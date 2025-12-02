#!/bin/bash
#===============================================================================
# Rocky Linux Setup Utility
# Version: 1.0
# Author: Jackson Tong / Creekside Networks LLC
# License: MIT
#
# Description:
#   Comprehensive setup and configuration utility for Rocky Linux 8/9.
#   Provides menu-driven interface for system initialization, network
#   configuration, desktop environment installation, and domain enrollment.
#
# Usage:
#   Local:  sudo ./rocky-setup.sh
#   Remote: ssh -t <host> "$(<./rocky-setup.sh)"
#
# Requirements:
#   - Rocky Linux 8 or 9
#   - Root privileges
#   - Network connectivity (for package installation)
#===============================================================================

# Colors for terminal output
Red=$(tput setaf 1)
Green=$(tput setaf 2)
Yellow=$(tput setaf 3)
Blue=$(tput setaf 4)
Cyan=$(tput setaf 6)
Bold=$(tput bold)
Reset=$(tput sgr0)
Dim=$(tput dim)

#===============================================================================
# Output Helper Functions
#===============================================================================

# Print a section header with box border
print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    echo ""
    printf "${Cyan}%s${Reset}\n" "$(printf '═%.0s' $(seq 1 $width))"
    printf "${Cyan}║${Reset}%*s${Bold}%s${Reset}%*s${Cyan}║${Reset}\n" $padding "" "$title" $((width - padding - ${#title} - 2)) ""
    printf "${Cyan}%s${Reset}\n" "$(printf '═%.0s' $(seq 1 $width))"
}

# Print a step header
print_step() {
    local step_num="$1"
    local title="$2"
    echo ""
    echo -e "${Yellow}[$step_num]${Reset} ${Bold}$title${Reset}"
    echo -e "${Dim}$(printf '─%.0s' $(seq 1 50))${Reset}"
}

# Print success message
print_ok() {
    echo -e "  ${Green}✓${Reset} $1"
}

# Print warning message  
print_warn() {
    echo -e "  ${Yellow}⚠${Reset} $1"
}

# Print error message
print_error() {
    echo -e "  ${Red}✗${Reset} $1"
}

# Print info message
print_info() {
    echo -e "  ${Blue}ℹ${Reset} $1"
}

# Print a summary box
print_summary() {
    local title="$1"
    shift
    local items=("$@")
    echo ""
    echo -e "${Cyan}┌─ $title ───────────-────${Reset}"
    for item in "${items[@]}"; do
        echo -e "${Cyan}│${Reset}  $item"
    done
    echo -e "${Cyan}└$(printf '─%.0s' $(seq 1 40))${Reset}"
}

# Regional options - parallel arrays for country codes, display names, and timezones
# Add new regions by appending to all three arrays in the same order
countries=("CN" "GB" "AE" "US")
regions=("China" "UK" "UAE" "USA")
timezones=("Asia/Shanghai" "Europe/London" "Asia/Dubai" "America/Los_Angeles")

COUNTRY=""
TIMEZONE="UTC"

# Mirror options - associative arrays mapping country codes to mirror URLs
# BASE_MIRRORS: Rocky Linux base repository mirrors
# EPEL_MIRRORS: Extra Packages for Enterprise Linux mirrors
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

# Create temporary file for script operations and ensure cleanup on exit
tmp_file=$(mktemp /tmp/rocky-setup.XXXXXX)
trap cleanup_existing EXIT

# Cleanup function - called on script exit (normal or interrupted)
function cleanup_existing() {
    echo ""
    echo -e "${Dim}Cleaning up and exiting...${Reset}"
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

# Generic menu function - displays numbered options and captures user selection
# Arguments:
#   $1: Menu title
#   $@: Menu options (remaining arguments)
# Sets global variable:
#   menu_index: 0-based index of selected option
function show_menu() {
    local title="$1"
    shift
    local options=("$@")
    echo ""
    echo -e "${Green}${Bold}$title${Reset}"
    for i in "${!options[@]}"; do
        printf "  ${Cyan}%d)${Reset} %s\n" "$((i+1))" "${options[$i]}"
    done
    echo ""
    echo -n "  Select [1-${#options[@]}]: "
    read user_choice
    if ! [[ "$user_choice" =~ ^[0-9]+$ ]] || (( user_choice < 1 || user_choice > ${#options[@]} )); then
        user_choice=${#options[@]}
    fi
    menu_index=$((user_choice-1))
}

# Detect geographic location using public IP geolocation API
# Sets global variables: COUNTRY, TIMEZONE
# Falls back to manual selection if detection fails
function detect_location() {
    # Get geolocation info from public IP with timeout
    GEOINFO=$(curl -s --max-time 5 http://ip-api.com/json/)
    if [[ -n "$GEOINFO" && "$GEOINFO" != "{}" ]]; then
        COUNTRY=$(echo "$GEOINFO" | grep -o '"countryCode":"[^"]*"' | cut -d':' -f2 | tr -d '"')
        TIMEZONE=$(echo "$GEOINFO" | grep -o '"timezone":"[^"]*"' | cut -d':' -f2 | tr -d '"')
        #echo -e "✓ Detected location: Country=$COUNTRY, Timezone=$TIMEZONE"
    fi
    if [[ -z "$COUNTRY" ]] || [[ ! " ${countries[@]} " =~ " $COUNTRY " ]]; then
        echo -e "⚠️  Could not retrieve geolocation info, use USA as default."
        # Set default to USA, user can change later
        COUNTRY="US"
        TIMEZONE="America/Los_Angeles"
    fi
    # Export variables for use in initialization
    export COUNTRY TIMEZONE
}

# Configure yum repository mirrors based on detected/selected country
# Updates both Rocky Linux base repos and EPEL repos
function yum_configure_mirror() {
    # Auto-select mirror based on country
    baseos_url="${BASE_MIRRORS[$COUNTRY]:-US}"
    epel_url="${EPEL_MIRRORS[$COUNTRY]:-US}"

    # Update Rocky repos
    shopt -s nocaseglob
    for repo in /etc/yum.repos.d/Rocky*.repo; do
        sed -i -E "s%^([[:space:]]*)#?([[:space:]]*)baseurl=http.*contentdir%baseurl=${baseos_url}%" "$repo"
        sed -i 's/^mirrorlist=/#mirrorlist=/' "$repo"
    done
    shopt -u nocaseglob
    print_ok "Rocky Linux repos → $baseos_url"

    # Update EPEL repo
    for repo in /etc/yum.repos.d/epel*.repo; do
        sed -i -E "s%^([[:space:]]*)#?([[:space:]]*)baseurl=http.*epel%baseurl=${epel_url}%" "$repo"
        sed -i 's/^metalink=/#metalink=/' "$repo"
    done
    print_ok "EPEL repos → $epel_url"
}

# Install packages using dnf, skipping already-installed packages
# Arguments: List of package names to install
# Outputs success/failure message for each package
function install_applications() {
    local packages=("$@")
    local installed=0
    local failed=0
    local skipped=0
    
    for package in "${packages[@]}"; do
        if rpm -q --quiet "$package" 2>/dev/null; then
            ((skipped++))
        elif dnf install -yq "$package" &>/dev/null; then
            ((installed++))
        else
            print_warn "Failed: $package"
            ((failed++))
        fi
    done
    
    # Summary line
    local summary="Installed: $installed"
    [[ $skipped -gt 0 ]] && summary+=", Skipped: $skipped"
    [[ $failed -gt 0 ]] && summary+=", Failed: $failed"
    print_ok "$summary"
}

# Main initialization routine - performs complete system setup
function initialization() {
    print_header "System Initialization"

    detect_location

    while true; do
        # Collect configuration
        echo ""
        echo -e "${Bold}Configuration Options${Reset}"
        echo ""
        printf "  ${Cyan}1.${Reset} Region:   ${Green}$COUNTRY${Reset} (Timezone: $TIMEZONE)\n"
        read -p "     Change region? [y/N]: " change_country
        if [[ "$change_country" =~ ^[Yy]$ ]]; then
            show_menu "Select your country/region" "${regions[@]}"
            if (( menu_index >= 0 && menu_index < ${#countries[@]} )); then
                COUNTRY="${countries[$menu_index]}"
                TIMEZONE="${timezones[$menu_index]}"
            fi
        fi

        proxy_url=""
        printf "\n  ${Cyan}2.${Reset} Proxy:    "
        read -p "Configure yum proxy? [y/N]: " use_proxy
        if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
            read -p "     Enter proxy host (hostname or IP): " proxy_host
            if [[ -n "$proxy_host" ]] && \
               ([[ "$proxy_host" =~ ^([a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || \
                [[ "$proxy_host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]); then
                proxy_url="http://$proxy_host:3128"
            else
                print_warn "Invalid hostname or IP. Skipping proxy."
            fi
        fi

        printf "\n  ${Cyan}3.${Reset} Hostname: "
        read -p "Enter new hostname [skip]: " new_hostname

        # Display summary
        local summary_items=(
            "Country:   $COUNTRY"
            "Timezone:  $TIMEZONE"
            "Proxy:     ${proxy_url:-(none)}"
            "Hostname:  ${new_hostname:-(unchanged)}"
        )
        print_summary "Configuration Summary" "${summary_items[@]}"

        echo ""
        read -p "  Proceed with these settings? [Y/n]: " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            read -p "  Return to main menu? [y/N]: " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] && return
            continue
        fi
        break
    done

    #---------------------------------------------------------------------------
    print_step "1" "Configuring System Settings"
    #---------------------------------------------------------------------------
    
    # Configure yum proxy
    if [[ -n "$proxy_url" ]]; then
        if grep -q "^proxy=" /etc/yum.conf; then
            sudo sed -i "s|^proxy=.*|proxy=$proxy_url|" /etc/yum.conf
        else
            echo "proxy=$proxy_url" | sudo tee -a /etc/yum.conf > /dev/null
        fi
        print_ok "Yum proxy configured"

        # Set proxy environment variables for root user
        if ! grep -q "http_proxy=" /root/.bashrc; then
            cat <<EOF >> /root/.bashrc
export http_proxy=$proxy_url
export https_proxy=$proxy_url
export ftp_proxy=$proxy_url
export no_proxy="localhost,127.0.0.1,::1"
EOF
            print_ok "Proxy environment variables set"
        fi
    fi

    # Set timezone
    sudo timedatectl set-timezone "${TIMEZONE}"
    print_ok "Timezone: ${TIMEZONE}"

    # Set hostname
    if [[ -n "$new_hostname" ]]; then
        sudo hostnamectl set-hostname "$new_hostname"
        print_ok "Hostname: $new_hostname"
    fi

    # Disable SELinux
    sudo setenforce 0 2>/dev/null || true
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    print_ok "SELinux disabled"

    #---------------------------------------------------------------------------
    print_step "2" "Configuring Repositories"
    #---------------------------------------------------------------------------
    
    # Install EPEL
    if ! dnf repolist enabled | grep -q epel 2>/dev/null; then
        if dnf install -y epel-release &>/dev/null; then
            dnf makecache -y &>/dev/null
            print_ok "EPEL repository installed"
        else
            print_error "Failed to install EPEL repository"
            exit 1
        fi
    else
        print_ok "EPEL repository (already installed)"
    fi 

    # Enable PowerTools/CRB
    if [[ $os_version == "8" ]]; then
        yum config-manager --set-enabled powertools &>/dev/null
        print_ok "PowerTools repository enabled"
    else
        yum config-manager --set-enabled crb &>/dev/null
        print_ok "CRB repository enabled"
    fi

    # Configure RPM Fusion repos
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
    print_ok "RPM Fusion repositories enabled"

    # Configure yum mirrors
    yum_configure_mirror

    #---------------------------------------------------------------------------
    print_step "3" "Installing Essential Packages"
    #---------------------------------------------------------------------------
    
    local default_packages=(
        "zsh" "ksh" "tcsh" "xterm" "ethtool" "vim"
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

    print_info "Installing ${#default_packages[@]} packages..."
    install_applications "${default_packages[@]}"

    #---------------------------------------------------------------------------
    print_step "4" "Installing Docker CE"
    #---------------------------------------------------------------------------
    
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
        compose_version=$(docker compose version 2>/dev/null | cut -d' ' -f4)
        print_ok "Docker CE already installed (v$docker_version)"
        [[ -n "$compose_version" ]] && print_ok "Docker Compose (v$compose_version)"
    else
        # Add Docker repository based on region
        if [[ "$COUNTRY" == "CN" ]]; then
            cat <<EOF > /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://mirrors.nju.edu.cn/docker-ce/linux/rhel/${os_version}/\$basearch/stable
enabled=1
gpgcheck=0
gpgkey=https://mirrors.nju.edu.cn/docker-ce/linux/rhel/gpg
EOF
            print_ok "Docker CE repository (NJU mirror)"
        else
            dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo &>/dev/null
            print_ok "Docker CE repository added"
        fi
        
        # Install Docker CE and plugins
        if dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &>/dev/null; then
            systemctl enable docker &>/dev/null
            systemctl start docker &>/dev/null
            
            docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
            compose_version=$(docker compose version 2>/dev/null | cut -d' ' -f4)
            print_ok "Docker CE installed (v$docker_version)"
            print_ok "Docker Compose (v$compose_version)"
            print_ok "Docker service enabled and started"
        else
            print_error "Failed to install Docker CE"
        fi
    fi

    #---------------------------------------------------------------------------
    echo ""
    echo -e "${Green}${Bold}✓ Initialization completed successfully${Reset}"
    echo ""
}

# Update yum repository mirrors
function update_mirrors() {
    print_header "Update Repository Mirrors"

    detect_location

    while true; do
        echo ""
        printf "  ${Cyan}1.${Reset} Region: ${Green}$COUNTRY${Reset} (Timezone: $TIMEZONE)\n"
        read -p "     Change region? [y/N]: " change_country
        if [[ "$change_country" =~ ^[Yy]$ ]]; then
            show_menu "Select your country/region" "${regions[@]}"
            if (( menu_index >= 0 && menu_index < ${#countries[@]} )); then
                COUNTRY="${countries[$menu_index]}"
                TIMEZONE="${timezones[$menu_index]}"
            fi
        fi

        proxy_url=""
        printf "\n  ${Cyan}2.${Reset} Proxy: "
        read -p "Configure yum proxy? [y/N]: " use_proxy
        if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
            read -p "     Enter proxy host: " proxy_host
            [[ -n "$proxy_host" ]] && proxy_url="http://$proxy_host:3128"
        fi

        echo ""
        read -p "  Proceed with these settings? [Y/n]: " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            read -p "  Return to main menu? [y/N]: " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] && return
        else
            break
        fi
    done

    if [[ -n "$proxy_url" ]]; then
        echo "proxy=$proxy_url" | sudo tee -a /etc/yum.conf > /dev/null
        print_ok "Proxy configured"
    fi

    yum_configure_mirror

    echo ""
    echo -e "${Green}${Bold}✓ Repository mirrors updated${Reset}"
    echo ""
}

# Install desktop environments and GUI applications
function install_desktop() {
    print_header "Desktop Environment Installation"

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

    #---------------------------------------------------------------------------
    print_step "1" "Installing Xfce Desktop Environment"
    #---------------------------------------------------------------------------
    if ! command -v xfce4-session >/dev/null 2>&1; then
        if dnf groupinstall -y "Xfce" &>/dev/null; then
            print_ok "Xfce Desktop Environment installed"
        else
            print_error "Failed to install Xfce Desktop Environment"
            return
        fi
    else
        print_ok "Xfce Desktop Environment (already installed)"
    fi

    #---------------------------------------------------------------------------
    print_step "2" "Installing MATE Desktop Environment"
    #---------------------------------------------------------------------------
    if ! command -v mate-session >/dev/null 2>&1; then
        print_info "Installing ${#mate_packages[@]} MATE packages..."
        install_applications "${mate_packages[@]}"
    else
        print_ok "MATE Desktop Environment (already installed)"
    fi

    #---------------------------------------------------------------------------
    print_step "3" "Installing Desktop Applications"
    #---------------------------------------------------------------------------

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
    print_ok "Tilix repository added"

    rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg 2>/dev/null
    if dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo &>/dev/null; then
        print_ok "Sublime Text repository added"
    else
        print_error "Failed to add Sublime Text repository"
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
    print_ok "Google Chrome repository added"

    local desktop_apps=(
        "firefox" "thunderbird" "vlc" "gimp" "file-roller" "nautilus" 
        "ristretto" "transmission-gtk" "hexchat" "gnome-calculator" 
        "evince" "pluma-plugins" "engrampa" "tilix" "sublime-text"
        "filezilla" "google-chrome-stable" "libreoffice"
    )

    print_info "Installing ${#desktop_apps[@]} desktop applications..."
    install_applications "${desktop_apps[@]}" 

    echo ""
    echo -e "${Green}${Bold}✓ Desktop Environment installation completed${Reset}"
    echo ""
}

# Prompt user to enter AD/LDAP group names (up to 4)
function get_ad_user_groups() {
    local title="$1"
    local groups=""

    echo ""
    echo -e "${Cyan}$title${Reset}"

    local index=1
    while [ $index -le 4 ]; do
        read -p "  [$index] Group name (blank to finish): " group_name
        [[ -z "$group_name" ]] && break
        
        if ! getent group "$group_name" &>/dev/null; then
            print_warn "Group '$group_name' not found in directory"
            continue
        fi
        groups+="$group_name "
        index=$((index + 1))
    done

    USER_GROUPS="$groups"
}

# Update or add a setting in a configuration file section
# Used primarily for SSSD configuration
# Arguments:
#   $1: Setting key
#   $2: Setting value
#   $3: Section name (without brackets)
#   $4: Configuration file path
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

# Enroll host to Active Directory or FreeIPA domain
function enroll_domain() {
    print_header "Domain Enrollment"

    # Check if already joined
    current_domain=$(realm list | grep domain-name | cut -d ':' -f 2 | xargs)
    if [[ -n $current_domain ]]; then
        print_ok "Already joined to domain: $current_domain"
        return 0
    fi

    while true; do
        echo ""
        # Detect FQDN from host
        default_fqdn=$(hostname -f 2>/dev/null)
        [[ -z "$default_fqdn" || "$default_fqdn" == "localhost" ]] && default_fqdn=""
        
        read -p "  Enter FQDN hostname [${default_fqdn}]: " fqdn_hostname
        [[ -z "$fqdn_hostname" ]] && fqdn_hostname="$default_fqdn"
        
        # Derive domain name from FQDN
        domain_name="${fqdn_hostname#*.}"
        if [[ "$domain_name" == "$fqdn_hostname" ]]; then
            print_warn "Invalid FQDN. Could not derive domain name."
            continue
        fi

        # Discover domain info
        realm_output=$(realm discover "$domain_name" 2>/dev/null || true)
        domain_type=$(echo "$realm_output" | awk -F': ' '/server-software:/ {if ($2 ~ /active-directory/) print "Active Directory"; else if ($2 ~ /ipa/) print "FreeIPA"; else print "Unknown"}')

        if [[ -z $domain_type || "$domain_type" == "Unknown" ]]; then
            print_warn "Domain $domain_name not found"
            print_info "Check domain name and network connectivity"
            return 0
        fi

        while true; do
            read -p "  Enter admin username for $domain_name: " admin_user
            [[ -n "$admin_user" ]] && break
            print_warn "Admin username cannot be empty"
        done

        while true; do
            read -s -p "  Enter password for $admin_user: " admin_pass
            echo ""
            [[ -n "$admin_pass" ]] && break
            print_warn "Password cannot be empty"
        done

        # Display summary
        local summary_items=(
            "Hostname:    $fqdn_hostname"
            "Domain:      $domain_name"
            "Type:        $domain_type"
            "Admin User:  $admin_user"
        )
        print_summary "Domain Join Configuration" "${summary_items[@]}"

        echo ""
        read -p "  Proceed to join $domain_type? [y/N]: " proceed
        [[ "$proceed" =~ ^[Yy]$ ]] && break
        print_info "Operation cancelled"
        return
    done

    #---------------------------------------------------------------------------
    print_step "1" "Joining Domain"
    #---------------------------------------------------------------------------
    
    # Set hostname
    sudo hostnamectl set-hostname "$fqdn_hostname"
    print_ok "Hostname set to $fqdn_hostname"

    if [[ "$domain_type" == "FreeIPA" ]]; then
        ipa-client-install \
            -p "$admin_user" \
            -w "$admin_pass" \
            --hostname="$fqdn_hostname" \
            --domain="$domain_name" \
            --principal="$admin_user" \
            --mkhomedir \
            --unattended
        if [[ $? -eq 0 ]]; then
            print_ok "Joined $domain_name (FreeIPA)"
        else
            print_error "Failed to join FreeIPA domain"
        fi
    else
        # Join Active Directory domain        
        echo "$admin_pass" | realm join --user="$admin_user" "$domain_name"
        if [[ $? -eq 0 ]]; then
            print_ok "Joined $domain_name (Active Directory)"
        else
            print_error "Failed to join domain. Check credentials and network."
            return 0
        fi

        #-----------------------------------------------------------------------
        print_step "2" "Configuring SSSD"
        #-----------------------------------------------------------------------
        # Update SSSD configuration in-place
        SSSD_CONF="/etc/sssd/sssd.conf"
        BACKUP_CONF="${SSSD_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$SSSD_CONF" "$BACKUP_CONF"

        declare -A settings=(
            ["use_fully_qualified_names"]="False"
            ["fallback_homedir"]="/home/%u"
            ["ad_gpo_access_control"]="disabled"
            ["ad_gpo_map_remote_interactive"]="+xrdp-sesman"
            ["default_shell"]="bash"
        )

        for key in "${!settings[@]}"; do
            update_setting "$key" "${settings[$key]}" "domain" "$SSSD_CONF"
        done
        chmod 600 "$SSSD_CONF"
        print_ok "SSSD configuration updated"

        # Restart SSSD
        systemctl stop sssd
        rm -rf /var/lib/sss/db/*
        systemctl start sssd
        print_ok "SSSD cache cleared and service restarted"

        #-----------------------------------------------------------------------
        print_step "3" "Configuring Access Permissions"
        #-----------------------------------------------------------------------
        
        get_ad_user_groups "Add groups with sudo access (up to 4)"
        admin_groups="$USER_GROUPS"

        get_ad_user_groups "Add groups with regular access (up to 4)"
        access_groups="$USER_GROUPS"

        # Configure sudoers for admin groups
        if [[ -n "$admin_groups" ]]; then
            SUDOERS_FILE="/etc/sudoers.d/90-ad-groups"
            echo "# Sudoers file for AD groups - $(date)" > "$SUDOERS_FILE"
            for group in $admin_groups; do
                echo "%$group ALL=(ALL) NOPASSWD: ALL" >> "$SUDOERS_FILE"
            done
            chmod 640 "$SUDOERS_FILE"
            print_ok "Sudo access configured for: $admin_groups"
        fi

        # Permit access to specified groups
        combined_groups=$(echo "$admin_groups $access_groups" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' | xargs)
        if [[ -n "$combined_groups" ]]; then
            if realm permit -g $combined_groups 2>/dev/null; then
                print_ok "Login access permitted for: $combined_groups"
            else
                print_warn "Failed to configure realm permissions"
            fi
        fi

        echo ""
        echo -e "${Green}${Bold}✓ Domain enrollment completed${Reset}"
        echo ""
        return 0
    fi
}

# Install development tools and libraries
function install_devtools() {
    print_header "Development Tools Installation"

    local dev_packages=(
        "kernel-devel" "kernel-headers" "bison" "flex" "gdb" "strace" 
        "ltrace" "valgrind" "ncurses-devel" "libtool" "pkgconfig" 
        "openssl-devel"  "libcurl-devel" "libxml2-devel" 
        "zlib-devel" "bzip2-devel"  "xz-devel"  "libffi-devel"
        "python3-devel"  "perl-devel"  "java-11-openjdk-devel"
        "gcc" "make" "ncurses-devel" "gnutls-devel" "libX11-devel" "libXext-devel" 
        "libXfixes-devel" "libXft-devel" "libXt-devel" "libXi-devel" "gtk3-devel" 
        "libpng-devel" "libjpeg-turbo-devel" "giflib-devel" 
        "libtiff-devel" "hunspell" "hunspell-en" "python3.9"
    )
    
    #---------------------------------------------------------------------------
    print_step "1" "Installing Development Tools Group"
    #---------------------------------------------------------------------------
    if dnf groupinstall -y "Development Tools" &>/dev/null; then
        print_ok "Development Tools group installed"
    else
        print_error "Failed to install Development Tools group"
    fi

    #---------------------------------------------------------------------------
    print_step "2" "Installing Development Libraries"
    #---------------------------------------------------------------------------
    print_info "Installing ${#dev_packages[@]} packages..."
    install_applications "${dev_packages[@]}"

    #---------------------------------------------------------------------------
    print_step "3" "Installing Visual Studio Code"
    #---------------------------------------------------------------------------
    if ! command -v code &>/dev/null; then
        rpm -v --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null
        cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        if dnf install -y code &>/dev/null; then
            print_ok "Visual Studio Code installed"
        else
            print_error "Failed to install Visual Studio Code"
        fi
    else
        print_ok "Visual Studio Code (already installed)"
    fi

    #---------------------------------------------------------------------------
    print_step "4" "Configuring VS Code launch options"
    #---------------------------------------------------------------------------
    if [[ -f /usr/bin/code ]]; then
        local proxy_line=""
        local vscode_opts="--disable-gpu"
        
        # Check if proxy is configured in yum.conf
        if grep -q '^proxy=' /etc/yum.conf; then
            proxy_line=$(grep '^proxy=' /etc/yum.conf | head -1 | cut -d'=' -f2)
            if [[ -n "$proxy_line" ]]; then
                vscode_opts="--disable-gpu --proxy-server=$proxy_line"
            fi
        fi
        
        # Check if options already configured
        if ! grep -qF 'VSCODE_CLI_OPTIONS' /usr/bin/code; then
            # Backup original
            cp /usr/bin/code /usr/bin/code.bak
            
            # Create patched version with options
            cat > /usr/bin/code <<'ENDOFCODE'
#!/usr/bin/env bash
# Patched by rocky-setup.sh - VS Code launch options
ENDOFCODE
            echo "VSCODE_CLI_OPTIONS=\"$vscode_opts\"" >> /usr/bin/code
            cat >> /usr/bin/code <<'ENDOFCODE'

# Get the actual code binary path
VSCODE_PATH="$(dirname "$(readlink -f "$0")")"
if [[ -f "$VSCODE_PATH/code.bak" ]]; then
    ELECTRON_RUN_AS_NODE=1 exec "$VSCODE_PATH/code.bak" "$VSCODE_PATH/code.bak" $VSCODE_CLI_OPTIONS "$@"
else
    # Fallback to standard electron location
    ELECTRON="$VSCODE_PATH/../lib/code/code"
    CLI="$VSCODE_PATH/../lib/code/out/cli.js"
    ELECTRON_RUN_AS_NODE=1 exec "$ELECTRON" "$CLI" $VSCODE_CLI_OPTIONS "$@"
fi
ENDOFCODE
            chmod +x /usr/bin/code
            print_ok "VS Code configured with: $vscode_opts"
        else
            print_ok "VS Code launch options already configured"
        fi
    else
        print_warn "/usr/bin/code not found for launch option patching"
    fi

    echo ""
    echo -e "${Green}${Bold}✓ Development tools installation completed${Reset}"
    echo ""
}

# Network configuration menu
function update_network_settings() {
    print_header "Network Configuration"

    local net_tools=("NetworkManager" "NetworkManager-tui")
    print_info "Checking network management tools..."
    install_applications "${net_tools[@]}"

    while true; do
        local net_options=("List network interfaces" "Configure interface" "Create bond interface" "Back to main menu")
        show_menu "Network Options" "${net_options[@]}"

        case $menu_index in
            0) list_network_interfaces;;
            1) configure_interface;;
            2) create_bond_interface;;
            3) return;;
        esac
    done
}

function list_network_interfaces() {
    echo ""
    echo -e "${Bold}Available Network Interfaces${Reset}"
    echo -e "${Dim}$(printf '─%.0s' $(seq 1 70))${Reset}"
    printf "  ${Cyan}%-12s${Reset} %-18s %-6s %-8s %s\n" "INTERFACE" "MAC ADDRESS" "MTU" "STATE" "IP ADDRESS"
    echo -e "${Dim}$(printf '─%.0s' $(seq 1 70))${Reset}"
    
    local interfaces=($(get_interfaces_array))
    
    for iface in "${interfaces[@]}"; do
        # Skip bond slaves
        [[ -d "/sys/class/net/$iface/master" ]] && continue
        
        local mac=$(cat /sys/class/net/$iface/address 2>/dev/null || echo "N/A")
        local mtu=$(cat /sys/class/net/$iface/mtu 2>/dev/null || echo "N/A")
        local state=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "N/A")
        local ipv4=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
        [[ -z "$ipv4" ]] && ipv4="-"
        
        # Color state
        local state_color="$Red"
        [[ "$state" == "up" ]] && state_color="$Green"
        
        printf "  %-12s %-18s %-6s ${state_color}%-8s${Reset} %s\n" "$iface" "$mac" "$mtu" "$state" "$ipv4"
    done
    echo ""
}

function get_interfaces_array() {
    ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | sed 's/@.*//'
}

# Prompt user for IP configuration (DHCP or Static)
function select_ip_config() {
    local iface="$1"
    local current_ip=""
    local current_cidr=""
    
    # Get current IP address if interface is provided
    if [[ -n "$iface" ]]; then
        current_cidr=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
        current_ip="$current_cidr"
    fi
    
    local ip_options=("DHCP" "Static IP")
    show_menu "IPv4 Configuration" "${ip_options[@]}"
    
    bootproto="dhcp"
    ipaddr=""
    netmask=""
    gateway=""
    dns1=""
    dns2=""
    defroute="yes"
    
    if [[ "$menu_index" == "1" ]]; then
        bootproto="none"
        
        while true; do
            local ip_prompt="  IP address (e.g., 192.168.1.100/24)"
            [[ -n "$current_ip" ]] && ip_prompt+=" [$current_ip]"
            ip_prompt+=": "
            read -p "$ip_prompt" ip_input
            
            [[ -z "$ip_input" && -n "$current_ip" ]] && ip_input="$current_ip"
            
            if [[ "$ip_input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]{1,2})$ ]]; then
                ipaddr="${ip_input%/*}"
                local cidr="${ip_input#*/}"
                case $cidr in
                    8)  netmask="255.0.0.0";;
                    16) netmask="255.255.0.0";;
                    17) netmask="255.255.128.0";;
                    18) netmask="255.255.192.0";;
                    19) netmask="255.255.224.0";;
                    20) netmask="255.255.240.0";;
                    21) netmask="255.255.248.0";;
                    22) netmask="255.255.252.0";;
                    23) netmask="255.255.254.0";;
                    24) netmask="255.255.255.0";;
                    25) netmask="255.255.255.128";;
                    26) netmask="255.255.255.192";;
                    27) netmask="255.255.255.224";;
                    28) netmask="255.255.255.240";;
                    29) netmask="255.255.255.248";;
                    30) netmask="255.255.255.252";;
                    31) netmask="255.255.255.254";;
                    32) netmask="255.255.255.255";;
                    *)  print_warn "Unsupported CIDR: /$cidr"; continue;;
                esac
                print_ok "Netmask: $netmask (CIDR /$cidr)"
                break
            elif [[ "$ip_input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                ipaddr="$ip_input"
                break
            else
                print_warn "Invalid IP address format"
            fi
        done
        
        if [[ -z "$netmask" ]]; then
            while true; do
                read -p "  Netmask [255.255.255.0]: " netmask
                [[ -z "$netmask" ]] && netmask="255.255.255.0"
                [[ "$netmask" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break
                print_warn "Invalid netmask format"
            done
        fi
        
        read -p "  Gateway (blank for none): " gateway
        
        if [[ -n "$gateway" ]]; then
            read -p "  Primary DNS (blank for none): " dns1
            read -p "  Secondary DNS (blank for none): " dns2
        else
            dns1=""
            dns2=""
            defroute="no"
            print_info "No gateway - DNS skipped, default route disabled"
        fi
    fi
    
    if [[ -n "$gateway" ]]; then
        read -p "  Use as default route? [Y/n]: " use_defroute
        [[ "$use_defroute" =~ ^[Nn]$ ]] && defroute="no"
    fi
}

# Configure a single network interface
function configure_interface() {
    echo ""
    echo -e "${Bold}Configure Network Interface${Reset}"
    
    local all_interfaces=($(get_interfaces_array))
    local interfaces=()
    
    # Filter out bond slaves
    for iface in "${all_interfaces[@]}"; do
        [[ ! -d "/sys/class/net/$iface/master" ]] && interfaces+=("$iface")
    done
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_warn "No network interfaces found"
        return
    fi
    
    show_menu "Select interface" "${interfaces[@]}"
    local selected_iface="${interfaces[$menu_index]}"
    local current_mtu=$(cat /sys/class/net/$selected_iface/mtu 2>/dev/null || echo "1500")
    local script_file="/etc/sysconfig/network-scripts/ifcfg-$selected_iface"
    
    while true; do
        echo ""
        print_info "Configuring: $selected_iface"
        
        read -p "  New interface name [$selected_iface]: " new_name
        [[ -z "$new_name" ]] && new_name="$selected_iface"
        
        if [[ ! "$new_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
            print_warn "Invalid interface name"
            continue
        fi
        
        read -p "  MTU [$current_mtu]: " new_mtu
        [[ -z "$new_mtu" ]] && new_mtu="$current_mtu"
        
        if ! [[ "$new_mtu" =~ ^[0-9]+$ ]] || (( new_mtu < 576 || new_mtu > 9000 )); then
            print_warn "Invalid MTU (576-9000)"
            continue
        fi
        
        select_ip_config "$selected_iface"
        
        # Show summary
        local summary_items=(
            "Interface:     $new_name"
            "MTU:           $new_mtu"
            "Boot Protocol: $bootproto"
        )
        [[ "$bootproto" == "none" ]] && summary_items+=(
            "IP Address:    $ipaddr"
            "Netmask:       $netmask"
        )
        [[ -n "$gateway" ]] && summary_items+=("Gateway:       $gateway")
        [[ -n "$dns1" ]] && summary_items+=("DNS1:          $dns1")
        [[ -n "$dns2" ]] && summary_items+=("DNS2:          $dns2")
        summary_items+=("Default Route: $defroute")
        summary_items+=("IPv6:          disabled")
        
        print_summary "Interface Configuration" "${summary_items[@]}"
        
        echo ""
        read -p "  Apply configuration? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            read -p "  Return to network menu? [y/N]: " return_menu
            [[ "$return_menu" =~ ^[Yy]$ ]] && return
        fi
    done
    
    local mac_addr=$(cat /sys/class/net/$selected_iface/address 2>/dev/null)
    local new_script_file="/etc/sysconfig/network-scripts/ifcfg-$new_name"
    
    [[ -f "$new_script_file" ]] && cp "$new_script_file" "${new_script_file}.bak.$(date +%Y%m%d_%H%M%S)"
    [[ "$selected_iface" != "$new_name" && -f "$script_file" ]] && rm -f "$script_file"
    
    cat > "$new_script_file" <<EOF
# Generated by rocky-setup.sh on $(date)
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=$bootproto
DEFROUTE=$defroute
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=no
IPV6_DEFROUTE=no
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=default
NAME=$new_name
DEVICE=$new_name
ONBOOT=yes
MTU=$new_mtu
EOF

    [[ "$selected_iface" != "$new_name" && -n "$mac_addr" ]] && echo "HWADDR=$mac_addr" >> "$new_script_file"
    
    if [[ "$bootproto" == "none" ]]; then
        echo "IPADDR=$ipaddr" >> "$new_script_file"
        echo "NETMASK=$netmask" >> "$new_script_file"
        [[ -n "$gateway" ]] && echo "GATEWAY=$gateway" >> "$new_script_file"
        [[ -n "$dns1" ]] && echo "DNS1=$dns1" >> "$new_script_file"
        [[ -n "$dns2" ]] && echo "DNS2=$dns2" >> "$new_script_file"
    fi
    
    chmod 644 "$new_script_file"
    print_ok "Configuration saved: $new_script_file"
    print_warn "Reboot required to apply changes"
}

# Create a bonded network interface
function create_bond_interface() {
    echo ""
    echo -e "${Bold}Create Bond Interface${Reset}"
    
    local all_interfaces=($(get_interfaces_array))
    local physical_interfaces=()
    
    for iface in "${all_interfaces[@]}"; do
        [[ ! "$iface" =~ ^bond ]] && [[ -d "/sys/class/net/$iface/device" ]] && physical_interfaces+=("$iface")
    done
    
    if [[ ${#physical_interfaces[@]} -lt 2 ]]; then
        print_warn "At least 2 physical interfaces required for bonding"
        print_info "Available: ${physical_interfaces[*]}"
        return
    fi
    
    echo ""
    echo -e "${Dim}Available interfaces for bonding:${Reset}"
    for i in "${!physical_interfaces[@]}"; do
        local iface="${physical_interfaces[$i]}"
        local mac=$(cat /sys/class/net/$iface/address 2>/dev/null || echo "N/A")
        local state=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "N/A")
        printf "  ${Cyan}%d)${Reset} %-10s MAC: %-18s State: %s\n" "$((i+1))" "$iface" "$mac" "$state"
    done
    
    while true; do
        echo ""
        read -p "  Bond interface name (e.g., bond0): " bond_name
        if [[ ! "$bond_name" =~ ^bond[0-9]+$ ]]; then
            print_warn "Bond name format: bondX (e.g., bond0, bond1)"
            continue
        fi
        
        if [[ -f "/etc/sysconfig/network-scripts/ifcfg-$bond_name" ]]; then
            print_warn "Bond $bond_name already exists"
            continue
        fi
        
        read -p "  Select slave interfaces (space-separated numbers, e.g., '1 2'): " slave_nums
        
        local slaves=()
        for num in $slave_nums; do
            [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#physical_interfaces[@]} )) && slaves+=("${physical_interfaces[$((num-1))]}")
        done
        
        if [[ ${#slaves[@]} -lt 2 ]]; then
            print_warn "At least 2 slave interfaces required"
            continue
        fi
        
        local bond_modes=("balance-rr (Round-robin)" "active-backup (Failover)" "balance-xor" "broadcast" "802.3ad (LACP)" "balance-tlb" "balance-alb")
        show_menu "Select bond mode" "${bond_modes[@]}"
        
        local bond_mode="active-backup"
        local bond_opts="miimon=100"
        
        case $menu_index in
            0) bond_mode="balance-rr";;
            1) bond_mode="active-backup";;
            2) bond_mode="balance-xor";;
            3) bond_mode="broadcast";;
            4) bond_mode="802.3ad"; bond_opts="miimon=100 lacp_rate=1";;
            5) bond_mode="balance-tlb";;
            6) bond_mode="balance-alb";;
        esac
        
        read -p "  MTU [1500]: " bond_mtu
        [[ -z "$bond_mtu" ]] && bond_mtu="1500"
        
        if ! [[ "$bond_mtu" =~ ^[0-9]+$ ]] || (( bond_mtu < 576 || bond_mtu > 9000 )); then
            print_warn "Invalid MTU (576-9000)"
            continue
        fi
        
        select_ip_config
        
        # Show summary
        local summary_items=(
            "Bond Name:     $bond_name"
            "Bond Mode:     $bond_mode"
            "Slaves:        ${slaves[*]}"
            "MTU:           $bond_mtu"
            "Boot Protocol: $bootproto"
        )
        [[ "$bootproto" == "none" ]] && summary_items+=(
            "IP Address:    $ipaddr"
            "Netmask:       $netmask"
        )
        [[ -n "$gateway" ]] && summary_items+=("Gateway:       $gateway")
        [[ -n "$dns1" ]] && summary_items+=("DNS1:          $dns1")
        [[ -n "$dns2" ]] && summary_items+=("DNS2:          $dns2")
        summary_items+=("Default Route: $defroute")
        
        print_summary "Bond Configuration" "${summary_items[@]}"
        
        echo ""
        read -p "  Create this bond? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            read -p "  Return to network menu? [y/N]: " return_menu
            [[ "$return_menu" =~ ^[Yy]$ ]] && return
        fi
    done
    
    # Create bond configuration
    local bond_file="/etc/sysconfig/network-scripts/ifcfg-$bond_name"
    
    cat > "$bond_file" <<EOF
# Generated by rocky-setup.sh on $(date)
TYPE=Bond
BONDING_MASTER=yes
NAME=$bond_name
DEVICE=$bond_name
ONBOOT=yes
BOOTPROTO=$bootproto
DEFROUTE=$defroute
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=no
IPV6_DEFROUTE=no
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=default
MTU=$bond_mtu
BONDING_OPTS="mode=$bond_mode $bond_opts"
EOF
    
    if [[ "$bootproto" == "none" ]]; then
        echo "IPADDR=$ipaddr" >> "$bond_file"
        echo "NETMASK=$netmask" >> "$bond_file"
        [[ -n "$gateway" ]] && echo "GATEWAY=$gateway" >> "$bond_file"
        [[ -n "$dns1" ]] && echo "DNS1=$dns1" >> "$bond_file"
        [[ -n "$dns2" ]] && echo "DNS2=$dns2" >> "$bond_file"
    fi
    
    chmod 644 "$bond_file"
    print_ok "Bond config: $bond_file"
    
    # Create slave configurations
    for slave in "${slaves[@]}"; do
        local slave_file="/etc/sysconfig/network-scripts/ifcfg-$slave"
        local slave_mac=$(cat /sys/class/net/$slave/address 2>/dev/null)
        
        [[ -f "$slave_file" ]] && cp "$slave_file" "${slave_file}.bak.$(date +%Y%m%d_%H%M%S)"
        
        cat > "$slave_file" <<EOF
# Generated by rocky-setup.sh on $(date)
TYPE=Ethernet
NAME=$slave
DEVICE=$slave
ONBOOT=yes
BOOTPROTO=none
MASTER=$bond_name
SLAVE=yes
MTU=$bond_mtu
IPV6INIT=no
IPV6_AUTOCONF=no
EOF
        
        [[ -n "$slave_mac" ]] && echo "HWADDR=$slave_mac" >> "$slave_file"
        chmod 644 "$slave_file"
        print_ok "Slave config: $slave_file"
    done
    
    # Load bonding module
    if ! lsmod | grep -q "^bonding"; then
        modprobe bonding
        echo "bonding" > /etc/modules-load.d/bonding.conf
        print_ok "Bonding module loaded"
    fi
    
    print_warn "Reboot required to apply changes"
    echo ""
}

# Install xrdp remote desktop
function install_xrdp() {
    print_header "xrdp Remote Desktop Installation"

    if rpm -q --quiet xrdp; then
        print_ok "xrdp already installed"
        return 0
    fi

    local allow_clipboard="N"
    local allow_drivemap="N"

    while true; do
        echo ""
        printf "  ${Cyan}1.${Reset} Allow clipboard (cut/copy from server)? "
        read -p "[y/N]: " clipboard_input
        [[ "$clipboard_input" =~ ^[Yy]$ ]] && allow_clipboard="Y"

        printf "  ${Cyan}2.${Reset} Allow drive mapping (map remote drives)? "
        read -p "[y/N]: " drivemap_input
        [[ "$drivemap_input" =~ ^[Yy]$ ]] && allow_drivemap="Y"

        local summary_items=(
            "Clipboard:     $allow_clipboard"
            "Drive Mapping: $allow_drivemap"
        )
        print_summary "xrdp Configuration" "${summary_items[@]}"

        echo ""
        read -p "  Proceed with installation? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            read -p "  Return to remote desktop menu? [y/N]: " return_menu
            [[ "$return_menu" =~ ^[Yy]$ ]] && return
        fi
    done

    #---------------------------------------------------------------------------
    print_step "1" "Installing xrdp packages"
    #---------------------------------------------------------------------------
    local xrdp_packages=("tigervnc" "tigervnc-server" "xrdp")
    install_applications "${xrdp_packages[@]}"

    #---------------------------------------------------------------------------
    print_step "2" "Configuring xrdp"
    #---------------------------------------------------------------------------
    local xrdp_ini="/etc/xrdp/xrdp.ini"

    # Enable channels
    sed -i 's/^allow_channels=.*/allow_channels=true/' "$xrdp_ini" 2>/dev/null || echo "allow_channels=true" >> "$xrdp_ini"

    # Drive remap
    if [[ "$allow_drivemap" == "Y" ]]; then
        sed -i 's/^rdpdr=.*/rdpdr=true/' "$xrdp_ini" 2>/dev/null
    else
        sed -i 's/^rdpdr=.*/rdpdr=false/' "$xrdp_ini" 2>/dev/null
    fi

    # Sound
    sed -i 's/^rdpsnd=.*/rdpsnd=true/' "$xrdp_ini" 2>/dev/null

    # Clipboard
    if [[ "$allow_clipboard" == "Y" ]]; then
        sed -i 's/^cliprdr=.*/cliprdr=true/' "$xrdp_ini" 2>/dev/null
    else
        sed -i 's/^cliprdr=.*/cliprdr=false/' "$xrdp_ini" 2>/dev/null
    fi

    print_ok "xrdp.ini configured"

    #---------------------------------------------------------------------------
    print_step "3" "Configuring Firewall"
    #---------------------------------------------------------------------------
    firewall-cmd --permanent -q --add-port=3389/tcp
    firewall-cmd -q --reload
    print_ok "Port 3389/tcp opened"

    #---------------------------------------------------------------------------
    print_step "4" "Starting xrdp Service"
    #---------------------------------------------------------------------------
    systemctl enable xrdp -q
    systemctl restart xrdp -q
    print_ok "xrdp service enabled and started"

    #---------------------------------------------------------------------------
    print_step "5" "Configuring User Session"
    #---------------------------------------------------------------------------
    echo "mate-session" > /etc/skel/.Xclients
    chmod a+x /etc/skel/.Xclients
    print_ok "Default session set to MATE"

    # Update existing user homes
    for user_home in /home/*; do
        if [[ -d "$user_home" ]]; then
            local user=$(basename "$user_home")
            cp /etc/skel/.Xclients "$user_home/.Xclients"
            chown "$user:" "$user_home/.Xclients"
            chmod a+x "$user_home/.Xclients"
        fi
    done
    print_ok "Existing user homes updated"

    echo ""
    echo -e "${Green}${Bold}✓ xrdp installation completed${Reset}"
    echo ""
}

# Install RealVNC Server
function install_realvnc() {
    print_header "RealVNC Server Installation"

    local http_base="https://download.creekside.network/resource/apps/realVNC"
    local http_user="downloader"
    local http_pass="Khyp04682"

    if rpm -q --quiet realvnc-vnc-server; then
        print_ok "RealVNC Server already installed"
        return 0
    fi

    local allow_clipboard="N"
    local allow_fileshare="N"
    local license_key=""

    while true; do
        echo ""
        # Check if xrdp is installed
        if rpm -q --quiet xrdp; then
            print_warn "xrdp is installed and will be removed"
        fi

        printf "  ${Cyan}1.${Reset} License key (xxxxx-xxxxx-xxxxx-xxxxx-xxxxx): "
        read license_key
        if [[ ! "$license_key" =~ ^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$ ]]; then
            print_warn "Invalid license key format"
            continue
        fi

        printf "  ${Cyan}2.${Reset} Allow clipboard (cut/copy from server)? "
        read -p "[y/N]: " clipboard_input
        [[ "$clipboard_input" =~ ^[Yy]$ ]] && allow_clipboard="Y"

        printf "  ${Cyan}3.${Reset} Allow file sharing? "
        read -p "[y/N]: " fileshare_input
        [[ "$fileshare_input" =~ ^[Yy]$ ]] && allow_fileshare="Y"

        local summary_items=(
            "License Key:   ${license_key:0:5}-*****-*****-*****-${license_key: -5}"
            "Clipboard:     $allow_clipboard"
            "File Sharing:  $allow_fileshare"
        )
        print_summary "RealVNC Configuration" "${summary_items[@]}"

        echo ""
        read -p "  Proceed with installation? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            read -p "  Return to remote desktop menu? [y/N]: " return_menu
            [[ "$return_menu" =~ ^[Yy]$ ]] && return
        fi
    done

    #---------------------------------------------------------------------------
    print_step "1" "Removing Conflicting Packages"
    #---------------------------------------------------------------------------
    if rpm -q --quiet xrdp; then
        dnf remove -y tigervnc tigervnc-server xrdp &>/dev/null
        firewall-cmd --permanent --remove-port=3389/tcp &>/dev/null
        print_ok "Removed xrdp and related packages"
    else
        print_ok "No conflicting packages found"
    fi

    #---------------------------------------------------------------------------
    print_step "2" "Installing VNC Dummy Video Driver"
    #---------------------------------------------------------------------------
    # Install development tools if needed
    if ! rpm -q --quiet gcc; then
        dnf groupinstall -y "Development Tools" &>/dev/null
        print_ok "Development tools installed"
    fi

    local vnc_dev_packages=("autoconf" "automake" "libtool" "make" "pkgconfig" "xorg-x11-server-devel")
    install_applications "${vnc_dev_packages[@]}"

    local work_dir=$(mktemp -d)
    
    # Download and build VNC driver
    curl --silent --user "$http_user:$http_pass" "$http_base/driver/xf86-video-vnc-master.zip" -o "$work_dir/xf86-video-vnc-master.zip"
    
    if [[ -f "$work_dir/xf86-video-vnc-master.zip" ]]; then
        cd "$work_dir"
        unzip -q xf86-video-vnc-master.zip
        cd xf86-video-vnc-master
        ./buildAndInstall automated &>/dev/null
        print_ok "VNC dummy video driver installed"
    else
        print_warn "Could not download VNC driver (optional for 4K support)"
    fi

    #---------------------------------------------------------------------------
    print_step "3" "Downloading RealVNC Server"
    #---------------------------------------------------------------------------
    # Find the latest RPM in the server directory
    local vnc_rpm=""
    while read -r filename; do
        if [[ "$filename" == *"Linux-x64.rpm" && "$filename" != *"@"* ]]; then
            vnc_rpm="$filename"
            break
        fi
    done < <(curl --silent --user "$http_user:$http_pass" "$http_base/server/" 2>/dev/null | grep -oP 'href="\K[^"]+\.rpm')

    if [[ -z "$vnc_rpm" ]]; then
        print_error "No RealVNC RPM package found"
        rm -rf "$work_dir"
        return 1
    fi

    curl -# --user "$http_user:$http_pass" "$http_base/server/$vnc_rpm" -o "$work_dir/$vnc_rpm"
    print_ok "Downloaded: $vnc_rpm"

    #---------------------------------------------------------------------------
    print_step "4" "Installing RealVNC Server"
    #---------------------------------------------------------------------------
    if dnf localinstall -y "$work_dir/$vnc_rpm" &>/dev/null; then
        print_ok "RealVNC Server installed"
    else
        print_error "Failed to install RealVNC Server"
        rm -rf "$work_dir"
        return 1
    fi

    #---------------------------------------------------------------------------
    print_step "5" "Configuring RealVNC"
    #---------------------------------------------------------------------------
    mkdir -p /etc/vnc/config.d

    cat > /etc/vnc/config.d/common.custom <<EOF
DisableOptions=FALSE
EnableRemotePrinting=FALSE
Encryption=AlwaysOn
AllowChangeDefaultPrinter=FALSE
AcceptCutText=TRUE
Authentication=SystemAuth
RootSecurity=TRUE
AuthTimeout=30
BlackListThreshold=10
BlackListTimeout=30
DisableAddNewClient=TRUE
DisableTrayIcon=2
EnableManualUpdateChecks=FALSE
EnableAutoUpdateChecks=0
GuestAccess=0
EnableGuestLogin=FALSE
AllowTcpListenRfb=TRUE
AllowHTTP=FALSE
IdleTimeout=0
QuitOnCloseStatusDialog=FALSE
AlwaysShared=TRUE
NeverShared=FALSE
DisconnectClients=FALSE
ServiceDiscoveryEnabled=FALSE
_ConnectToExisting=1
RandR=1920x1080,3840x2160,3840x1080,3840x1440,2560x1080,1680x1050,1600x1200,1400x1050,1360x768,1280x1024,1280x960,1280x800,1024x768
EOF

    # Clipboard setting
    if [[ "$allow_clipboard" == "Y" ]]; then
        echo "SendCutText=TRUE" >> /etc/vnc/config.d/common.custom
    else
        echo "SendCutText=FALSE" >> /etc/vnc/config.d/common.custom
    fi

    # File sharing setting
    if [[ "$allow_fileshare" == "Y" ]]; then
        echo "ShareFiles=TRUE" >> /etc/vnc/config.d/common.custom
    else
        echo "ShareFiles=FALSE" >> /etc/vnc/config.d/common.custom
    fi

    print_ok "VNC configuration created"

    # Configure PAM authentication
    cat > /etc/pam.d/vncserver.custom <<EOF
auth include password-auth
account include password-auth
session include password-auth
EOF
    echo "PamApplicationName=vncserver.custom" >> /etc/vnc/config.d/common.custom
    print_ok "PAM authentication configured"

    #---------------------------------------------------------------------------
    print_step "6" "Adding License Key"
    #---------------------------------------------------------------------------
    if vnclicense -add "$license_key" &>/dev/null; then
        print_ok "License key added"
    else
        print_error "Failed to add license key"
    fi

    #---------------------------------------------------------------------------
    print_step "7" "Configuring Firewall"
    #---------------------------------------------------------------------------
    firewall-cmd --permanent --add-service=vncserver-virtuald &>/dev/null
    firewall-cmd --reload &>/dev/null
    print_ok "Firewall configured for VNC"

    #---------------------------------------------------------------------------
    print_step "8" "Starting VNC Service"
    #---------------------------------------------------------------------------
    systemctl enable vncserver-virtuald.service --now &>/dev/null
    print_ok "VNC virtual desktop service started"

    #---------------------------------------------------------------------------
    print_step "9" "Configuring User Session"
    #---------------------------------------------------------------------------
    echo "mate-session" > /etc/skel/.Xclients
    chmod a+x /etc/skel/.Xclients
    print_ok "Default session set to MATE"

    # Update existing user homes
    for user_home in /home/*; do
        if [[ -d "$user_home" ]]; then
            local user=$(basename "$user_home")
            cp /etc/skel/.Xclients "$user_home/.Xclients"
            chown "$user:" "$user_home/.Xclients"
            chmod a+x "$user_home/.Xclients"
        fi
    done
    print_ok "Existing user homes updated"

    rm -rf "$work_dir"

    echo ""
    echo -e "${Green}${Bold}✓ RealVNC Server installation completed${Reset}"
    echo ""
}

# Install ETX Connection Node
function install_etx_node() {
    print_header "ETX Connection Node Installation"

    local etx_cn_path="/opt/etx/cn"
    local install_path="/opt/etx/packages"
    local http_base="https://download.creekside.network/resource/apps/etx"
    local http_user="downloader"
    local http_pass="Khyp04682"
    mkdir -p "$install_path"

    if systemctl is-enabled otetxcn.service &>/dev/null; then
        print_ok "ETX Connection Node already installed at $etx_cn_path"
        return 0
    fi

    #---------------------------------------------------------------------------
    print_step "1" "Checking Available Versions"
    #---------------------------------------------------------------------------
    local etx_versions=()
    
    # List version directories from HTTP directory listing (12.5.3, 12.5.4, etc.)
    while read -r dirname; do
        # Filter for version-like directories (e.g., 12.5.3, 12.5.4)
        if [[ "$dirname" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            etx_versions+=("$dirname")
        fi
    done < <(curl --silent --user "$http_user:$http_pass" "$http_base/" 2>/dev/null | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/")')

    if [[ ${#etx_versions[@]} -eq 0 ]]; then
        print_error "No ETX versions found"
        return 1
    fi

    # Sort versions and show menu
    IFS=$'\n' etx_versions=($(sort -V <<<"${etx_versions[*]}")); unset IFS
    
    echo ""
    show_menu "Select ETX version" "${etx_versions[@]}"
    local selected_version="${etx_versions[$menu_index]}"
    print_info "Selected version: $selected_version"

    #---------------------------------------------------------------------------
    print_step "2" "Finding Linux Package"
    #---------------------------------------------------------------------------
    local etx_file=""
    
    # Look for linux-x64 package in ETXConnectionNode directory
    # Try different possible paths based on directory structure
    local search_paths=(
        "$http_base/$selected_version/ETXConnectionNode/"
        "$http_base/$selected_version/"
    )
    
    for search_path in "${search_paths[@]}"; do
        while read -r filename; do
            if [[ "$filename" == *"linux-x64"* && "$filename" == *".tar.gz" ]]; then
                etx_file="$filename"
                print_info "Found package: $etx_file"
                break 2
            fi
        done < <(curl --silent --user "$http_user:$http_pass" "$search_path" 2>/dev/null | grep -oP 'href="\K[^"]+linux-x64[^"]*\.tar\.gz')
    done

    if [[ -z "$etx_file" ]]; then
        print_error "No Linux package found for version $selected_version"
        return 1
    fi

    #---------------------------------------------------------------------------
    print_step "3" "Downloading Package"
    #---------------------------------------------------------------------------
    local download_url="$http_base/$selected_version/ETXConnectionNode/$etx_file"
    local install_file="$install_path/$etx_file"
    
    curl -# --user "$http_user:$http_pass" "$download_url" -o "$install_file"

    if [[ ! -f "$install_file" ]] || [[ ! -s "$install_file" ]]; then
        print_error "Download failed"
        return 1
    fi
    print_ok "Downloaded: $etx_file"

    #---------------------------------------------------------------------------
    print_step "4" "Installing ETX Connection Node"
    #---------------------------------------------------------------------------
    mkdir -p "$etx_cn_path"
    tar xzf "$install_file" --strip-components=1 -C "$etx_cn_path"

    local work_dir=$(mktemp -d)
    cat > "$work_dir/install_options" <<EOF
install.etxcn.ListenPort=5510
install.etxcn.StartNow=1
install.etxcn.AllowMigrate=0
install.etxcn.CreateETXProxyUser=0
install.etxcn.CreateETXXstartUser=0
install.service.createservice=1
install.service.bBootStart=1
install.register.bAutoRegister=0
install.register.r_WebAdaptor=0
install.register.WebAdaptorPort=5510
install.register.r_auth=0
install.register.r_appscan=0
install.register.r_firstdisplay=1
install.register.r_maxtotalsessions=30
install.register.r_maxsessperuser=2
install.register.r_allownewsess=1
install.register.r_ssrconfig=0
install.register.r_selinuxsetup=0
install.register.r_vdinode=0
EOF
    "$etx_cn_path/bin/install" -s "$work_dir/install_options" &>/dev/null
    print_ok "ETX Connection Node installed"

    #---------------------------------------------------------------------------
    print_step "5" "Configuring Authentication"
    #---------------------------------------------------------------------------
    cp /etc/pam.d/sshd /etc/pam.d/exceed-connection-node
    print_ok "PAM authentication configured"

    # Prevent core dumps
    echo 'ulimit -c 0 > /dev/null 2>&1' > /etc/profile.d/disable-coredumps.sh
    print_ok "Core dumps disabled"

    #---------------------------------------------------------------------------
    print_step "5" "Configuring Firewall"
    #---------------------------------------------------------------------------
    firewall-cmd -q --permanent --add-port=5510/tcp
    firewall-cmd -q --reload
    print_ok "Port 5510/tcp opened"

    rm -rf "$work_dir"

    echo ""
    echo -e "${Green}${Bold}✓ ETX Connection Node installation completed${Reset}"
    echo ""
}

# Install ETX Server
function install_etx_server() {
    print_header "ETX Server Installation"

    local install_path="/opt/etx/packages"
    local http_base="https://download.creekside.network/resource/apps/etx"
    local http_user="downloader"
    local http_pass="Khyp04682"
    mkdir -p "$install_path"

    if systemctl is-enabled otetxsvr.service &>/dev/null; then
        print_ok "ETX Server already installed"
        return 0
    fi

    local etx_admin_passwd="Good2Great"
    local standalone="Y"

    while true; do
        echo ""
        printf "  ${Cyan}1.${Reset} Standalone mode (N for cluster)? "
        read -p "[Y/n]: " standalone_input
        [[ "$standalone_input" =~ ^[Nn]$ ]] && standalone="N" || standalone="Y"

        printf "  ${Cyan}2.${Reset} ETX admin password "
        read -p "[$etx_admin_passwd]: " passwd_input
        [[ -n "$passwd_input" ]] && etx_admin_passwd="$passwd_input"

        local summary_items=(
            "Mode:           $([ "$standalone" == "Y" ] && echo "Standalone" || echo "Cluster")"
            "Admin Password: $etx_admin_passwd"
        )
        print_summary "ETX Server Configuration" "${summary_items[@]}"

        echo ""
        read -p "  Proceed with installation? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            read -p "  Return to remote desktop menu? [y/N]: " return_menu
            [[ "$return_menu" =~ ^[Yy]$ ]] && return
        fi
    done

    #---------------------------------------------------------------------------
    print_step "1" "Checking Available Versions"
    #---------------------------------------------------------------------------
    local etx_versions=()
    
    # List version directories (12.5.3, 12.5.4, etc.)
    while read -r dirname; do
        # Filter for version-like directories (e.g., 12.5.3, 12.5.4)
        if [[ "$dirname" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            etx_versions+=("$dirname")
        fi
    done < <(curl --silent --user "$http_user:$http_pass" "$http_base/" 2>/dev/null | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/")')

    if [[ ${#etx_versions[@]} -eq 0 ]]; then
        print_error "No ETX versions found"
        return 1
    fi

    # Sort versions and show menu
    IFS=$'\n' etx_versions=($(sort -V <<<"${etx_versions[*]}")); unset IFS
    
    echo ""
    show_menu "Select ETX version" "${etx_versions[@]}"
    local selected_version="${etx_versions[$menu_index]}"
    print_info "Selected version: $selected_version"

    #---------------------------------------------------------------------------
    print_step "2" "Finding Linux Package"
    #---------------------------------------------------------------------------
    local etx_file=""
    
    # Look for linux-x64 package in ETXServer directory
    local search_paths=(
        "$http_base/$selected_version/ETXServer/"
        "$http_base/$selected_version/"
    )
    
    for search_path in "${search_paths[@]}"; do
        while read -r filename; do
            if [[ "$filename" == *"linux-x64"* && "$filename" == *".tar.gz" ]]; then
                etx_file="$filename"
                print_info "Found package: $etx_file"
                break 2
            fi
        done < <(curl --silent --user "$http_user:$http_pass" "$search_path" 2>/dev/null | grep -oP 'href="\K[^"]+linux-x64[^"]*\.tar\.gz')
    done

    if [[ -z "$etx_file" ]]; then
        print_error "No Linux package found for version $selected_version"
        return 1
    fi

    #---------------------------------------------------------------------------
    print_step "3" "Downloading Package"
    #---------------------------------------------------------------------------
    local download_url="$http_base/$selected_version/ETXServer/$etx_file"
    local install_file="$install_path/$etx_file"
    
    curl -# --user "$http_user:$http_pass" "$download_url" -o "$install_file"

    if [[ ! -f "$install_file" ]] || [[ ! -s "$install_file" ]]; then
        print_error "Download failed"
        return 1
    fi
    print_ok "Downloaded: $etx_file"

    #---------------------------------------------------------------------------
    print_step "4" "Installing ETX Server"
    #---------------------------------------------------------------------------
    local etx_svr_path="/opt/etx/svr"
    mkdir -p "$etx_svr_path"
    tar xzf "$install_file" --strip-components=1 -C "$etx_svr_path"

    if [[ "$standalone" == "Y" ]]; then
        "$etx_svr_path/bin/etxsvr" datastore init
        "$etx_svr_path/bin/etxsvr" bootstart enable
        "$etx_svr_path/bin/etxsvr" config eulaAccepted=1
        "$etx_svr_path/bin/etxsvr" etxadmin setpasswd -p "$etx_admin_passwd"
        print_ok "Standalone mode configured"
    fi

    #---------------------------------------------------------------------------
    print_step "5" "Configuring Firewall"
    #---------------------------------------------------------------------------
    firewall-cmd -q --permanent --add-port={5510/tcp,5610/tcp,8080/tcp,8443/tcp}
    firewall-cmd -q --reload
    print_ok "Ports 5510,5610,8080,8443/tcp opened"

    #---------------------------------------------------------------------------
    print_step "6" "Starting ETX Server"
    #---------------------------------------------------------------------------
    "$etx_svr_path/bin/etxsvr" start
    print_ok "ETX Server started"

    echo ""
    echo -e "${Green}${Bold}✓ ETX Server installation completed${Reset}"
    echo ""
}

# Remote Desktop menu
function install_remote_desktop() {
    print_header "Remote Desktop Installation"

    # Check if MATE desktop is installed
    local mate_installed="N"
    if command -v mate-session &>/dev/null; then
        mate_installed="Y"
        print_ok "MATE desktop detected"
    else
        print_warn "MATE desktop NOT installed"
        print_info "Only ETX Server installation is available without desktop"
    fi

    while true; do
        echo ""
        if [[ "$mate_installed" == "Y" ]]; then
            local rd_options=("xrdp (RDP protocol)" "RealVNC Server" "ETX Server" "ETX Connection Node" "Back to main menu")
        else
            local rd_options=("ETX Server" "Back to main menu")
        fi

        show_menu "Remote Desktop Options" "${rd_options[@]}"

        if [[ "$mate_installed" == "Y" ]]; then
            case $menu_index in
                0) install_xrdp;;
                1) install_realvnc;;
                2) install_etx_server;;
                3) install_etx_node;;
                4) return;;
            esac
        else
            case $menu_index in
                0) install_etx_server;;
                1) return;;
            esac
        fi
    done
}

# Main program
function main() {
    # Professional banner
    echo ""
    echo -e "${Cyan}╔═══════════════════════════════════════════════════════════╗${Reset}"
    echo -e "${Cyan}║${Reset}  ${Bold}Rocky Linux Setup Utility${Reset}                                ${Cyan}║${Reset}"
    echo -e "${Cyan}║${Reset}  Version 1.0                                              ${Cyan}║${Reset}"
    echo -e "${Cyan}║${Reset}  (c) 2021-2025 Creekside Networks LLC                     ${Cyan}║${Reset}"
    echo -e "${Cyan}╚═══════════════════════════════════════════════════════════╝${Reset}"

    # Ensure running as root
    if [[ $(id -u) -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi

    # Check OS version
    os_name=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | cut -d. -f1)
    if [[ "$os_name" != "rocky" ]]; then
        print_error "This script is for Rocky Linux only. Detected: $os_name $os_version"
        exit 1
    fi
    print_ok "Rocky Linux $os_version detected"

    # Add SSH public keys to root
    add_root_ssh_keys

    # Main loop
    while true; do
        local menu_items=(
            "System Initialization" 
            "Update Repository Mirrors" 
            "Install Desktop Environment" 
            "Install Development Tools"
            "Install Remote Desktop"
            "Configure Network"
            "Join Domain (AD/FreeIPA)"
            "Exit"
        )
        show_menu "Main Menu" "${menu_items[@]}"
        
        case $menu_index in
            0) initialization;;
            1) yum_configure_mirror;;
            2) install_desktop;;
            3) install_devtools;;
            4) install_remote_desktop;;
            5) update_network_settings;;
            6) enroll_domain;;
            7) cleanup_existing;;
        esac
    done
}

main "$@"