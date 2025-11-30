#!/bin/bash
# Rocky Linux Setup Utility
# Usage: ssh -t <host> "$(<./rocky-setup.sh)" or run locally

set -e

# Colors
Black=$(tput setaf 0)	#${Black}
Red=$(tput setaf 1)	    #${Red}
Green=$(tput setaf 2)	#${Green}
Yellow=$(tput setaf 3)	#${Yellow}
Blue=$(tput setaf 4)	#${Blue}
Magenta=$(tput setaf 5)	#${Magenta}
Cyan=$(tput setaf 6)	#${Cyan}
White=$(tput setaf 7)	#${White}
Bold=$(tput bold)	    #${Bold}
UndrLn=$(tput sgr 0 1)	#${UndrLn}
Rev=$(tput smso)		#${Rev}
Reset=$(tput sgr0)	    #${Reset}

# Regional options
countries=("CN" "GB" "AE" "US")
regions=("China" "UK" "UAE" "USA")
timezones=("Asia/Shanghai" "Europe/London" "Asia/Dubai" "America/Los_Angeles")

COUNTRY=""
TIMEZONE="UTC"

# Mirror options
declare -A BASE_MIRRORS
declare -A EPEL_MIRRORS
BASE_MIRRORS["US"]="https://dl.rockylinux.org/pub/rocky"
EPEL_MIRRORS["US"]="http://dl.fedoraproject.org/pub/epel"
BASE_MIRRORS["CN"]="https://mirrors.nju.edu.cn/rocky"
EPEL_MIRRORS["CN"]="https://mirrors.nju.edu.cn/epel"
BASE_MIRRORS["GB"]="http://rockylinux.mirrorservice.org/pub/rocky"
EPEL_MIRRORS["GB"]="https://www.mirrorservice.org/pub/epel"
BASE_MIRRORS["AE"]="https://mirror.ourhost.az/rockylinux/"
EPEL_MIRRORS["AE"]="https://mirror.yer.az/fedora-epel/"

function cleanup_existing() {
    echo -e "${Reset}Exiting.\n\n"
    exit 0
}

# Add SSH keys to root authorized_keys
function add_root_ssh_keys() {
    # Only run as root
    if [[ $(id -u) -ne 0 ]]; then
        echo "This operation must be run as root. Please re-run as root or with sudo."
        exit 1
    fi

    local authorized_keys_file="/root/.ssh/authorized_keys"
    local ssh_dir="/root/.ssh"
    local keys=(
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p creeksidenetworks@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJggtEGPdn91k36jza3Ln+pXivNTjcT+l17fwFaVpecP jtong@creekside.network"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQChzHPb3CTFUwEPCm1sZQUwiJIWhrw8PtuKWyOOgBjPCGVbavRjHDKlaXSgh3JtEBovQX0CLvqR+dMDJEjYGCRQRyfLT84K7ozEbfw8tX+IlWrLGQ7t6bZQjp1d70ulFWWVwTFLtcA3RGONSAR+Jt0zTzkhFCjPp8CagRe7nY7KNh3kE7y19OlWoP4eNw0ZAaMcUajKd6YJXYs4LnpoyM2lrWZRssa3kiPxzpyJj9z0mrc5hH6WmrKyPAuJO4GuFXNUwGre/H5DIoXUgzmZZTbusE25exGkKpweFo4M/CxB2szebr0XKViwYrp3sT0ELUk92cJC65HkmFTrj/Fq49VEXJ3Z3fwoootyhPFQ/Gk5JrJ+bNsvSRRBS+m7f/afOq9m5jvx907nnP8HN9W0pJkrmJkzz7Lvzm7BfaMMJ9TUWf9olroLXWy+VkH8RdW0MKz7zZ1sCLhIerZz1iUtkVhPTjRYmWQZtFgSc7b4hhm6Xw7bGMhRZa91SJTt3MzUeM8= jsong@creekside.network"
    )

    # Ensure .ssh directory exists
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    # Ensure authorized_keys file exists
    if [[ ! -f "$authorized_keys_file" ]]; then
        touch "$authorized_keys_file"
        chmod 600 "$authorized_keys_file"
    fi

    for key in "${keys[@]}"; do
        if ! grep -qF "$key" "$authorized_keys_file"; then
            echo "$key" >> "$authorized_keys_file"
        fi
    done
}

