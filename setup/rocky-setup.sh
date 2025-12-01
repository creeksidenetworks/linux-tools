#!/bin/bash
# Rocky Linux Setup Utility
# Usage: ssh -t <host> "$(<./rocky-setup.sh)" or run locally

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

tmp_file=$(mktemp /tmp/rocky-setup.XXXXXX)
trap cleanup_existing EXIT

function cleanup_existing() {
    echo -e "${Reset}Cleanup & exiting.\n\n"
    rm -f "$tmp_file"
    exit 0
}

function download_apps() {
    local url="$1"
    local dest="$2"
    local path="/resource/apps/"

    url="sftp://ftp.creekside.network:58222"
    curl --silent --list --user downloader:Kkg94290 --insecure ${url}/${path}/

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
                echo -e "⚠️  ${Red}Failed to install package: $pacakge${Reset}"
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

    if [[ $os_version == "8" ]]; then
        yum config-manager --set-enabled powertools
        echo "✓ Enabled PowerTools repository for $os_name $os_version."
    else
        yum config-manager --set-enabled crb
        echo "✓ Enabled CRB repository for $os_version."
    fi

    cat <<EOF > /etc/yum.repos.d/rpmfusion-free.repo
[rpmfusion-free-updates]
name=RPM Fusion for EL ${os_version} - Free - Updates
baseurl=http://download1.rpmfusion.org/free/el/updates/${os_version}/\$basearch/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-el-${os_version}
EOF

cat <<EOF > /etc/yum.repos.d/rpmfusion-nonfree.repo
[rpmfusion-nonfree-updates]
name=RPM Fusion for EL ${os_version} - Nonfree - Updates
baseurl=http://download1.rpmfusion.org/nonfree/el/updates/${os_version}/\$basearch/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-el-${os_version}
EOF
    echo "✓ Enabled RPM fusion repository."

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
        "firewalld" "dnf-plugins-core" "policycoreutils-python-utils"
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

# Install Desktop Environment
function install_desktop() {
    echo ""
    echo -e "${Yellow}Install Desktop Environment${Reset}"

    local mate_packages=(
        abrt-desktop abrt-java-connector adwaita-gtk2-theme alsa-plugins-pulseaudio 
        atril atril-caja atril-thumbnailer caja caja-actions 
        caja-image-converter caja-open-terminal caja-sendto caja-wallpaper caja-xattr-tags 
        dconf-editor engrampa eom firewall-config 
        gnome-disk-utility gnome-epub-thumbnailer gstreamer1-plugins-ugly-free gtk2-engines 
        gucharmap gvfs-afc gvfs-afp gvfs-archive 
        gvfs-fuse gvfs-gphoto2 gvfs-mtp gvfs-smb initial-setup-gui 
        libmatekbd libmatemixer libmateweather libsecret lm_sensors marco mate-applets 
        mate-backgrounds mate-calc mate-control-center mate-desktop mate-dictionary 
        mate-disk-usage-analyzer mate-icon-theme mate-media 
        mate-menus mate-menus-preferences-category-menu mate-notification-daemon 
        mate-panel mate-polkit mate-power-manager mate-screensaver 
        mate-screenshot mate-search-tool mate-session-manager mate-settings-daemon 
        mate-system-log mate-system-monitor mate-terminal mate-themes 
        mate-user-admin mate-user-guide mozo network-manager-applet 
        nm-connection-editor pluma seahorse seahorse-caja 
        xdg-user-dirs-gtk slick-greeter-mate  
    )

    echo "1) Installing Xfce Desktop Environment packages..."
    if ! command -v xfce4-session >/dev/null 2>&1; then
        if dnf groupinstall -y "Xfce" &> /dev/null; then
            echo "✓ Xfce Desktop Environment packages installed."
        else
            echo -e "⚠️  ${Red}Failed to install Xfce Desktop Environment.${Reset}"
            return
        fi
    else
        echo "✓ Xfce Desktop Environment already installed."
    fi

    echo "2) Installing Mate Desktop Environment packages..."
    if ! command -v mate-session >/dev/null 2>&1; then
        install_applications "${mate_packages[@]}"
        echo "✓ Mate Desktop Environment packages installed."
    else
        echo "✓ Mate Desktop Environment already installed."
    fi

    echo "3) Install desktop applications..."

    cat <<EOF > /etc/yum.repos.d/tilix.repo
[ivoarch-Tilix]
name=Copr repo for Tilix owned by ivoarch
baseurl=https://copr-be.cloud.fedoraproject.org/results/ivoarch/Tilix/epel-7-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=0
gpgkey=https://copr-be.cloud.fedoraproject.org/results/ivoarch/Tilix/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

    echo "✓ Tilix copr repository enabled."

    rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
    if dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo &> /dev/null; then
        echo "✓ Sublime Text repository added."
    else
        echo -e "⚠️  ${Red}Failed to add Sublime Text repository.${Reset}"
        return
    fi

    cat <<EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=Google Chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=0
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF
    echo "✓ Google Chrome repository added."

    local desktop_apps=(
        "firefox" "thunderbird" "vlc" "gimp" "file-roller" "nautilus" 
        "ristretto" "transmission-gtk" "hexchat" "gnome-calculator" 
        "evince" "pluma-plugins" "engrampa" "tilix" "sublime-text"
        "filezilla" "google-chrome-stable" "libreoffice"
    )

    install_applications "${desktop_apps[@]}" 

    echo -e "\n${Green}Desktop Environment installation completed.${Reset}\n\n"
}

# Get AD user groups 
function get_ad_user_groups() {
    local title="$1"
    local groups=""

    echo ""
    echo "${Green}$title${Reset}"

    local index=1
    while [ $index -le 4 ]; do
        group_name=""
        read -p "[$index]. group name (leave blank to finish): " group_name
        if [[ -z "$group_name" ]]; then
            break
        fi
        #echo "Checking group '$group_name' in AD..."
        # check if group exists in AD
        if ! getent group "$group_name" &> /dev/null; then
            echo -e "⚠️  ${Red}Group '$group_name' not found. Please try again.${Reset}"
            continue
        else
            #echo "✓ Group '$group_name' added."
            groups+="$group_name "
        fi
        index=$((index + 1))
    done

    USER_GROUPS="$groups"
}

# Function to update or add a setting in the domain section
update_setting() {
    local key="$1"
    local value="$2"
    local section="$3"
    local conf_file="$4"

    # Check if the setting exists in the domain section
    if grep -q "^[[:space:]]*$key[[:space:]]*=[[:space:]]*" "$conf_file"; then
        # Replace existing line
        sed -i "/^\[${section}\//,/^\[/ s|^[[:space:]]*$key[[:space:]]*=[[:space:]]*.*|$key = $value|" "$conf_file"
    else
        # Add new line after the domain section header
        sed -i "/^\[${section}\//a $key = $value" "$conf_file"
    fi
}

# Enroll host to domain
function enroll_domain() {

    # Check if already joined
    current_domain=$(realm list | grep domain-name | cut -d ':' -f 2 | xargs)
    if [[ -n $current_domain ]]; then
        echo -e "\n${Yellow}**** Domain service ****${Reset}"
        echo "✓ This machine is already joined to $current_domain."
        echo ""

        return 0
    fi

    while true; do
        echo -e "\n${Yellow}**** Domain service ****${Reset}"
        # Detect FQDN from host
        default_fqdn=$(hostname -f 2>/dev/null)
        if [[ -z "$default_fqdn" || "$default_fqdn" == "localhost" ]]; then
            default_fqdn=""
        fi
        read -p "Enter the FQDN hostname for this machine [${default_fqdn}]: " fqdn_hostname
        if [[ -z "$fqdn_hostname" ]]; then
            fqdn_hostname="$default_fqdn"
        fi
        # Derive domain name from FQDN
        domain_name="${fqdn_hostname#*.}"
        if [[ "$domain_name" == "$fqdn_hostname" ]]; then
            echo "Invalid FQDN. Could not derive domain name."
            continue
        fi

        # Discover domain info
        realm_output=$( realm discover "$domain_name" 2>/dev/null || true)

        # Determine domain type
        domain_type=$(echo "$realm_output" | awk -F': ' '/server-software:/ {if ($2 ~ /active-directory/) print "Active Directory"; else if ($2 ~ /ipa/) print "FreeIPA"; else print "Unknown"}')

        if [[ -z $domain_type || "$domain_type" == "Unknown" ]]; then
            echo "⚠️  Domain $domain_name not found"
            echo "Please check the domain name and network connectivity."
            return 0
        fi

        while true; do
            # Prompt for admin credentials
            read -p "Enter admin username for $domain_name: " admin_user
            if [[ -z "$admin_user" ]]; then
                echo "⚠️  Admin username cannot be empty. Please try again."
                continue
            fi
            break
        done

        while true; do
            read -s -p "Enter password for $admin_user: " admin_pass
            if [[ -z "$admin_pass" ]]; then
                echo -e "\n⚠️  Password cannot be empty. Please try again."
                continue
            fi
            break
        done

        # Confirm details
        echo ""
        echo ""
        echo "Summary of your entries:"
        echo "------------------------"
        printf " %-12s : %-30s\n" "Hostname" "$fqdn_hostname"
        printf " %-12s : %-30s\n" "Domain" "$domain_name"
        printf " %-12s : %-30s\n" "Type" "$domain_type"
        printf " %-12s : %-30s\n" "Admin User" "$admin_user"
        echo ""
        read -p "Proceed to join $domain_type? (y/N): " proceed
        if [[ "$proceed" =~ ^[Yy]$ ]]; then
            break
        else
            echo "Operation cancelled. Returning to main menu."
            return
        fi
    done

    echo ""
    echo "Now joining domain $domain_name..."
    # Set hostname
    sudo hostnamectl set-hostname "$fqdn_hostname"
    echo "✓ Hostname set to $fqdn_hostname."

    # Enroll host to domain
    echo "Enrolling host to domain $domain_name..."
    if [[ "$domain_type" == "FreeIPA" ]]; then
        # Join FreeIPA domain
        ipa-client-install \
            -p "$admin_user" \
            -w "$admin_pass" \
            --hostname="$fqdn_hostname" \
            --domain="$domain_name" \
            --principal="$admin_user" \
            --force-ntpd \
            --mkhomedir \
            --unattended
        if [[ $? -eq 0 ]]; then
            echo "✓ Successfully joined $domain_name ($domain_type)."
        else
            echo "⚠️  Failed to join FreeIPA domain. Please check credentials and network connectivity."
        fi
    else
        # Join Active Directory domain        
        echo "$admin_pass" | realm join --user="$admin_user" "$domain_name"
        if [[ $? -eq 0 ]]; then
            echo "✓ Successfully joined $domain_name ($domain_type)."
        else
            echo "⚠️  Failed to join domain. Please check credentials and network connectivity."
            return 0
        fi

        printf "\nUpdate SSSD configuration\n"
        # Update SSSD configuration in-place, preserving order
        SSSD_CONF="/etc/sssd/sssd.conf"
        BACKUP_CONF="${SSSD_CONF}.bak.$(date +%Y%m%d_%H%M%S)"

        # Backup the current config
        cp "$SSSD_CONF" "$BACKUP_CONF"

        # Settings to update (key => value)
        declare -A settings=(
            ["use_fully_qualified_names"]="False"
            ["fallback_homedir"]="/home/%u"
            ["ad_gpo_access_control"]="disabled"
            ["ad_gpo_map_remote_interactive"]="+xrdp-sesman"
            ["default_shell"]="bash"
        )

        # Update each setting
        for key in "${!settings[@]}"; do
            update_setting "$key" "${settings[$key]}" "domain" "$SSSD_CONF"
        done

        # Set proper permissions
        chmod 600 "$SSSD_CONF"

        # clean sssd cache
        systemctl stop sssd
        rm -rf /var/lib/sss/db/*
        systemctl start sssd

        get_ad_user_groups "Adding groups with sudo access"
        admin_groups="$USER_GROUPS"

        get_ad_user_groups "Adding groups with regular access"
        access_groups="$USER_GROUPS"

        # Configure sudoers for admin groups
        SUDOERS_FILE="/etc/sudoers.d/90-ad-groups"
        echo "# Sudoers file for AD groups - generated on $(date)" > "$SUDOERS_FILE"
        for group in $admin_groups; do
            echo "%$group ALL=(ALL) NOPASSWD: ALL" >> "$SUDOERS_FILE"
        done
        chmod 640 "$SUDOERS_FILE"
        echo "✓ Successfully added [$admin_groups] to sudo access."


        # Permit access to specified groups
        # Combine admin_groups and access_groups, remove duplicates and empty entries
        combined_groups=$(echo "$admin_groups $access_groups" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' | xargs)
        if [[ -n "$combined_groups" ]]; then
            # Pass each group as a separate argument to realm permit
            if realm permit -g $combined_groups; then
                echo "✓ Permitted [$combined_groups] to access this machine."
            else
                echo "⚠️  Failed to permit [$combined_groups] to access this machine."
            fi
        else
            echo "⚠️  No groups specified. Skipping realm permit."
        fi

        return 0
    fi
}

# Main program
function main() {

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
    os_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | cut -d. -f1)
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
            "Install Desktop Environment" 
            "Join a domain"
            "Exit"
        )
        show_menu "Main menu" "${menu_items[@]}"
        case $menu_index in
            0) initialization;;
            1) yum_configure_mirror;;
            2) install_desktop;;
            3) enroll_domain;;
            4) cleanup_existing;;
            *) echo "Invalid option.";;
        esac
    done
}

main "$@"