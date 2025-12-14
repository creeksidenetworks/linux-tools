#!/bin/bash
#===============================================================================
# Ubuntu Linux Setup Utility
# Version: 1.0
# Author: Jackson Tong / Creekside Networks LLC
# License: MIT
#
# Description:
#   Comprehensive setup and configuration utility for Ubuntu Linux 18.04+.
#   Provides menu-driven interface for system initialization, network
#   configuration, desktop environment installation, and domain enrollment.
#
# Usage:
#   Local:  sudo ./ubuntu-setup.sh
#   Remote: ssh -t <host> "$(<./ubuntu-setup.sh)"
#
# Requirements:
#   - Ubuntu 18.04 LTS or newer
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
declare -A APT_MIRRORS
APT_MIRRORS["US"]="http://archive.ubuntu.com/ubuntu"
APT_MIRRORS["CN"]="https://mirrors.aliyun.com/ubuntu"
APT_MIRRORS["GB"]="http://gb.archive.ubuntu.com/ubuntu"
APT_MIRRORS["AE"]="http://ae.archive.ubuntu.com/ubuntu"

# Create temporary file for script operations and ensure cleanup on exit
tmp_file=$(mktemp /tmp/ubuntu-setup.XXXXXX)
trap cleanup_existing EXIT

# Cleanup function - called on script exit (normal or interrupted)
function cleanup_existing() {
    echo ""
    echo -e "${Dim}Cleaning up and exiting...${Reset}"
    rm -f "$tmp_file"
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

# Generic menu function - displays numbered options and captures user selection
# Arguments:
#   $1: Menu title
#   $2: Default option (1-based index, optional)
#   $@: Menu options (remaining arguments)
# Sets global variable:
#   menu_index: 0-based index of selected option
function show_menu() {
    local title="$1"
    shift
    local default_choice=0
    
    # Check if second argument is a number (default choice)
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        default_choice=$1
        shift
    fi
    
    local options=("$@")
    echo ""
    echo -e "${Green}${Bold}$title${Reset}"
    for i in "${!options[@]}"; do
        printf "  ${Cyan}%d)${Reset} %s\n" "$((i+1))" "${options[$i]}"
    done
    echo ""
    if [[ $default_choice -gt 0 ]]; then
        echo -n "  Select [$default_choice]: "
    else
        echo -n "  Select: "
    fi
    read user_choice
    
    # Use default if empty or invalid input
    if [[ -z "$user_choice" ]]; then
        user_choice=$default_choice
    fi
    if ! [[ "$user_choice" =~ ^[0-9]+$ ]] || (( user_choice < 1 || user_choice > ${#options[@]} )); then
        if [[ $default_choice -gt 0 ]]; then
            user_choice=$default_choice
        else
            user_choice=${#options[@]}
        fi
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
    fi
    if [[ -z "$COUNTRY" ]] || [[ ! " ${countries[@]} " =~ " $COUNTRY " ]]; then
        echo -e "⚠️  Could not retrieve geolocation info, use USA as default."
        COUNTRY="US"
        TIMEZONE="America/Los_Angeles"
    fi
    export COUNTRY TIMEZONE
}

# Interactive menu to select country for apt mirror
# Detects current location and offers it as default
function select_mirror_country() {
    # Auto-detect location first
    detect_location
    local detected_country="$COUNTRY"
    
    # Find the index of detected country
    local default_index=0
    for i in "${!countries[@]}"; do
        if [[ "${countries[$i]}" == "$detected_country" ]]; then
            default_index=$i
            break
        fi
    done
    
    # Build menu options
    local menu_options=()
    for i in "${!countries[@]}"; do
        local country_code="${countries[$i]}"
        local region_name="${regions[$i]}"
        local mirror_url="${APT_MIRRORS[$country_code]}"
        
        if [[ "$country_code" == "$detected_country" ]]; then
            menu_options+=("$region_name ($country_code) - $mirror_url [detected]")
        else
            menu_options+=("$region_name ($country_code) - $mirror_url")
        fi
    done
    
    # Show menu with detected country as default
    show_menu "Select APT Mirror Country:" "$((default_index+1))" "${menu_options[@]}"
    
    # Use selected country
    COUNTRY="${countries[$menu_index]}"
    
    export COUNTRY
    echo -e "${Green}✓${Reset} Selected mirror country: $COUNTRY (${regions[$menu_index]})\n"
}

# Configure apt repository mirrors based on detected/selected country
function apt_configure_mirror() {
    # Let user select mirror country (with auto-detection as default)
    select_mirror_country
    echo "  Configuring apt repositories for $COUNTRY"
    local mirror_url="${APT_MIRRORS[$COUNTRY]}"
    
    # Fallback to US if country not found in mirrors
    if [[ -z "$mirror_url" ]]; then
        mirror_url="${APT_MIRRORS[US]}"
    fi

    # Backup original sources.list
    if [[ ! -f /etc/apt/sources.list.bak ]]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        print_ok "Backed up original sources.list"
    fi

    # Get Ubuntu codename
    local codename=$(lsb_release -cs)
    
    # Create new sources.list
    cat > /etc/apt/sources.list <<EOF
# Ubuntu repositories - configured by ubuntu-setup.sh
# Mirror: $mirror_url

deb $mirror_url $codename main restricted universe multiverse
deb $mirror_url $codename-updates main restricted universe multiverse
deb $mirror_url $codename-backports main restricted universe multiverse
deb $mirror_url $codename-security main restricted universe multiverse

# deb-src $mirror_url $codename main restricted universe multiverse
# deb-src $mirror_url $codename-updates main restricted universe multiverse
# deb-src $mirror_url $codename-backports main restricted universe multiverse
# deb-src $mirror_url $codename-security main restricted universe multiverse
EOF

    print_ok "APT sources configured → $mirror_url"
    
    # Update package lists
    print_info "Updating package lists..."
    apt-get update -qq &>/dev/null
    print_ok "Package lists updated"
}

# Install packages using apt, skipping already-installed packages
# Arguments: List of package names to install
# Outputs success/failure message for each package
function install_applications() {
    local packages=("$@")
    local installed=0
    local failed=0
    local skipped=0
    
    for package in "${packages[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            ((skipped++))
        elif apt-get install -yq "$package" &>/dev/null; then
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
        read -p "Configure apt proxy? [y/N]: " use_proxy
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
    
    # Configure apt proxy
    if [[ -n "$proxy_url" ]]; then
        cat > /etc/apt/apt.conf.d/95proxy <<EOF
Acquire::http::Proxy "$proxy_url";
Acquire::https::Proxy "$proxy_url";
EOF
        print_ok "APT proxy configured"

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
    timedatectl set-timezone "${TIMEZONE}"
    print_ok "Timezone: ${TIMEZONE}"

    # Set hostname
    if [[ -n "$new_hostname" ]]; then
        hostnamectl set-hostname "$new_hostname"
        print_ok "Hostname: $new_hostname"
    fi

    # Disable swap (optional for server deployments)
    # swapoff -a
    # sed -i '/swap/d' /etc/fstab
    # print_ok "Swap disabled"

    #---------------------------------------------------------------------------
    print_step "2" "Configuring Repositories"
    #---------------------------------------------------------------------------
    
    # Configure apt mirrors
    apt_configure_mirror

    #---------------------------------------------------------------------------
    print_step "3" "Updating System Packages"
    #---------------------------------------------------------------------------
    
    print_info "Running system update (this may take a few minutes)..."
    export DEBIAN_FRONTEND=noninteractive
    if apt-get upgrade -yq &>/dev/null; then
        print_ok "System packages updated successfully"
    else
        print_warn "System update completed with some warnings"
    fi

    #---------------------------------------------------------------------------
    print_step "4" "Installing Essential Packages"
    #---------------------------------------------------------------------------
    
    local default_packages=(
        "zsh" "ksh" "csh" "xterm" "ethtool" "vim"
        "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
        "software-properties-common" "tree"
        "nano" "htop" "pwgen"
        "nfs-common" "cifs-utils" "smbclient" "autofs"
        "subversion" "ansible"
        "iperf3" "traceroute" "mtr-tiny"
        "tar" "zip" "unzip" "p7zip-full" "cabextract"
        "rsync" "curl" "ftp" "wget"
        "telnet" "jq" "lsof" "dnsutils" "tcpdump" "net-tools"
        "openssl" "libsasl2-modules" "ldap-utils"
        "sssd" "sssd-tools" "realmd" "packagekit"
        "adcli" "samba-common-bin" "krb5-user"
        "ufw" "policycoreutils"
    )

    print_info "Installing ${#default_packages[@]} packages..."
    install_applications "${default_packages[@]}"

    #---------------------------------------------------------------------------
    print_step "5" "Installing Docker CE"
    #---------------------------------------------------------------------------
    
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
        compose_version=$(docker compose version 2>/dev/null | cut -d' ' -f4)
        print_ok "Docker CE already installed (v$docker_version)"
        [[ -n "$compose_version" ]] && print_ok "Docker Compose (v$compose_version)"
    else
        # Add Docker repository
        if [[ "$COUNTRY" == "CN" ]]; then
            # Use Aliyun mirror for China
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
            print_ok "Docker CE repository (Aliyun mirror)"
        else
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
            print_ok "Docker CE repository added"
        fi
        
        apt-get update -qq &>/dev/null
        
        # Install Docker CE and plugins
        if apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &>/dev/null; then
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
    print_step "6" "Installing Python 3.9+"
    #---------------------------------------------------------------------------
    
    # Check current Python 3 version
    current_python=""
    if command -v python3 >/dev/null 2>&1; then
        current_python=$(python3 --version 2>&1 | awk '{print $2}')
        python_major=$(echo "$current_python" | cut -d. -f1)
        python_minor=$(echo "$current_python" | cut -d. -f2)
        
        if [[ "$python_major" -ge 3 && "$python_minor" -ge 9 ]]; then
            print_ok "Python $current_python already installed"
        else
            print_info "Current Python $current_python is older than 3.9"
        fi
    fi
    
    # Install Python 3.11 or 3.10 depending on Ubuntu version
    local python_pkg="python3"
    if [[ "$os_version" -ge 22 ]]; then
        python_pkg="python3.11"
    elif [[ "$os_version" -ge 20 ]]; then
        python_pkg="python3.9"
    fi
    
    if ! command -v ${python_pkg} >/dev/null 2>&1; then
        print_info "Installing ${python_pkg}..."
        if apt-get install -yq ${python_pkg} ${python_pkg}-pip ${python_pkg}-venv ${python_pkg}-dev &>/dev/null; then
            print_ok "${python_pkg} installed"
            print_info "Use '${python_pkg}' or 'pip3' to access Python"
        else
            print_warn "Failed to install ${python_pkg}"
        fi
    else
        print_ok "${python_pkg} already installed"
    fi
    
    # Display available Python versions
    if command -v python3 >/dev/null 2>&1; then
        py_version=$(python3 --version 2>&1)
        print_ok "$py_version available"
    fi

    #---------------------------------------------------------------------------
    echo ""
    echo -e "${Green}${Bold}✓ Initialization completed successfully${Reset}"
    echo ""
}

# Placeholder functions for unimplemented features

function update_mirrors() {
    print_header "Update Repository Mirrors"
    apt_configure_mirror
    echo ""
    echo -e "${Green}${Bold}✓ Repository mirrors updated${Reset}"
    echo ""
}

function install_desktop() {
    print_header "Desktop Environment Installation"
    print_warn "Not yet implemented"
    echo ""
}

function install_devtools() {
    print_header "Development Tools Installation"
    print_warn "Not yet implemented"
    echo ""
}

# Install xrdp remote desktop
function install_xrdp() {
    print_header "xrdp Remote Desktop Installation"

    if dpkg -l xrdp 2>/dev/null | grep -q "^ii"; then
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
    local xrdp_packages=("xrdp" "xorgxrdp")
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
    if command -v ufw &>/dev/null; then
        ufw allow 3389/tcp &>/dev/null
        print_ok "Port 3389/tcp opened (ufw)"
    fi

    #---------------------------------------------------------------------------
    print_step "4" "Starting xrdp Service"
    #---------------------------------------------------------------------------
    systemctl enable xrdp &>/dev/null
    systemctl restart xrdp &>/dev/null
    print_ok "xrdp service enabled and started"

    #---------------------------------------------------------------------------
    print_step "5" "Configuring User Session"
    #---------------------------------------------------------------------------
    
    # Detect available desktop session
    local desktop_session=""
    if command -v mate-session &>/dev/null; then
        desktop_session="mate-session"
    elif command -v xfce4-session &>/dev/null; then
        desktop_session="startxfce4"
    elif command -v gnome-session &>/dev/null; then
        desktop_session="gnome-session"
    fi
    
    if [[ -n "$desktop_session" ]]; then
        echo "$desktop_session" > /etc/skel/.xsession
        chmod a+x /etc/skel/.xsession
        print_ok "Default session set to $desktop_session"

        # Update existing user homes
        for user_home in /home/*; do
            if [[ -d "$user_home" ]]; then
                local user=$(basename "$user_home")
                echo "$desktop_session" > "$user_home/.xsession"
                chown "$user:" "$user_home/.xsession"
                chmod a+x "$user_home/.xsession"
            fi
        done
        print_ok "Existing user homes updated"
    else
        print_warn "No desktop session found - install a desktop environment first"
    fi

    # Fix for authentication required popup on Ubuntu
    cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
    print_ok "Polkit authentication fix applied"

    echo ""
    echo -e "${Green}${Bold}✓ xrdp installation completed${Reset}"
    echo ""
}

# Install RealVNC Server
function install_realvnc() {
    print_header "RealVNC Server Installation"

    local vnc_deb_url="https://downloads.realvnc.com/download/file/vnc.files/VNC-Server-6.9.1-Linux-x64.deb"

    if dpkg -l realvnc-vnc-server 2>/dev/null | grep -q "^ii"; then
        print_ok "RealVNC Server already installed"
        return 0
    fi

    local allow_clipboard="N"
    local allow_fileshare="N"
    local license_key=""

    while true; do
        echo ""
        # Check if xrdp is installed
        if dpkg -l xrdp 2>/dev/null | grep -q "^ii"; then
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
    if dpkg -l xrdp 2>/dev/null | grep -q "^ii"; then
        apt-get remove -yq xrdp xorgxrdp &>/dev/null
        if command -v ufw &>/dev/null; then
            ufw delete allow 3389/tcp &>/dev/null
        fi
        print_ok "Removed xrdp and related packages"
    else
        print_ok "No conflicting packages found"
    fi

    #---------------------------------------------------------------------------
    print_step "2" "Downloading RealVNC Server"
    #---------------------------------------------------------------------------
    local work_dir=$(mktemp -d)
    local vnc_deb="$work_dir/realvnc-server.deb"
    
    if curl -# -L "$vnc_deb_url" -o "$vnc_deb"; then
        print_ok "Downloaded RealVNC Server"
    else
        print_error "Failed to download RealVNC Server"
        rm -rf "$work_dir"
        return 1
    fi

    #---------------------------------------------------------------------------
    print_step "3" "Installing RealVNC Server"
    #---------------------------------------------------------------------------
    # Install dependencies
    apt-get install -yq libxtst6 libxrandr2 libxfixes3 &>/dev/null
    
    if dpkg -i "$vnc_deb" &>/dev/null; then
        print_ok "RealVNC Server installed"
    else
        # Fix dependencies if needed
        apt-get install -f -yq &>/dev/null
        if dpkg -l realvnc-vnc-server 2>/dev/null | grep -q "^ii"; then
            print_ok "RealVNC Server installed (with dependency fix)"
        else
            print_error "Failed to install RealVNC Server"
            rm -rf "$work_dir"
            return 1
        fi
    fi

    #---------------------------------------------------------------------------
    print_step "4" "Configuring RealVNC"
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
auth include common-auth
account include common-account
session include common-session
EOF
    echo "PamApplicationName=vncserver.custom" >> /etc/vnc/config.d/common.custom
    print_ok "PAM authentication configured"

    #---------------------------------------------------------------------------
    print_step "5" "Adding License Key"
    #---------------------------------------------------------------------------
    if vnclicense -add "$license_key" &>/dev/null; then
        print_ok "License key added"
    else
        print_error "Failed to add license key"
    fi

    #---------------------------------------------------------------------------
    print_step "6" "Configuring Firewall"
    #---------------------------------------------------------------------------
    if command -v ufw &>/dev/null; then
        ufw allow 5900/tcp &>/dev/null
        print_ok "Port 5900/tcp opened (ufw)"
    fi

    #---------------------------------------------------------------------------
    print_step "7" "Starting VNC Service"
    #---------------------------------------------------------------------------
    systemctl enable vncserver-virtuald.service &>/dev/null
    systemctl start vncserver-virtuald.service &>/dev/null
    print_ok "VNC virtual desktop service started"

    #---------------------------------------------------------------------------
    print_step "8" "Configuring User Session"
    #---------------------------------------------------------------------------
    
    # Detect available desktop session
    local desktop_session=""
    if command -v mate-session &>/dev/null; then
        desktop_session="mate-session"
    elif command -v xfce4-session &>/dev/null; then
        desktop_session="startxfce4"
    elif command -v gnome-session &>/dev/null; then
        desktop_session="gnome-session"
    fi
    
    if [[ -n "$desktop_session" ]]; then
        echo "$desktop_session" > /etc/skel/.xsession
        chmod a+x /etc/skel/.xsession
        print_ok "Default session set to $desktop_session"

        # Update existing user homes
        for user_home in /home/*; do
            if [[ -d "$user_home" ]]; then
                local user=$(basename "$user_home")
                echo "$desktop_session" > "$user_home/.xsession"
                chown "$user:" "$user_home/.xsession"
                chmod a+x "$user_home/.xsession"
            fi
        done
        print_ok "Existing user homes updated"
    fi

    rm -rf "$work_dir"

    echo ""
    echo -e "${Green}${Bold}✓ RealVNC Server installation completed${Reset}"
    echo ""
}

# Remote Desktop menu
function install_remote_desktop() {
    print_header "Remote Desktop Installation"

    # Check for desktop environment (priority: mate -> xfce4 -> gnome)
    local desktop_name=""
    
    if command -v mate-session &>/dev/null; then
        desktop_name="MATE"
    elif command -v xfce4-session &>/dev/null; then
        desktop_name="Xfce"
    elif command -v gnome-session &>/dev/null; then
        desktop_name="GNOME"
    fi

    if [[ -n "$desktop_name" ]]; then
        print_ok "$desktop_name desktop detected"
    else
        print_warn "No desktop environment detected (checked: MATE, Xfce, GNOME)"
        print_info "Install a desktop environment first for full remote desktop support"
    fi

    while true; do
        echo ""
        local rd_options=("xrdp (RDP protocol)" "RealVNC Server" "Back to main menu")

        show_menu "Remote Desktop Options" "${rd_options[@]}"

        case $menu_index in
            0) install_xrdp;;
            1) install_realvnc;;
            2) return;;
        esac
    done
}

function update_network_settings() {
    print_header "Network Configuration"

    # Ensure NetworkManager or networkd is available
    if ! systemctl is-active --quiet NetworkManager && ! systemctl is-active --quiet systemd-networkd; then
        print_info "Starting network service..."
        systemctl start systemd-networkd &>/dev/null || systemctl start NetworkManager &>/dev/null
    fi

    while true; do
        local net_options=("List network interfaces" "Configure interface" "Rename interface" "Create bond interface" "Create VLAN interface" "Back to main menu")
        show_menu "Network Options" "${net_options[@]}"

        case $menu_index in
            0) list_network_interfaces;;
            1) configure_interface;;
            2) rename_interface;;
            3) create_bond_interface;;
            4) create_vlan_interface;;
            5) return;;
        esac
    done
}

# List all network interfaces with details
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

# Get array of network interfaces (excluding lo, docker, br-)
function get_interfaces_array() {
    ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | grep -v '^docker' | grep -v '^br-' | grep -v '^veth' | sed 's/@.*//'
}

# Calculate default gateway (last usable IP in subnet)
function calculate_default_gateway() {
    local ip="$1"
    local cidr="$2"
    
    # Convert IP to decimal
    IFS=. read -r i1 i2 i3 i4 <<< "$ip"
    local ip_dec=$((i1 * 256**3 + i2 * 256**2 + i3 * 256 + i4))
    
    # Calculate network mask using bit shifting
    local mask_dec=$(( (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF ))
    
    # Calculate broadcast address (last IP in subnet)
    local broadcast_dec=$(( (ip_dec & mask_dec) | (~mask_dec & 0xFFFFFFFF) ))
    
    # Gateway is broadcast - 1 (last usable IP)
    local gateway_dec=$((broadcast_dec - 1))
    
    # Convert back to dotted notation
    echo "$((gateway_dec >> 24 & 0xFF)).$((gateway_dec >> 16 & 0xFF)).$((gateway_dec >> 8 & 0xFF)).$((gateway_dec & 0xFF))"
}

# Prompt user for IP configuration (DHCP or Static)
function select_ip_config() {
    local iface="$1"
    local current_ip=""
    
    # Get current IP address if interface is provided
    if [[ -n "$iface" ]]; then
        current_ip=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
    fi
    
    local ip_options=("DHCP" "Static IP")
    show_menu "IPv4 Configuration" "${ip_options[@]}"
    
    bootproto="dhcp"
    ipaddr=""
    cidr=""
    gateway=""
    dns1=""
    dns2=""
    
    if [[ "$menu_index" == "1" ]]; then
        bootproto="static"
        
        while true; do
            local ip_prompt="  IP address (e.g., 192.168.1.100/24)"
            [[ -n "$current_ip" ]] && ip_prompt+=" [$current_ip]"
            ip_prompt+=": "
            read -p "$ip_prompt" ip_input
            
            [[ -z "$ip_input" && -n "$current_ip" ]] && ip_input="$current_ip"
            
            if [[ "$ip_input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]{1,2})$ ]]; then
                ipaddr="${ip_input%/*}"
                cidr="${ip_input#*/}"
                break
            else
                print_warn "Invalid IP address format (use x.x.x.x/prefix)"
            fi
        done
        
        # Calculate default gateway (last usable IP in subnet)
        local default_gateway=""
        if [[ -n "$cidr" ]] && [[ "$cidr" =~ ^[0-9]+$ ]]; then
            default_gateway=$(calculate_default_gateway "$ipaddr" "$cidr")
        fi
        
        local gateway_prompt="  Gateway"
        if [[ -n "$default_gateway" ]]; then
            gateway_prompt+=" [$default_gateway] (- for none): "
        else
            gateway_prompt+=" (blank for none): "
        fi
        read -p "$gateway_prompt" gateway
        
        # Handle explicit "no gateway" with "-"
        if [[ "$gateway" == "-" ]]; then
            gateway=""
        elif [[ -z "$gateway" && -n "$default_gateway" ]]; then
            gateway="$default_gateway"
        fi
        
        if [[ -n "$gateway" ]]; then
            local dns_prompt="  Primary DNS [$gateway] (- for none): "
            read -p "$dns_prompt" dns1
            
            if [[ "$dns1" == "-" ]]; then
                dns1=""
            elif [[ -z "$dns1" ]]; then
                dns1="$gateway"
            fi
            
            read -p "  Secondary DNS (blank for none): " dns2
        fi
    fi
}

# Generate Netplan configuration file
function generate_netplan_config() {
    local config_file="$1"
    local iface="$2"
    local config_type="$3"  # ethernet, bond, vlan
    
    cat > "$config_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
EOF
    
    echo "$config_file"
}

# Configure a single network interface using Netplan
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
    
    interfaces+=("Return to network menu")
    show_menu "Select interface" "${interfaces[@]}"
    
    # Check if user selected return option
    if [[ $menu_index -eq $((${#interfaces[@]} - 1)) ]]; then
        return
    fi
    
    local selected_iface="${interfaces[$menu_index]}"
    local current_mtu=$(cat /sys/class/net/$selected_iface/mtu 2>/dev/null || echo "1500")
    
    while true; do
        echo ""
        print_info "Configuring: $selected_iface"
        
        read -p "  MTU [$current_mtu]: " new_mtu
        [[ -z "$new_mtu" ]] && new_mtu="$current_mtu"
        
        if ! [[ "$new_mtu" =~ ^[0-9]+$ ]] || (( new_mtu < 576 || new_mtu > 9000 )); then
            print_warn "Invalid MTU (576-9000)"
            continue
        fi
        
        select_ip_config "$selected_iface"
        
        # Show summary
        local summary_items=(
            "Interface:     $selected_iface"
            "MTU:           $new_mtu"
            "Boot Protocol: $bootproto"
        )
        [[ "$bootproto" == "static" ]] && summary_items+=(
            "IP Address:    $ipaddr/$cidr"
        )
        [[ -n "$gateway" ]] && summary_items+=("Gateway:       $gateway")
        [[ -n "$dns1" ]] && summary_items+=("DNS1:          $dns1")
        [[ -n "$dns2" ]] && summary_items+=("DNS2:          $dns2")
        
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
    
    # Create Netplan configuration
    local netplan_file="/etc/netplan/50-${selected_iface}.yaml"
    
    if [[ "$bootproto" == "dhcp" ]]; then
        cat > "$netplan_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
  ethernets:
    $selected_iface:
      dhcp4: true
      dhcp6: false
      mtu: $new_mtu
EOF
    else
        local dns_section=""
        if [[ -n "$dns1" ]]; then
            dns_section="      nameservers:
        addresses:"
            dns_section+="
          - $dns1"
            [[ -n "$dns2" ]] && dns_section+="
          - $dns2"
        fi
        
        cat > "$netplan_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
  ethernets:
    $selected_iface:
      dhcp4: false
      dhcp6: false
      mtu: $new_mtu
      addresses:
        - $ipaddr/$cidr
EOF
        [[ -n "$gateway" ]] && echo "      routes:
        - to: default
          via: $gateway" >> "$netplan_file"
        [[ -n "$dns_section" ]] && echo "$dns_section" >> "$netplan_file"
    fi
    
    chmod 600 "$netplan_file"
    
    # Apply configuration
    if netplan apply &>/dev/null; then
        print_ok "Configuration applied: $netplan_file"
        print_ok "Interface $selected_iface configured"
    else
        print_error "Failed to apply netplan configuration"
        print_info "Check configuration with: netplan try"
    fi
}

# Rename network interface using udev rules
function rename_interface() {
    echo ""
    echo -e "${Bold}Rename Network Interface${Reset}"
    
    local all_interfaces=($(get_interfaces_array))
    local interfaces=()
    
    # Filter out bond slaves and virtual interfaces
    for iface in "${all_interfaces[@]}"; do
        [[ ! -d "/sys/class/net/$iface/master" ]] && [[ ! "$iface" =~ \. ]] && [[ ! "$iface" =~ ^bond ]] && interfaces+=("$iface")
    done
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_warn "No renameable interfaces found"
        return
    fi
    
    interfaces+=("Return to network menu")
    show_menu "Select interface to rename" "${interfaces[@]}"
    
    # Check if user selected return option
    if [[ $menu_index -eq $((${#interfaces[@]} - 1)) ]]; then
        return
    fi
    
    local selected_iface="${interfaces[$menu_index]}"
    local mac_addr=$(cat /sys/class/net/$selected_iface/address 2>/dev/null)
    
    echo ""
    print_info "Current interface: $selected_iface (MAC: $mac_addr)"
    
    while true; do
        read -p "  New interface name: " new_name
        
        if [[ -z "$new_name" ]]; then
            print_warn "Interface name cannot be empty"
            continue
        fi
        
        if [[ "$new_name" == "$selected_iface" ]]; then
            print_warn "New name is the same as current name"
            return
        fi
        
        if [[ ! "$new_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
            print_warn "Invalid interface name (must start with letter, contain only alphanumeric, _, -)"
            continue
        fi
        
        if ip link show "$new_name" &>/dev/null; then
            print_warn "Interface $new_name already exists"
            continue
        fi
        
        break
    done
    
    echo ""
    print_info "Renaming: $selected_iface → $new_name"
    read -p "  Proceed with rename? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    # Create udev rule for persistent naming
    local udev_rule="/etc/udev/rules.d/70-persistent-net-${new_name}.rules"
    cat > "$udev_rule" <<EOF
# Generated by ubuntu-setup.sh on $(date)
# Rename $selected_iface to $new_name based on MAC address
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$mac_addr", NAME="$new_name"
EOF
    
    chmod 644 "$udev_rule"
    print_ok "Udev rule created: $udev_rule"
    
    # Update Netplan configuration if it exists
    for netplan_file in /etc/netplan/*.yaml; do
        if grep -q "$selected_iface" "$netplan_file" 2>/dev/null; then
            sed -i "s/$selected_iface/$new_name/g" "$netplan_file"
            print_ok "Updated netplan config: $netplan_file"
        fi
    done
    
    print_warn "Reboot required to apply interface rename"
    echo ""
}

# Create a bonded network interface using Netplan
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
    printf "  ${Cyan}0)${Reset} Return to network menu\n"
    
    while true; do
        echo ""
        read -p "  Bond interface name (e.g., bond0, or 0 to return): " bond_name
        
        if [[ "$bond_name" == "0" ]]; then
            return
        elif [[ ! "$bond_name" =~ ^bond[0-9]+$ ]]; then
            print_warn "Bond name format: bondX (e.g., bond0, bond1)"
            continue
        fi
        
        # Check if bond already exists
        if [[ -f "/etc/netplan/50-${bond_name}.yaml" ]]; then
            print_warn "Bond $bond_name configuration already exists"
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
        case $menu_index in
            0) bond_mode="balance-rr";;
            1) bond_mode="active-backup";;
            2) bond_mode="balance-xor";;
            3) bond_mode="broadcast";;
            4) bond_mode="802.3ad";;
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
        [[ "$bootproto" == "static" ]] && summary_items+=(
            "IP Address:    $ipaddr/$cidr"
        )
        [[ -n "$gateway" ]] && summary_items+=("Gateway:       $gateway")
        [[ -n "$dns1" ]] && summary_items+=("DNS1:          $dns1")
        [[ -n "$dns2" ]] && summary_items+=("DNS2:          $dns2")
        
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
    
    # Build slaves list for YAML
    local slaves_yaml=""
    for slave in "${slaves[@]}"; do
        slaves_yaml+="
        - $slave"
    done
    
    # Create Netplan bond configuration
    local netplan_file="/etc/netplan/50-${bond_name}.yaml"
    
    if [[ "$bootproto" == "dhcp" ]]; then
        cat > "$netplan_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
  bonds:
    $bond_name:
      interfaces:$slaves_yaml
      mtu: $bond_mtu
      dhcp4: true
      dhcp6: false
      parameters:
        mode: $bond_mode
        mii-monitor-interval: 100
EOF
    else
        local dns_section=""
        if [[ -n "$dns1" ]]; then
            dns_section="      nameservers:
        addresses:
          - $dns1"
            [[ -n "$dns2" ]] && dns_section+="
          - $dns2"
        fi
        
        cat > "$netplan_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
  bonds:
    $bond_name:
      interfaces:$slaves_yaml
      mtu: $bond_mtu
      dhcp4: false
      dhcp6: false
      addresses:
        - $ipaddr/$cidr
EOF
        [[ -n "$gateway" ]] && echo "      routes:
        - to: default
          via: $gateway" >> "$netplan_file"
        [[ -n "$dns_section" ]] && echo "$dns_section" >> "$netplan_file"
        
        echo "      parameters:
        mode: $bond_mode
        mii-monitor-interval: 100" >> "$netplan_file"
    fi
    
    chmod 600 "$netplan_file"
    
    # Apply configuration
    if netplan apply &>/dev/null; then
        print_ok "Bond $bond_name created: $netplan_file"
        print_ok "Slaves: ${slaves[*]}"
    else
        print_error "Failed to apply netplan configuration"
        print_info "Check configuration with: netplan try"
    fi
    echo ""
}

# Create a VLAN interface using Netplan
function create_vlan_interface() {
    echo ""
    echo -e "${Bold}Create VLAN Interface${Reset}"
    
    local all_interfaces=($(get_interfaces_array))
    local available_interfaces=()
    
    # Get all non-VLAN interfaces (physical, bond, etc.)
    for iface in "${all_interfaces[@]}"; do
        [[ ! "$iface" =~ \. ]] && available_interfaces+=("$iface")
    done
    
    if [[ ${#available_interfaces[@]} -eq 0 ]]; then
        print_warn "No interfaces found for VLAN tagging"
        return
    fi
    
    echo ""
    echo -e "${Dim}Available interfaces for VLAN tagging:${Reset}"
    for i in "${!available_interfaces[@]}"; do
        local iface="${available_interfaces[$i]}"
        local mac=$(cat /sys/class/net/$iface/address 2>/dev/null || echo "N/A")
        local state=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "N/A")
        printf "  ${Cyan}%d)${Reset} %-10s MAC: %-18s State: %s\n" "$((i+1))" "$iface" "$mac" "$state"
    done
    printf "  ${Cyan}0)${Reset} Return to network menu\n"
    
    while true; do
        echo ""
        read -p "  Select parent interface number [1-${#available_interfaces[@]}, or 0 to return]: " iface_num
        
        if [[ "$iface_num" == "0" ]]; then
            return
        fi
        
        if ! [[ "$iface_num" =~ ^[0-9]+$ ]] || (( iface_num < 1 || iface_num > ${#available_interfaces[@]} )); then
            print_warn "Invalid selection"
            continue
        fi
        
        local parent_iface="${available_interfaces[$((iface_num-1))]}"
        
        read -p "  VLAN ID (1-4094): " vlan_id
        
        if ! [[ "$vlan_id" =~ ^[0-9]+$ ]] || (( vlan_id < 1 || vlan_id > 4094 )); then
            print_warn "Invalid VLAN ID (must be 1-4094)"
            continue
        fi
        
        local vlan_name="vlan${vlan_id}"
        
        if [[ -f "/etc/netplan/50-${vlan_name}.yaml" ]]; then
            print_warn "VLAN interface $vlan_name already exists"
            continue
        fi
        
        read -p "  MTU [1500]: " vlan_mtu
        [[ -z "$vlan_mtu" ]] && vlan_mtu="1500"
        
        if ! [[ "$vlan_mtu" =~ ^[0-9]+$ ]] || (( vlan_mtu < 576 || vlan_mtu > 9000 )); then
            print_warn "Invalid MTU (576-9000)"
            continue
        fi
        
        select_ip_config
        
        # Show summary
        local summary_items=(
            "VLAN Interface: $vlan_name"
            "Parent Interface: $parent_iface"
            "VLAN ID:        $vlan_id"
            "MTU:            $vlan_mtu"
            "Boot Protocol:  $bootproto"
        )
        [[ "$bootproto" == "static" ]] && summary_items+=(
            "IP Address:     $ipaddr/$cidr"
        )
        [[ -n "$gateway" ]] && summary_items+=("Gateway:        $gateway")
        [[ -n "$dns1" ]] && summary_items+=("DNS1:           $dns1")
        [[ -n "$dns2" ]] && summary_items+=("DNS2:           $dns2")
        
        print_summary "VLAN Configuration" "${summary_items[@]}"
        
        echo ""
        read -p "  Create this VLAN? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            break
        else
            read -p "  Return to network menu? [y/N]: " return_menu
            [[ "$return_menu" =~ ^[Yy]$ ]] && return
        fi
    done
    
    # Create Netplan VLAN configuration
    local netplan_file="/etc/netplan/50-${vlan_name}.yaml"
    
    if [[ "$bootproto" == "dhcp" ]]; then
        cat > "$netplan_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
  vlans:
    $vlan_name:
      id: $vlan_id
      link: $parent_iface
      mtu: $vlan_mtu
      dhcp4: true
      dhcp6: false
EOF
    else
        local dns_section=""
        if [[ -n "$dns1" ]]; then
            dns_section="      nameservers:
        addresses:
          - $dns1"
            [[ -n "$dns2" ]] && dns_section+="
          - $dns2"
        fi
        
        cat > "$netplan_file" <<EOF
# Generated by ubuntu-setup.sh on $(date)
network:
  version: 2
  renderer: networkd
  vlans:
    $vlan_name:
      id: $vlan_id
      link: $parent_iface
      mtu: $vlan_mtu
      dhcp4: false
      dhcp6: false
      addresses:
        - $ipaddr/$cidr
EOF
        [[ -n "$gateway" ]] && echo "      routes:
        - to: default
          via: $gateway" >> "$netplan_file"
        [[ -n "$dns_section" ]] && echo "$dns_section" >> "$netplan_file"
    fi
    
    chmod 600 "$netplan_file"
    
    # Apply configuration
    if netplan apply &>/dev/null; then
        print_ok "VLAN $vlan_name created: $netplan_file"
        print_ok "Parent interface: $parent_iface, VLAN ID: $vlan_id"
    else
        print_error "Failed to apply netplan configuration"
        print_info "Check configuration with: netplan try"
    fi
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

    # Check required packages
    local domain_packages=("realmd" "sssd" "sssd-tools" "adcli" "krb5-user" "samba-common-bin" "packagekit")
    for pkg in "${domain_packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            print_info "Installing required package: $pkg"
            apt-get install -yq "$pkg" &>/dev/null
        fi
    done

    # Check if already joined
    current_domain=$(realm list 2>/dev/null | grep "domain-name" | awk '{print $2}')
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
    hostnamectl set-hostname "$fqdn_hostname"
    print_ok "Hostname set to $fqdn_hostname"

    if [[ "$domain_type" == "FreeIPA" ]]; then
        # Install FreeIPA client if not present
        if ! command -v ipa-client-install &>/dev/null; then
            apt-get install -yq freeipa-client &>/dev/null
        fi
        
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
            ["default_shell"]="/bin/bash"
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
        print_step "3" "Configuring PAM for Home Directory Creation"
        #-----------------------------------------------------------------------
        # Enable automatic home directory creation on Ubuntu
        if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
            echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session
            print_ok "PAM mkhomedir configured"
        else
            print_ok "PAM mkhomedir already configured"
        fi

        #-----------------------------------------------------------------------
        print_step "4" "Configuring Access Permissions"
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
            chmod 440 "$SUDOERS_FILE"
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

# Main program
function main() {
    # Professional banner
    echo ""
    echo -e "${Cyan}╔═══════════════════════════════════════════════════════════╗${Reset}"
    echo -e "${Cyan}║${Reset}  ${Bold}Ubuntu Linux Setup Utility${Reset}                               ${Cyan}║${Reset}"
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
    
    if [[ "$os_name" != "ubuntu" ]]; then
        print_error "This script is for Ubuntu Linux only. Detected: $os_name $os_version"
        exit 1
    fi
    
    if [[ "$os_version" -lt 18 ]]; then
        print_error "Ubuntu 18.04 or newer required. Detected: $os_version"
        exit 1
    fi
    
    print_ok "Ubuntu $os_version detected"

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
            1) update_mirrors;;
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