# Generic menu function
function show_menu() {
    local title="$1"
    shift
    local options=("$@")
    echo -e "${Green}$title${Reset}"
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done
    echo -n "Select an option [1-${#options[@]}]: "

    read user_choice
    if ! [[ "$user_choice" =~ ^[0-9]+$ ]] || (( user_choice < 1 || user_choice > ${#options[@]} )); then
        user_choice=${#options[@]}
    fi
    menu_index=$((user_choice-1))
}

function detect_location() {
    # Get geolocation info from public IP with timeout
    GEOINFO=$(curl -s --max-time 5 http://ip-api.com/json/)
    if [[ -n "$GEOINFO" && "$GEOINFO" != "{}" ]]; then
        COUNTRY=$(echo "$GEOINFO" | grep -o '"countryCode":"[^"]*"' | cut -d':' -f2 | tr -d '"')
        TIMEZONE=$(echo "$GEOINFO" | grep -o '"timezone":"[^"]*"' | cut -d':' -f2 | tr -d '"')
        #echo -e "✓ Detected location: Country=$COUNTRY, Timezone=$TIMEZONE"
    fi
    if [[ -z "$COUNTRY" ]] || [[ ! " ${countries[@]} " =~ " $COUNTRY " ]]; then
        echo -e "⚠️  Could not retrieve geolocation info."
        # Prompt user for country/region
        show_menu "Select your country/region" "${regions[@]}"
        if (( menu_index >= 0 && menu_index < ${#countries[@]} )); then
            COUNTRY="${countries[$menu_index]}"
            TIMEZONE="${timezones[$menu_index]}"
        else
            COUNTRY="GLOBAL"
            TIMEZONE="UTC"
        fi
    fi
    # Export variables for use in initialization
    export COUNTRY TIMEZONE
}

function yum_configure_mirror() {

    # Auto-select mirror based on country
    baseos_url="${BASE_MIRRORS[$COUNTRY]:-US}"
    epel_url="${EPEL_MIRRORS[$COUNTRY]:-US}"

    echo "✓ Updating Rocky Linux base repository to $baseos_url"
    # Update Rocky repos
    shopt -s nocaseglob
    for repo in /etc/yum.repos.d/Rocky*.repo; do
        sed -i -E "s%^([[:space:]]*)#?([[:space:]]*)baseurl=http.*contentdir%baseurl=${baseos_url}%" "$repo"
        sed -i 's/^mirrorlist=/#mirrorlist=/' "$repo"
    done
    shopt -u nocaseglob

    # Update EPEL repo
    echo "✓ Updating EPEL repository to $epel_url"
    for repo in /etc/yum.repos.d/epel*.repo; do
        sed -i -E "s%^([[:space:]]*)#?([[:space:]]*)baseurl=http.*epel%baseurl=${epel_url}%" "$repo"
        #sed -i "s|^[[:space:]]*#?[[:space:]]*baseurl=.*epel|baseurl=${epel_url}|g" "$repo"
        sed -i 's/^metalink=/#metalink=/' "$repo"
    done

}

# Install applications
function install_applications() {
    packages=("$@")
    for pacakge in ${packages[@]}; do
        if ! rpm -q --quiet $pacakge 2>$1; then
            if ! dnf install -yq $pacakge &> /dev/null; then
                echo -e "⚠️  ${Red}Failed to install package: $pacakge${Res et}"
            else
                echo "✓ Package installed: $pacakge"
            fi
        fi
    done
}

# Initialization routine
function initialization() {
    echo ""
    echo -e "${Yellow}Rocky OS Initialization${Reset}"

    detect_location

    while true; do
        echo "1) Regional information "
        echo "  ✓ Country: $COUNTRY"
        echo "  ✓ Timezone: $TIMEZONE"
        read -p  "Do you want to choose a different country/region [y/N]:" change_country
        if [[ "$change_country" =~ ^[Yy]$ ]]; then
            show_menu "Select your country/region" "${regions[@]}"
            if (( menu_index >= 0 && menu_index < ${#countries[@]} )); then
                COUNTRY="${countries[$menu_index]}"
                TIMEZONE="${timezones[$menu_index]}"
            else
                echo "Invalid selection. Please try again."
                continue
            fi
        fi

        # Ask for Squid proxy
        proxy_url=""
        read -p "2) Do you want to use a proxy for yum? (y/N): " use_proxy
        if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
            read -p "Enter proxy hostname or IP (e.g. http://<proxy>:3128): " proxy_host
            if [[ -z "$proxy_host" ]]; then
                echo "Proxy hostname cannot be empty. Please try again."
                continue
            fi
            proxy_url="http://$proxy_host:3128"
        fi

        read -p "3) Enter hostname (leave blank to skip): " new_hostname
        echo ""
        echo "Summary of your selections:"
        echo "  Country:    $COUNTRY"
        echo "  Timezone:   $TIMEZONE"
        if [[ -n "$proxy_url" ]]; then
            echo "  Yum Proxy:  $proxy_url"
        else
            echo "  Yum Proxy:  (none)"
        fi
        if [[ -n "$new_hostname" ]]; then
            echo "  Hostname:   $new_hostname"
        else
            echo "  Hostname:   (unchanged)"
        fi
        echo ""
        read -p "Proceed with these settings? (Y/n): " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            read -p "Return to main menu? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                return  # Go back to main menu
            else
                echo ""
                continue
            fi
        fi
        break
    done

    echo ""
    echo "1) Updating system packages..."
    # Configure yum proxy
    if [[ -n "$proxy_url" ]]; then
        if grep -q "^proxy=" /etc/yum.conf; then
            sudo sed -i "s|^proxy=.*|proxy=$proxy_url|" /etc/yum.conf
            echo "✓ Yum proxy updated."
        else
            echo "proxy=$proxy_url" | sudo tee -a /etc/yum.conf > /dev/null
            echo "✓ Yum proxy configured."
        fi
    fi

    # Install EPEL
    if ! dnf repolist enabled | grep epel >/dev/null 2>&1; then
        echo "Installing EPEL repository..."
        if dnf install -y epel-release &> /dev/null; then
            echo "✓ EPEL repository installed."
            # Refresh repo metadata
            dnf makecache -y &> /dev/null
            echo "✓ Repo metadata refreshed."
        else
            echo -e "⚠️  ${Red}Failed to install EPEL repository. Exiting.${Reset}"
            exit 1
        fi
    else
        echo "✓ EPEL repository already installed."
    fi 

    if [[ $os_version == 8* ]]; then
        yum config-manager --set-enabled powertools
        echo "✓ Enabled PowerTools repository for $os_name $os_version."
    else
        yum config-manager --set-enabled crb
        echo "✓ Enabled CRB repository for $os_version."
    fi

    echo "2) Updating yum repository mirrors..."
    # Configure yum mirrors
    yum_configure_mirror

    # Disable SELinux
    echo "Disabling SELinux..."
    sudo setenforce 0 || true
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

    # Set timezone (default to detected)
    sudo timedatectl set-timezone "${TIMEZONE}"
    echo "Timezone set to ${TIMEZONE}."

    # Set hostname
    if [[ -n "$new_hostname" ]]; then
        sudo hostnamectl set-hostname "$new_hostname"
        echo "Hostname set to $new_hostname."
    fi

    local default_packages=(
        "zsh" "ksh" "tcsh" "xterm" 
        "yum-utils" "util-linux" "tree"  
        "nano" "ed" "fontconfig" "nedit" "htop" "pwgen"
        "nfs-utils" "cifs-utils" "samba-client" "autofs" 
        "subversion" "ansible" 
        "iperf3" "traceroute" "mtr" "rsnapshot"
        "tar"  "zip" "unzip" "p7zip" "p7zip-plugins" "cabextract"
        "rsync" "curl" "ftp" "wget" 
        "telnet" "jq"  "lsof" "bind-utils" "tcpdump" "net-tools"
        "openssl" "cyrus-sasl" "cyrus-sasl-plain" "cyrus-sasl-ldap"
        "openldap-clients" "ipa-client"
        "sssd" "realmd" "oddjob" "oddjob-mkhomedir"
        "adcli" "samba-common" "samba-common-tools" "krb5-workstation"
        "firewalld" 
    )

    echo "Installing necessary packages..."
    install_applications "${default_packages[@]}"
    echo "Necessary packages installed."

    echo -e "\n${Green}Initialization completed.${Reset}"
}

# Update yum repository mirrors
function update_mirrors() {
    echo ""
    echo -e "${Yellow}Update yum repository mirrors${Reset}"

    detect_location

    while true; do
        echo "1) Regional information "
        echo "  ✓ Country: $COUNTRY"
        echo "  ✓ Timezone: $TIMEZONE"
        read -p  "Do you want to choose a different country/region [y/N]:" change_country
        if [[ "$change_country" =~ ^[Yy]$ ]]; then
            show_menu "Select your country/region" "${regions[@]}"
            if (( menu_index >= 0 && menu_index < ${#countries[@]} )); then
                COUNTRY="${countries[$menu_index]}"
                TIMEZONE="${timezones[$menu_index]}"
            else
                echo "Invalid selection. Please try again."
                continue
            fi
        fi

        # Ask for Squid proxy
        proxy_url=""
        read -p "2) Do you want to use a proxy for yum? (y/N): " use_proxy
        if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
            read -p "Enter proxy hostname or IP (e.g. http://<proxy>:3128): " proxy_host
            if [[ -z "$proxy_host" ]]; then
                echo "Proxy hostname cannot be empty. Please try again."
                continue
            fi
            proxy_url="http://$proxy_host:3128"
        fi

        echo ""
        read -p "Proceed with these settings? (Y/n): " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            read -p "Return to main menu? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                return  # Go back to main menu
            fi
        else
            break
        fi
    done

    echo "proxy=$proxy_url" | sudo tee -a /etc/yum.conf > /dev/null
    echo "Proxy configured for yum."

    # Configure yum mirrors
    yum_configure_mirror

    echo -e "${Green}Yum repos updated.${Reset}\n\n"
}

main() {

    # print title and copyright box
    cat <<EOF

***********************************************************
* Rocky OS Setup scripts v1.0                             *
* (c) Jackson Tong / Creekside Networks LLC 2021-2025)    *
* Usage: ssh -t <host> "\$(<rocky-setup.sh)"               *
***********************************************************

EOF

    # Ensure running as root
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root. Please re-run as root or with sudo."
        exit 1
    fi

    # Check OS version
    os_name=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    if [[ "$os_name" != "rocky" ]]; then
        echo -e "${Red}This script is intended for Rocky Linux only. Detected OS: $os_name $os_version${Reset}"
        exit 1
    fi
    echo "Detected Rocky Linux $os_version."

    # Add SSH public keys to root
    add_root_ssh_keys

    # Main loop
    while true; do
        # Main menu wrapper
        echo ""
        menu_items=(
            "Initialization" 
            "Update yum mirrors" 
            "Install Desktop" 
            "Exit"
        )
        show_menu "Main menu" "${menu_items[@]}"
        case $menu_index in
            0) initialization;;
            1) yum_configure_mirror;;
            2) install_desktop;;
            3) cleanup_existing;;
            *) echo "Invalid option.";;
        esac
    done
}

main