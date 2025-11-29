#!/bin/bash
# Linux server configuration utility v1
# Now support interactive 
# (c) 2021 Creekside Networks LLC, Jackson Tong
# Usage: ssh -t ip "$(<./linux-setup.sh)"

SCRIPT_VERSION="0.4"
DEFAULT_DOMAIN="creekside.network"
NMS_SERVER=nms.$DEFAULT_DOMAIN
FTP_SERVER=ftp.$DEFAULT_DOMAIN
MASQUERADE_ENABLED="Y"
TCP_MSS=1300


#SFTP_URL="sftp://${SFTP_SVR}:58222"
# For China use only
SFTP_URL_CN="sftp://wuh-cu.innosilicon.org:58222/resource"

# For international use only
SFTP_URL_GLOBAL="sftp://ftp.creekside.network:58222"

SFTP_URL=${SFTP_URL_GLOBAL}

default_packages=("yum-utils" "rsync" "util-linux" "curl" "firewalld" "bind-utils" "telnet" "jq" "nano" \
"ed" "tcpdump" "wget" "nfs-utils" "cifs-utils" "samba-client" "tree" "xterm" "net-tools" \
"openldap-clients" "sssd" "realmd" "oddjob" "oddjob-mkhomedir" "adcli" \
"samba-common" "samba-common-tools" "krb5-workstation" "openldap-clients" "iperf3" "rsnapshot" "zip" \
"unzip" "ftp" "autofs" "zsh" "ksh" "tcsh" "ansible" "cabextract"  "fontconfig" \
"nedit" "htop" "tar" "traceroute" "mtr" "pwgen" "ipa-admintools"  "cyrus-sasl" "cyrus-sasl-plain" "cyrus-sasl-ldap" "svn")

CREEKSIDE_CFG_DIR="/etc/creekside"
LOCAL_CFG_FILE=$CREEKSIDE_CFG_DIR/conf/localhost.cfg

WIREGUARD_WG0_CONF=/etc/wireguard/wg0.conf

# system
SYSTEM_CFG_IDR=$CREEKSIDE_CFG_DIR/system
SUDOER_CFG=$SYSTEM_CFG_IDR/sudoer.cfg
REBOOT_RQUIRED="N"

# default values
IPA_ENABLED=""                      # freeIPA client installed 'Y' or not 'N'
IPA_DNSNAME=""
IPA_SERVER_IP=""
IPA_ADMIN=""

STATIC_USER_NAME="guest"
STATIC_USER_PASS="1234"
STATIC_USER_GROUP="Guest"


# ****************************************************************************
# Test an IP address for validity:
# Usage:
#      Valid_IP IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if Valid_IP IP_ADDRESS; then echo good; else echo bad; fi
# ****************************************************************************
function Valid_IP()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


# ****************************************************************************
# Test a FQDN for validity:
# Usage:
#      Valid_Hostname FQDN or hostname
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if Valid_Hostname hostname; then echo good; else echo bad; fi
# ****************************************************************************
function Valid_Hostname() {

    local hostname=$11
    # check host name only
    if [[ $hostname =~  ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61} ]]; then
        return 0
    elif [[ $hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then 
        return 0
    else
        return 1
    fi
}

# ****************************************************************************
# Test a domain for validity:
# Usage:
#      Valid_Domain domain
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if Valid_Domain domain; then echo good; else echo bad; fi
# ****************************************************************************
function Valid_Domain() {

    local domain_name=$1
    # check host name only
    if [[ $domain_name =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then 
        return 0
    else
        return 1
    fi
}


# ****************************************************************************
# Prompt user with a default value, return "Y" or "N"
# Usage:
#      Ask_Confirm "PROMPT" "DEFAULT"
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
# ****************************************************************************
function Ask_Confirm() {
    local prompt=$1
    local default=$2
    local choice
    local input

    while [[ true ]]; do
        case $default in
            "Y")
                printf "\n%49s %10s : " "$prompt" "[Y/n]"
                ;;
            "N")
                printf "\n%49s %10s : " "$prompt" "[y/N]"
                ;;
            *)
                printf "\n%49s %10s : " "$prompt" "[Yes/No]"
                ;;
        esac

        read input
        if [[ $default != "" ]]; then
            input=${input:-$default}
        fi

        input=${input^^}

        case $input in
            "Y" | "YES")
                return 0
                ;;
            "N" | "NO")
                return 1
                ;;
            *)
                printf "\n%60s\n" "*** Answer must be yes or no!"
                ;;
        esac
    done

    return 1
}


# ****************************************************************************
# Prompt user with a default value, return "Y" or "N"
# Usage:
#      Inquiry "PROMPT" "DEFAULT"
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
# ****************************************************************************
function Inquiry() {
    local prompt=$1
    local default=$2
    local choice
    local input

    if [[ $default == "Y" ]]; then
        choice="[Y/n]"
    else
        choice="[y/N]"
    fi

    printf "%-53s %6s : " "$prompt" "$choice"
    read input
    input=${input:-$default}
    input=${input^^}

    if [[ $input == "Y" ]] || [[ $input == "YES" ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt user and get a choice of a menu
function Read_Choice() {
    local input
    local default=$2
    local low=$3
    local high=$4

    while [[ true ]]; do
        printf "\n%55s %4s : " "$1" "[$2]"    
        read input
        input=${input:-$default}

        if [[ $input -lt $low ]] || [[ $input -gt $high ]]; then
             printf "\n  *** '$input' is out of valid range [$low - $high] ***\n"
             continue;
        else
            READ_VALUE=$input
            return 0
        fi
    done
}

# Prompt user and get a valid ip pool
function Read_IP_Pool24() {
    local input
    local default=$2
    default=${default#*[}
    default=${default%]*}

    while [[ true ]]; do
        printf "%-42s %17s : " "$1" "[$2]/24"    
        read input

        input=${input:-$default}
   
        if Valid_IP $input; then
            READ_VALUE=$input
            return 0
        else
            printf "\n  *** A valid IPv4 address is required ***\n"
            continue
        fi
    done
}

# ****************************************************************************
# Prompt user and get a valid ip address
# Usage:
#      Read_IP "PROMPT" "DEFAULT" "ALLOWEMPTY"
# Return:
#      $READ_VALUE
# ****************************************************************************
function Read_IP24() {
    local input
    local default=$2
    local ip_prefix=${default%.*}
    local ip_last=${default##*.}

    while [[ true ]]; do
        printf "%-42s %17s : " "$1" "$ip_prefix.[$ip_last]"    
        read input

        input=${input:-$ip_last}
   
        if [[ $input -le "1" ]] && [[ $input -gt "254" ]]; then
            printf "\n  *** Only 1 - 254 is allowed ***\n"
            continue
        else
            READ_VALUE="$ip_prefix.$input"
            return
        fi
    done
}
# ****************************************************************************
# Prompt user and get a valid ip address
# Usage:
#      Read_IP "PROMPT" "DEFAULT" "ALLOWEMPTY"
# Return:
#      $READ_VALUE
# ****************************************************************************
function Read_IP() {
    local input
    local default=$2
    local allow_empty=$3

    default=${default#*[}
    default=${default%]*}

    while [[ true ]]; do
        printf "%-42s %17s : " "$1" "[$2]"    
        read input

        if [[ $default != "" ]]; then
            input=${input:-$default}
        fi

        if [[ $allow_empty == "Y" ]] && [[ $input == "" ]]; then
            READ_VALUE=""
            return 1
        elif [[ $allow_empty == "Y" ]] && [[ $input == "-" ]]; then
            READ_VALUE=""
            return 1
        elif Valid_IP $input; then
            READ_VALUE=$input
            return 0
        else
            printf "\n  *** A valid IPv4 address is required ***\n"
            continue
        fi
    done
}

# ****************************************************************************
# Prompt user and get a valid alphanum
# Usage:
#      Read_Alphanum "PROMPT" "DEFAULT"
# Return:
#      $READ_VALUE
# ****************************************************************************
function Read_Alphanum() {
    local input
    
    local default=$2
    default=${default#*[}
    default=${default%]*}

    while [[ true ]]; do
        printf "%-39s %20s : " "$1" "$2"    
        read input

        input=${input:-$default}

        if [[ $input =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,19} ]]; then
            READ_VALUE=$input
            return 0
        else
            printf "\n  *** A alphanum value is required [$input] ***\n"
            continue
        fi
    done
}


# Prompt user and get a number in range
function Read_Number() {
    local input
    local default=$2
    local low=$3
    local high=$4

    while [[ true ]]; do
        printf "%-49s %10s : " "$1" "[$2]"    
        read input
        input=${input:-$default}

        if [[ $input -lt $low ]] || [[ $input -gt $high ]]; then
             printf "\n  *** '$input' is out of valid range [$low - $high] ***\n"
             continue;
        else
            READ_VALUE=$input
            return 0
        fi
    done
}


function DeleteLines() {
    local TARGET_KEY=$1
    local CONF_FILE=$2

    if [[ -f $CONF_FILE ]]; then
        sudo sed -i "/$TARGET_KEY.*/d" $CONF_FILE
    else
        printf "\n  ***** $CONF_FILE not found! ***** "
        return 1
    fi

}

# ****************************************************************************
# Change current value if exists, or 
# Append it
# Usage:
#      Update_Conf <TARGET_KEY> <REPLACEMENT_VALUE> <conf file>
# ****************************************************************************
function Update_Conf() {
    local TARGET_KEY=$1
    local REPLACEMENT_VALUE=$2
    local CONF_FILE=$3

    if [[ $TARGET_KEY == "" ]]; then
        return 1
    fi

    # create configuration file if not exist yet
    if [[ ! -f $CONF_FILE ]]; then
        printf   "       > create [$CONF_FILE]\n"
        sudo touch $CONF_FILE
    fi

    # search for the key
    if grep -q $TARGET_KEY $CONF_FILE; then
        # find existing key
        printf   "       > [$CONF_FILE]: Replace  \"$TARGET_KEY = $REPLACEMENT_VALUE\"\n"
        sed -i "s#^\($TARGET_KEY\s*=\s*\).*\$#\1$REPLACEMENT_VALUE#" $CONF_FILE
    else
        printf   "       > [$CONF_FILE]: Add  \"$TARGET_KEY = $REPLACEMENT_VALUE\"\n"
        echo "$TARGET_KEY = $REPLACEMENT_VALUE"| sudo tee -a $CONF_FILE  &> /dev/null
    fi
}

function Update_Hosts_File() {
    local MY_IP=$1
    local NEWHOSTNAME=$2
    local DOMAIN=$3

  
    DeleteLines $MY_IP /etc/hosts
    DeleteLines $NEWHOSTNAME /etc/hosts

    if [[ $DOMAIN == "" ]]; then
        echo "    - Update /etc/hosts with \"$MY_IP $NEWHOSTNAME\""
        echo "$MY_IP $NEWHOSTNAME" | sudo tee -a /etc/hosts &> /dev/null
    else
        echo "    - Update /etc/hosts with \"$MY_IP $NEWHOSTNAME.$DOMAIN $NEWHOSTNAME\""
        echo "$MY_IP $NEWHOSTNAME.$DOMAIN $NEWHOSTNAME" | sudo tee -a /etc/hosts &> /dev/null
    fi
}

# ****************************************************************************
# Install a CentOS package
# Usage:
#      Install_Package_Centos <package> [optional source]
# ****************************************************************************
function Install_Single_CentOS_Package() {
    package_name=$1
    package_source=$2

    printf "%-60s : " "   - Install \"$package_name\""
    if ! rpm -q --quiet $package_name; then
        if [ $# -eq 1 ]; then
            # install from repository
            sudo yum install -y -q $1
        else
            # install from remote source
            sudo yum -y -q localinstall $package_source
        fi
        if [ $? -eq 0 ]; then 
            printf "Just installed\n"
        else # Any other exit
            if Inquiry "   *** [$1] instllation failed, continue?" "Y"; then
                return 1
            else
                printf "\n   *** exit now \n\n"
	            exit 0
            fi
        fi
        return 0
    else
        printf "Already installed\n"
        return 1
    fi

}



# ****************************************************************************
# Get OS type
# Usage:
#      os_type=$(Get_OS_Type) 
# ****************************************************************************
function Get_OS_Type() {
    local host_os
    host_os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)-$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release)
    host_os=${host_os//\"}

    echo $host_os
}


# ****************************************************************************
# Disable sudoer's password request
# Usage:
#      Disable_Sudo_Passwd 
# ****************************************************************************
function Disable_Sudo_Passwd() {
    local nopasswd
    local magic_word

    magic_word="%$1	ALL=(ALL:ALL) NOPASSWD:ALL      #Added by Creekside Neworks LLC"
    nopasswd=$(sudo cat /etc/sudoers | grep "$magic_word")
    if [[ $nopasswd == "" ]]; then
        echo "$magic_word" | sudo tee -a /etc/sudoers &> /dev/null
    fi

    return 0
}

function Initial_Ubuntu() {
    return 0
}

# ****************************************************************************
# Formats
# ****************************************************************************
Black=`tput setaf 0`	#${Black}
Red=`tput setaf 1`	#${Red}
Green=`tput setaf 2`	#${Green}
Yellow=`tput setaf 3`	#${Yellow}
Blue=`tput setaf 4`	#${Blue}
Magenta=`tput setaf 5`	#${Magenta}
Cyan=`tput setaf 6`	#${Cyan}
White=`tput setaf 7`	#${White}
Bold=`tput bold`	#${Bold}
UndrLn=`tput sgr 0 1`	#${UndrLn}
Rev=`tput smso`		#${Rev}
Reset=`tput sgr0`	#${Reset}

# ****************************************************************************
# Execute a bash command & exit if failed 
# Used to show a process is making progress/running
# ****************************************************************************
RunCmd() {
    $1
    if [ $? -eq 0 ]; then 
        echo $2
        return 0
    else
        echo -e "\n  *** Command failed *** \n\n"
        exit 0
    fi
}


# ****************************************************************************
# Prompt user and get a valid domain
# ****************************************************************************
function Read_Domain() {
    local input
    local prompt=$1
    local default=$2


    while [[ true ]]; do
        printf "%-20s %39s : " "$prompt" "[$default]"    
        read input

        input=${input:-$default}
        
        if [[ $input =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z.]{2,}$ ]]; then 
            READ_VALUE=$input
            return 0
        else
            printf "\n  *** A valid domain is required [$input] ***\n"
            continue
        fi
    done
}

# Prompt user and get a valid hostname
function Read_Hostname() {
    local input
    local prompt=$1
    local default=$2
    local allow_empty=$3


    while [[ true ]]; do
        printf "%-29s %30s : " "$prompt" "[$default]"    
        read input

        input=${input:-$default}

        if [[ $input =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,31}[a-zA-Z0-9]$ ]]; then 
            READ_VALUE=$input
            return 0
        elif [[ $input =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,31}[a-zA-Z0-9]\.[a-zA-Z0-9.]{2,}$ ]]; then 
            READ_VALUE=$input
            return 0
        elif [[ $input == "-" && $allow_empty == "Y" ]]; then
            READ_VALUE=""
            return 0
        elif [[ $input == "" && $allow_empty == "Y" ]]; then
            READ_VALUE=""
            return 0
        else
            printf "\n  *** A valid hostname is required [$input] ***\n"
            continue
        fi
    done
}

# Prompt user and get a string with limited size 
function Read_String() {
    local input
    local default=$2
    local low=$3
    local high=$4
    local default_shown

    if [[ ${#default} -gt 18 ]]; then
        default_shown="${default:0:15}..."
    else
        default_shown=$default
    fi

    while [[ true ]]; do
        printf "%-39s %20s : " "$1" "[$default_shown]"    
        read input
        input=${input:-$default}

        input_len=${#input}
        if [[ $input_len -lt $low ]] || [[ $input_len -gt $high ]]; then
             printf "\n  *** Length out of range [$low - $high] ***\n"
             continue;
        else
            READ_VALUE=$input
            return 0
        fi
    done
}



function Check_Usergroup() {
    members=$(getent group $1)

    if [[ $members == "" ]]; then
        return 1
    else
        return 0
    fi
}

function SimpleMenu() {
    MENU_ITEMS=("$@")

    index="0"
    for item in "${MENU_ITEMS[@]}";
        do
        printf   "    $index. $item\n"
        index=$((index+1))
        done

    while true; do
        printf   "%55s %4s : " ">>> Your choice" "[0]" 
        read MENU_CHOICE
        MENU_CHOICE=${MENU_CHOICE:-"0"}

        if [[ $MENU_CHOICE -lt "0" ]] || [[ $MENU_CHOICE -ge $index ]]; then
            printf   "\n **** Invalid choice ****\n\n"
            continue
        else
            return 0      
        fi
    done
}

function SearchArray() {
    local value=$1
    local name=$2[@]
    local array=("${!name}")

    for item in ${array[@]}; do
        if [[ "$item" == "$value" ]]
        then
            return 0
        fi
    done

    return 1
}


# function:    Ftp_Download_File
function Ftp_Download_File() {
    local SRC_PATH=$1
    local DEST_FILE=$2

    sudo curl -fsSL -u anonymous $SRC_PATH -o $DEST_FILE

    if [[ ! -f $DEST_FILE ]]; then
        printf "\n *** Download failed, exit now\n\n"
        exit 
    fi
}

function ftp_list_directory() {
    local path=$1

    path=${path#/}              # remove leading '/'
    path=${path%/}              # remove tailing '/'

    curl --silent --list --user downloader:Kkg94290 --insecure ${SFTP_URL}/${path}/
}

function ftp_get() {
    local path=$1
    local dest=$2

    path=${path#/}              # remove leading '/'
    path=${path%/}              # remove tailing '/'

    curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/${path} -o ${dest}
}

function Install_CentOS_Packages() {
    packages=("$@")
    for pacakge in ${packages[@]}; do
        Install_Single_CentOS_Package $pacakge
    done
}


# ****************************************************************************
# Install development tools
# Usage:
#      Install_OfficeApps 
# ****************************************************************************
DevTools11Packages=("bzip2-devel" "libffi-devel" "centos-release-scl" "devtoolset-11")


EDA_Packages=("ksh" "gtkwave" "p7zip" "ntfs-3g" "vsftpd" "links" "mariadb-server" "mariadb" \
"libXScrnSaver" "php" "webkitgtk3-devel" "gdk-pixbuf2" "gdk-pixbuf2.i686" \
"glibc.i686" "libstdc++.so.5" "libusb.i686"   "motif.i686 " "libXpm.i686" \
"java" "java-1.8.0-openjdk-devel" "cglib.noarch" "fence-agents" "filezilla" "foomatic" "ftp" "gc" \
"geronimo-jms" "geronimo-annotation.noarch" "gfs2-utils.x86_64" "glib2.i686" "glib2" "glibmm24-devel.x86_64" \
"gnome-abrt.x86_64" "gperf.x86_64" "graphite2.i686" "gtk2.i686" "harfbuzz.i686" "ipmitool.x86_64" "jasper-libs.i686" \
"jboss-ejb-3.1-api" "jboss-servlet-3.0-api-javadoc" "jboss-transaction-1.1-api-javadoc.noarch" \
"jbigkit-libs.i686" "jsoup" "jzlib" "krb5-libs.i686" "libICE.i686" "libXau.i686" "libXext.i686" "libXft.i686" \
"libmount.i686" "libmount-devel" "libqb" "libsepol.i686" "libsigc++20" "libsigc++20-devel" "libvpx" "libvpx.i686" \
"libwayland-server" "libwayland-server.i686" "libwayland-client.i686" "libusb.i686 motif.i686" "libwayland-client.i686" \
"libvpx.i686" "libsigc++20-devel")

function Install_Vscode() {
    if rpm -q --quiet code; then
        printf "\n o Vsode already installed\n"
        return 1
    fi

    printf "\n o Install  Visual studio code\n" 

    if [[ $OS_VERSION == "7" ]]; then
        printf "   - Download VSCode 1.85 from ftp server\n"
        WORK_DIR=$(mktemp -d)
        curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/centos7/vscode/code-1.85.2-1705561377.el7.x86_64.rpm -o ${WORK_DIR}/vscode1.85.rpm
        yum localinstall ${WORK_DIR}/vscode1.85.rpm -y
        sudo rm -rf $WORK_DIR
    else
        if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
        printf "\n   - Update yum repositories \n"
            echo "
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=0
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
" | sudo tee /etc/yum.repos.d/vscode.repo &> /dev/null
        fi

        printf "\n   - Install vscode \n"
        Install_Single_CentOS_Package "code"
    fi
}

function Install_GCC11() {
    printf "\n o Install scl devetoolset 11 \n"
    Install_CentOS_Packages "${DevTools11Packages[@]}"

    printf  "\n    *************************************************************\n"
    printf    "      - Run \"scl enable devtoolset-11 bash\" to enable dev11 env\n"
    printf    "    *************************************************************\n"
}

function Install_OpenSSL() {
    printf "\n o Install openssl 1.1.1 ***\n"
    version=$(openssl version &> /dev/null)
    if [ $? -eq 0 ]; then
        version=$(echo $version | grep "OpenSSL.*" | awk '{print $2}')
        if [[ $version != "1.1"* ]]; then
            printf  "    - Remove old version $version\n"
            sudo yum -y remove openssl openssl-devel
        fi
    fi
    
    if [[ $version != "1.1"* ]]; then
        WORK_DIR=$(mktemp -d)
        cd ${WORK_DIR}
        printf  "    - Download source\n"
        curl -# https://www.openssl.org/source/openssl-1.1.1t.tar.gz -o ${WORK_DIR}/opensslsrc.tgz

        printf  "    - Extract archive files\n"
        tar -xf ${WORK_DIR}/opensslsrc.tgz --strip-components=1 

        printf  "    - Build openssl 1.1.1\n"
        ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl
        make -j $(nproc)
        sudo make install
        sudo ldconfig
        sudo tee /etc/profile.d/openssl.sh<<EOF
export PATH=/usr/local/openssl/bin:\$PATH
export LD_LIBRARY_PATH=/usr/local/openssl/lib:\$LD_LIBRARY_PATH
EOF

        printf  "    - Cleanup work enviroment\n"
        cd ~
        sudo rm -rf ${WORK_DIR}
    else
        printf  "    - OpenSSL $version already installed\n"
    fi
}

function Install_Git2() {
    printf "\n o Install git 2\n"
    version=$(rpm -q git | awk -F- '{ print $2 }' )
    if [[ $version != "2."* ]]; then
        sudo rpm --import endpoint-rpmsign-7.pub
        sudo yum install -y https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
        sudo yum clean all
        sudo yum install -y git 
    else
        printf  "    - Git $version already installed\n"
    fi    
}

function Install_Python3() {
        printf "\n o Install Python 3.11.4 \n"

        version=$(python3 --version  | awk '{ print $2 }')
        if [[ $version != "3.11"* ]]; then
            WORK_DIR=$(mktemp -d)
            cd ${WORK_DIR}
            printf  "    - Download source\n"
            curl -# https://www.python.org/ftp/python/3.11.4/Python-3.11.4.tgz -o ${WORK_DIR}/python3src.tgz

            printf  "    - Extract archive files\n"
            tar -xf ${WORK_DIR}/python3src.tgz --strip-components=1 

            printf  "    - Build Python3.11\n"
            LDFLAGS="${LDFLAGS} -Wl,-rpath=/usr/local/openssl/lib" ./configure --with-openssl=/usr/local/openssl
            #./configure --prefix=/opt/python311 --with-system-ffi --with-computed-gotos --enable-loadable-sqlite-extensions  --enable-optimizations
            sudo make altinstall

            printf  "    - Make Python3.11 as default\n"
            update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.11 1
            update-alternatives --install /usr/bin/python3-config python3-config /usr/local/bin/python3.11-config 1
            update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.11 1

            sudo yum install python3-devel python3-pip -y
            sudo python3 -m pip install --upgrade pip

            sudo python3 -m pip install cocotb
            sudo python3 -m pip install scapy
            sudo python3 -m pip install matplotlib==1.5.3

            printf  "    - Cleanup work enviroment\n"
            cd ~

            printf "\n o Install jboss \n"
            cd ${WORK_DIR}
            wget http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.zip
            sudo unzip jboss-as-7.1.1.Final.zip -d /opt/
            cd /opt/
            sudo ln -s jboss-as-7.1.1.Final/ jboss
            sudo adduser jboss
            sudo chown -R jboss. /opt/jboss-as-7.1.1.Final/ /opt/jboss

            sudo rm -rf ${WORK_DIR}
        else
            printf  "    - Python $version already installed\n"
        fi         
}

function Install_EDA_Libraries() {
    printf "\n o Install EDA Libraries \n"
    Install_CentOS_Packages "${EDA_Packages[@]}"
}

function Install_Docker () {
    printf "\n o Install Docker Engine CE \n"
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo curl -s https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
    sudo yum update -y
    sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    sudo systemctl start docker && sudo systemctl enable docker
}

function Install_DevTools() {
    local i
    local input

    printf "\n *** Install development tools ***\n"
    if ! rpm -q --quiet gcc; then
        printf "\n o Install prerequisted standard develeopment tools\n"
        sudo yum groupinstall "Development tools" -y
    fi    

    while [[ true ]]; do
        CONFIG_CHANGED=false

        # main menu
        printf "\n o Installation menu ***\n"
        printf   "   1. Visual studio code\n"
        printf   "   2. GCC 11\n"
        printf   "   3. Python 3.11\n"
        printf   "   4. OpenSSL 1.1.1\n"
        printf   "   5. Git 2\n"
        printf   "   6. EDA libraries\n"
        printf   "   7. Docker\n"
        printf   "   9. All above\n"
        printf   "   0. Exit\n\n"

        DEFAULT_ACTION="0"

        printf   "%55s %4s : " ">>> Your choice" "[$DEFAULT_ACTION]" 
        read INPUT
        INPUT=${INPUT:-$DEFAULT_ACTION}

        case "$INPUT" in
            "1")
                Install_Vscode
                ;;
            "2")
                Install_GCC11
                ;;
            "3")
                Install_Python3
                ;;
            "4")
                Install_OpenSSL
                ;;
            "5")
                Install_Git2
                ;;
            "6")
                Install_EDA_Libraries
                ;;
            "7")
                Install_Docker
                ;;
            "9")
                Install_Vscode
                Install_GCC11
                Install_Python3
                Install_OpenSSL
                Install_Git2
                Install_EDA_Libraries
                Install_Docker
                ;;
            "0")
                return 0;;
            *)
                printf   "\n **** Feature not implemented yet ****\n\n";;
        esac
    done

    printf "\n    *** Development tools installation completed ***\n\n"
}

# ****************************************************************************
# Install Office applications
# Usage:
#      Install_OfficeApps 
# ****************************************************************************
function Install_OfficeApps() {
    local i
    local input

    if [ ! -f /usr/bin/mate-session ]; then
        printf "\n mate desktop NOT installed\n\n"
        return -1
    fi

    printf "\n *** Install office applications ***\n"

    while [[ true ]]; do
        CONFIG_CHANGED=false

        # main menu
        printf "\n o Installation menu ***\n"
        printf   "   1. Google Chrome\n"
        printf   "   2. Libreoffice\n"
        printf   "   3. Misc\n"
        printf   "   9. All above\n"
        printf   "   0. Exit\n\n"

        DEFAULT_ACTION="0"

        printf   "%55s %4s : " ">>> Your choice" "[$DEFAULT_ACTION]" 
        read INPUT
        INPUT=${INPUT:-$DEFAULT_ACTION}

        case "$INPUT" in
            "1")
                Install_Chrome
                ;;
            "2")
                Install_LibreOffice
                ;;
            "3")
                Install_Office_Misc
                ;;         
            "9")
                Install_Chrome
                Install_LibreOffice
                Install_Office_Misc
                ;;
            "0")
                return 0
                ;;
            *)
                printf   "\n **** Feature not implemented yet ****\n\n"
                ;;
        esac
    done
}

function Install_Chrome() {
    printf "   - Install Chrome browser \n" 

    if [[ $OS_VERSION == "7" ]] ; then
        printf "     > Download from ftp server\n"
        WORK_DIR="/opt/chrome/pkg"
        sudo mkdir -p $WORK_DIR
        curl -# http://dist.control.lth.se/public/CentOS-7/x86_64/google.x86_64/google-chrome-stable-124.0.6367.118-1.x86_64.rpm -o ${WORK_DIR}/google-chrome-stable_current_x86_64.rpm

        sudo yum -y install liberation-fonts libvulkan*

        printf "     > Install Chrome\n"
        sudo yum install liberation-fonts -y
        sudo rpm -i ${WORK_DIR}/google-chrome-stable_current_x86_64.rpm
    else
        sudo dnf install https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -y
    fi

}

function Install_Office_Misc() {
    Install_Single_CentOS_Package  "filezilla"
    Install_Single_CentOS_Package  "evince"
}

function Install_Opera() {
    Install_Single_CentOS_Package  "opera-stable"
}

function Install_LibreOffice() {
    if [[ $OS_VERSION == "7" ]] ; then
        Install_LibreOffice_7
    else
        Install_Most_Recently_LibreOffice
    fi
}

function Install_LibreOffice_7() {
    printf "   - Install LibreOffice 7.6.7\n"

    printf "     > Check current installation\n"
    INSTALLED_VERSION=$(sudo yum list installed | grep -E 'libreoffice[0-9]+\.[0-9]+(\.[0-9]+)?\.x86_64' | awk '{print $2}')    

    if [[ $INSTALLED_VERSION != "7.6.7" ]]; then
        printf "   - Remove installed version $INSTALLED_VERSION \n"
        sudo yum remove libreoffice* -y


        printf "     > Download from ftp server\n"
        RPM_LibreOffice_7_6_7="LibreOffice_7.6.7_Linux_x86-64_rpm.tar.gz"
        RPM_PATH="/opt/libreoffice/rpm"
        RPM_FILE="${RPM_PATH}/${RPM_LibreOffice_7_6_7}"
        ftp_get "apps/centos7/libreoffice/${RPM_LibreOffice_7_6_7}" "${RPM_FILE}"

        if [ ! -f $RPM_FILE ]; then 
            printf "\n   *** Download failure, exit now\n"
            return 1
        fi

        WORK_DIR=$(mktemp -d)

        printf "\n   - Install Libreoffice $lastest_libre_version \n" 
        tar xzf $RPM_FILE --strip-components=2 -C ${WORK_DIR}
        sudo yum localinstall ${WORK_DIR}/*.rpm -y

        rm -rf WORK_DIR

        printf "\n    *** Office applications installation completed ***\n\n"
    else
        printf "   - LibreOffice 7.6.7 is already installed\n"
    fi
}   

function Install_Most_Recently_LibreOffice() {
    printf "   - Install Most Recently Libera Office\n"
    RPM_PATH="/opt/libreoffice/rpm"
    RPM_FILE="${RPM_PATH}/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz"
    sudo mkdir -p $RPM_PATH

    INSTALLED_VERSION=$(sudo yum list installed | grep -E 'libreoffice[0-9]+\.[0-9]+(\.[0-9]+)?\.x86_64' | awk '{print $2}')

    printf "     >> Check latest libreoffice version from Document Foundation\n" 
    while read version; do
        #skip unstable versions
        major=${version%%.*}

        #if (( $major < "20" )); then
            lastest_libre_version=$version
        #fi
    done < <(curl --silent --max-time 15 http://download.documentfoundation.org/libreoffice/stable/  | grep -o 'href="[0-9].*">' | sed 's/href="//;s/\/">.*//')

    if [[ $lastest_libre_version != "" &&  $INSTALLED_VERSION != $lastest_libre_version  ]]; then 
        REMOTE_URL="http://download.documentfoundation.org/libreoffice/stable/${lastest_libre_version}/rpm/x86_64/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz"
        printf "     >>  Download $REMOTE_URL \n"
        curl -# -L http://download.documentfoundation.org/libreoffice/stable/${lastest_libre_version}/rpm/x86_64/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz -o $RPM_FILE

        if [ ! -f $RPM_FILE ]; then
            printf "\n   *** Download failure, try ftp\n"
            while read version; do 
                lastest_libre_version=$version
            done < <(curl --list --silent --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/centos7/libreoffice/ | awk -F'_' '{print $2}')
            if [[ $INSTALLED_VERSION != $lastest_libre_version ]]; then
                REMOTE_URL="ftp://sftp.creekside.network:58222/apps/libreoffice/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz"
                printf "     >>  Download $REMOTE_URL \n"
                sudo curl -# --user downloader:Kkg94290 -o $RPM_FILE

                if [ ! -f $RPM_FILE ]; then 
                    printf "\n   *** Download failure, exit now\n"
                    return 1
                fi
            else
                printf "     >>  ftp version $lastest_libre_version is already installed, exit now\n"
                return "0"
            fi

        fi
    else
        printf "     >>  $lastest_libre_version is already installed, exit now\n"
        return "0"
    fi

    WORK_DIR=$(mktemp -d)

    if [[ $INSTALLED_VERSION != "" ]]; then
        printf "   - Remove installed version $INSTALLED_VERSION \n"
        sudo yum remove libreoffice* -y
    fi

    printf "\n   - Install Libreoffice $lastest_libre_version \n" 
    tar xzf $RPM_FILE --strip-components=2 -C ${WORK_DIR}
    sudo yum localinstall ${WORK_DIR}/*.rpm -y

    rm -rf WORK_DIR

    printf "\n    *** Office applications installation completed ***\n\n"

    return 0
}

mate_packges=("adwaita-gtk2-theme" "lightdm-settings" "lightdm" "gnome-terminal" \
            "alsa-plugins-pulseaudio" "atril" "atril-caja" "atril-thumbnailer" "caja" "caja-actions" "caja-image-converter" "caja-open-terminal" \
             "caja-sendto" "caja-wallpaper" "caja-xattr-tags" "dconf-editor" "engrampa" "eom" "firewall-config" "gnome-disk-utility" \
             "gnome-epub-thumbnailer" "gstreamer1-plugins-ugly-free" "gtk2-engines" "gucharmap" "gvfs-fuse" "gvfs-gphoto2" "gvfs-mtp" \
             "gvfs-smb" "initial-setup-gui" "libmatekbd" "libmatemixer" "libmateweather" "libsecret" "lm_sensors" "marco" "mate-applets" \
             "mate-backgrounds" "mate-calc" "mate-control-center" "mate-desktop" "mate-dictionary" "mate-disk-usage-analyzer" "mate-icon-theme" \
             "mate-media" "mate-menus" "mate-menus-preferences-category-menu" "mate-notification-daemon" "mate-panel" "mate-polkit" \
             "mate-power-manager" "mate-screensaver" "mate-screenshot" "mate-search-tool" "mate-session-manager" "mate-settings-daemon" \
             "mate-system-log" "mate-system-monitor" "mate-terminal" "mate-themes" "mate-user-admin" "mate-user-guide" "mozo" \
             "network-manager-applet" "nm-connection-editor" "p7zip" "p7zip-plugins" "pluma" "seahorse" "seahorse-caja" "xdg-user-dirs-gtk"
             )

mate8_packges=("adwaita-gtk2-theme" "lightdm-gtk-greeter" "gnome-terminal" \
            "alsa-plugins-pulseaudio" "atril" "atril-caja" "atril-thumbnailer" "caja" "caja-actions" "caja-image-converter" "caja-open-terminal" \
             "caja-sendto" "caja-wallpaper" "caja-xattr-tags" "dconf-editor" "engrampa" "eom" "firewall-config" "gnome-disk-utility" \
             "gnome-epub-thumbnailer" "gstreamer1-plugins-ugly-free" "gtk2-engines" "gucharmap" "gvfs-fuse" "gvfs-gphoto2" "gvfs-mtp" \
             "gvfs-smb" "initial-setup-gui" "libmatekbd" "libmatemixer" "libmateweather" "libsecret" "lm_sensors" "marco" "mate-applets" \
             "mate-backgrounds" "mate-calc" "mate-control-center" "mate-desktop" "mate-dictionary" "mate-disk-usage-analyzer" "mate-icon-theme" \
             "mate-media" "mate-menus" "mate-menus-preferences-category-menu" "mate-notification-daemon" "mate-panel" "mate-polkit" \
             "mate-power-manager" "mate-screensaver" "mate-screenshot" "mate-search-tool" "mate-session-manager" "mate-settings-daemon" \
             "mate-system-log" "mate-system-monitor" "mate-terminal" "mate-themes" "mate-user-admin" "mate-user-guide" "mozo" \
             "network-manager-applet" "nm-connection-editor" "p7zip" "p7zip-plugins" "pluma" "seahorse" "seahorse-caja" "xdg-user-dirs-gtk"
             )

#"NetworkManager-adsl" "NetworkManager-bluetooth" "NetworkManager-libreswan-gnome" "NetworkManager-openvpn-gnome" \
#            "NetworkManager-ovs" "NetworkManager-ppp" "NetworkManager-team" "NetworkManager-wifi" "NetworkManager-wwan" 

function Install_MateDesktop() {
    if type -p mate-session; then
        printf "\n mate desktop already installed\n\n"
        return 0
    fi

    printf "\n  o Install mate desktop\n"

    case $OS_VERSION in
        "7")
            sudo yum group install "X Window system" -y
            sudo yum group install "MATE Desktop" -y
            ;;
        "8")
            Install_CentOS_Packages "${mate_packges[@]}"
            ;;
        "9")
            Install_CentOS_Packages "${mate_packges[@]}"
            ;;
        *)
            ;;
    esac

    printf "\n  o Disable user list at login\n"
    sed -i "s%#greeter-hide-users=false%greeter-hide-users=true%" /etc/lightdm/lightdm.conf

    if ! sudo systemctl status graphical.target &> /dev/null; then
        printf "\n  o Start GUI now\n"

        sudo systemctl isolate graphical.target
        sudo systemctl set-default graphical.target
        sudo ln -fs '/usr/lib/systemd/system/graphical.target' '/etc/systemd/system/default.target'
    fi

    printf "  o Disable shutdown menu \n"

    sudo mkdir -p /etc/polkit-1/rules.d
    echo "polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
        action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.hibernate" ||
        action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
    {
        return polkit.Result.NO;
    }
});" | sudo tee /etc/polkit-1/rules.d/55-inhibit-shutdown.rules &> /dev/null


    printf "\n  o Enable mate-session as default \n"
    printf "    - Update default /etc/skel \n"
    echo "mate-session" | sudo tee /etc/skel/.Xclients
    sudo chmod a+x /etc/skel/.Xclients

    printf "    - Update exisitng user homes \n"
    readarray -t homes < <(find "/home" -maxdepth 1 -type d -printf '%P\n')
    for user in ${homes[@]}; do
        printf "      > ${user}\n"
        sudo cp /etc/skel/.Xclients /home/${user}/.Xclients
        sudo chown ${user}: /home/${user}/.Xclients
        sudo chmod a+x /home/${user}/.Xclients
    done

    printf "\n  o Change default xterm fonts and scheme \n"
    printf "    - Update default /etc/skel \n"
    echo "! xterm
xterm*dynamiccolors:      true
xterm*utf8:               2
xterm*geometry:           WINDOWGEOMETRY
xterm*visualBell:         off
xterm*highlightSelection: true
xterm*background:         black
xterm*foreground:         white
xterm*faceName:           Monospace
xterm*faceSize:           11
xterm*colorMode:          on
xterm*colorBD:            lightcyan
xterm*colorBDMode:        on
xterm*colorUL:            white
xterm*colorULMode:        on
xterm*scrollTtyOutput:    false
xterm*scrollKey:          true
xterm*scrollBar:          true" | sudo tee /etc/skel/.Xresources
    sudo chmod a+x /etc/skel/.Xresources

    printf "    - Update exisitng user homes \n"
    readarray -t homes < <(find "/home" -maxdepth 1 -type d -printf '%P\n')
    for user in ${homes[@]}; do
        printf "      > ${user}\n"
        sudo cp /etc/skel/.Xresources /home/${user}/.Xresources
        sudo chown ${user}: /home/${user}/.Xresources
        sudo chmod a+x /home/${user}/.Xresources
    done

    printf "\n o Install extra apps \n"

    if [ ! -f /etc/yum.repos.d/tilix.repo ]; then
        printf "   - Tilix\n" 
        echo "
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
" | sudo tee /etc/yum.repos.d/tilix.repo &> /dev/null
    fi

    if [ ! -f /etc/yum.repos.d/sublime-text.repo ]; then
        printf "   - Sublime-text\n" 
        echo "
[sublime-text]
name=Sublime Text - x86_64 - Stable
baseurl=https://download.sublimetext.com/rpm/stable/x86_64
enabled=1
gpgcheck=0
gpgkey=https://download.sublimetext.com/sublimehq-rpm-pub.gpg
" | sudo tee /etc/yum.repos.d/sublime-text.repo &> /dev/null
    fi
    packages=("vim" "vim-X11" "emacs" "tilix" "sublime-text" "meld")
    Install_CentOS_Packages "${packages[@]}"

    printf "\n    *** Mate desktop installation completed ***\n\n"
}

# ****************************************************************************
# Update authorized sshkeys 
# ****************************************************************************

function Update_SSH_Keys() {
    SSH_KEY_RSA_CREEKSIDE="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p creeksidenetworks@gmail.com"
    SSH_KEY_EDCSA_CREEKSIDE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJggtEGPdn91k36jza3Ln+pXivNTjcT+l17fwFaVpecP jtong@creekside.network"

    if [[ $1 == "root" ]]; then
        home_dir="/root"
    else
        home_dir="/home/$1"
    fi

    ssh_dir=${home_dir}/.ssh

    if [ ! -d $home_dir ]; then 
        # no such user, skip
        printf "    - skip non-exist user: $home_dir\n"
        return
    elif [ ! -d $ssh_dir ]; then 
        sudo mkdir -p $ssh_dir
    fi

    ssh_authorized_keyfile="${ssh_dir}/authorized_keys"
    if [ ! -f $ssh_authorized_keyfile ]; then 
        sudo touch $ssh_authorized_keyfile
    fi


    if ! grep -q "$SSH_KEY_RSA_CREEKSIDE" $ssh_authorized_keyfile; then
        printf "    - update user rsa key: $1\n"
        echo $SSH_KEY_RSA_CREEKSIDE | sudo tee -a $ssh_authorized_keyfile  &> /dev/null
    fi

    if ! grep -q "$SSH_KEY_ED_CREEKSIDE" $ssh_authorized_keyfile; then
        printf "    - update user edcsa key: $1\n"
        echo $SSH_KEY_ED_CREEKSIDE | sudo tee -a $ssh_authorized_keyfile  &> /dev/null
    fi

}

# ****************************************************************************
# Add ssh key
# ****************************************************************************
function Add_SSH_AuthorizedKey() {
    user="$1"
    pubkey="$2" 

    if [[ $user == "root" ]]; then
        homedir="/root"
    else
        homedir="/home/${user}"
    fi

    authroizedkey_file="${homedir}/.ssh/authorized_keys"

    if ! sudo test -d "${homedir}/.ssh"; then
        sudo mkdir -p "${homedir}/.ssh"
        sudo chown ${user}:${user} ${homedir}/.ssh/
    fi 

    if ! sudo test -f ${authroizedkey_file}; then
        sudo touch ${authroizedkey_file}
        sudo chown ${user}:${user} ${authroizedkey_file}
    fi 

    
    if ! sudo grep -q "${pubkey}" "${authroizedkey_file}"; then
        echo "${pubkey}" | sudo tee -a "${authroizedkey_file}" &> /dev/null
    fi
}

# ****************************************************************************
# Initialize a CentOS host
# Usage:
#      Initial_CentOS
# ****************************************************************************
function OS_Init() {
    local UPDATE_REQUIRED="N"
    DISABLE_SELINUX="Y"
    DEFAULT_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p creeksidenetworks@gmail.com"
    DEFAULT_EDCSA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJggtEGPdn91k36jza3Ln+pXivNTjcT+l17fwFaVpecP jtong@creekside.network"
    JUNSONG_RSA_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQChzHPb3CTFUwEPCm1sZQUwiJIWhrw8PtuKWyOOgBjPCGVbavRjHDKlaXSgh3JtEBovQX0CLvqR+dMDJEjYGCRQRyfLT84K7ozEbfw8tX+IlWrLGQ7t6bZQjp1d70ulFWWVwTFLtcA3RGONSAR+Jt0zTzkhFCjPp8CagRe7nY7KNh3kE7y19OlWoP4eNw0ZAaMcUajKd6YJXYs4LnpoyM2lrWZRssa3kiPxzpyJj9z0mrc5hH6WmrKyPAuJO4GuFXNUwGre/H5DIoXUgzmZZTbusE25exGkKpweFo4M/CxB2szebr0XKViwYrp3sT0ELUk92cJC65HkmFTrj/Fq49VEXJ3Z3fwoootyhPFQ/Gk5JrJ+bNsvSRRBS+m7f/afOq9m5jvx907nnP8HN9W0pJkrmJkzz7Lvzm7BfaMMJ9TUWf9olroLXWy+VkH8RdW0MKz7zZ1sCLhIerZz1iUtkVhPTjRYmWQZtFgSc7b4hhm6Xw7bGMhRZa91SJTt3MzUeM8= jsong@creekside.network"
    # check & enable sudoer nopassword
    printf "\n  o Enable no-password for sudo commands\n"
    printf "\n *** Your sudo password maybe required ***\n\n"
    Disable_Sudo_Passwd "wheel"

    # Install essential packages
    printf "\n o Install some essential packages\n"

    if [[ $OS_VERSION == "7" ]] && [[ ! -f /etc/yum.repos.d/CentOS-Base.repo.bak ]]; then
        # update centos repo 
        sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak

        sudo cat  <<EOF >> /etc/yum.repos.d/CentOS-Base.repo
[base]
name=CentOS-7 - Base
baseurl=http://vault.centos.org/centos/7/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7 - Updates
baseurl=http://vault.centos.org/centos/7/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7 - Extras
baseurl=http://vault.centos.org/centos/7/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[centosplus]
name=CentOS-7 - Plus
baseurl=http://vault.centos.org/centos/7/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF

    fi



    Install_Single_CentOS_Package "epel-release"
    sudo yum update -y

    case $OS_VERSION in
        "7")
            Install_Single_CentOS_Package "kernel-devel"

            ;;
        "8")
            sudo yum config-manager --set-enabled powertools
            Install_Single_CentOS_Package "libnsl"
            ;;
        "9")
            sudo yum config-manager --set-enabled crb
            Install_Single_CentOS_Package "libnsl"
            ;;
        *)
            ;;
    esac

    Install_CentOS_Packages "${default_packages[@]}"

    if ! rpm -q --quiet gcc; then
        printf "\n o Install standard develeopment tools\n"
        sudo yum groupinstall "Development tools" -y
    fi  

    case $OS_VERSION in
        "7")
            if ! sudo rpm -q --quiet "ntp"; then
                Install_Single_CentOS_Package "ntp"
                sudo systemctl enable ntpd --now
            fi
            ;;
        "9")
            if ! sudo systemctl is-enabled NetworkManager; then
                printf "\n  o Enable NetworkManager\n"
                sudo systemctl enable NetworkManager
            fi    
            ;;        
        *)
            ;;
    esac

    GEOINFO=$(curl -s http://ip-api.com/json/)

    if [[ -z $GEOINFO ]]; then
        echo -e "\n**** Can not retrieve geometry infomration, use China as default\n"
        COUNTRY="CN";
        TIMEZONE="Asia/Shanghai"
    else
        COUNTRY=$(echo $GEOINFO | jq '.countryCode' | tr -d \")
        TIMEZONE=$(echo $GEOINFO | jq '.timezone' | tr -d \")
        ISP=$(echo $GEOINFO | jq '.isp' | tr -d \")
    fi

    # Collect some local information
    if [[ $LOCAL_HOSTNAME == "" ]]; then
        LOCAL_HOSTNAME=$(hostnamectl | grep -o "hostname:.*" | awk '{print $2}')
        LOCAL_HOSTNAME=$(echo $LOCAL_HOSTNAME | cut -d . -f 1)
    fi

	# ipa options
	while [[ true ]]; do
        printf "\n o Required informations:\n"

        Read_Hostname "   - Hostname" "$LOCAL_HOSTNAME"
        LOCAL_HOSTNAME=$READ_VALUE

        printf "%-20s %39s : " "   - Timezone" "[$TIMEZONE]"
        read INPUT
        INPUT=${INPUT:-$TIMEZONE}

        if Inquiry "   - Disable SELinux?" $DISABLE_SELINUX; then
            DISABLE_SELINUX="Y"
        fi

        # get user confirmation
	    echo ""
	    if  Ask_Confirm "   >>> Do you confirm?" "N"; then
	        break
        else
        	if  Ask_Confirm "   >>> Return to main menu?" "N"; then
                return 1
            fi
	    fi  
	done

    printf "\n  o Update default ssh key \n"

    printf "    - root \n"
    Add_SSH_AuthorizedKey "root" "$DEFAULT_SSH_KEY"
    Add_SSH_AuthorizedKey "root" "$DEFAULT_EDCSA_KEY"
    Add_SSH_AuthorizedKey "root" "$JUNSONG_RSA_KEY"

    printf "    - admin \n"
    sudo grep -q admin /etc/passwd
    if ! sudo grep -q admin /etc/passwd; then
        admin_password=$(tr -dc A-Z </dev/urandom | head -c 1)
        admin_password=${admin_password}$(tr -dc a-z </dev/urandom | head -c 2)
        admin_password=${admin_password}$(tr -dc 0-9 </dev/urandom | head -c 5)

        admin_password="calvin2024+"

        printf "%-60s : %s\n" "      > create new sudo user admin" "$admin_password"
        sudo useradd admin
        sudo usermod -aG wheel admin
        echo "admin:$admin_password" | sudo chpasswd
    fi

    Add_SSH_AuthorizedKey "admin" "$DEFAULT_SSH_KEY"
    Add_SSH_AuthorizedKey "admin" "$DEFAULT_EDCSA_KEY"

    printf "\n  o Disable SSH DNS reverse lookup \n"
    TARGET_KEY="UseDNS"
    REPLACEMENT_VALUE="no"
    sudo sed -i "s%^\($TARGET_KEY\s*\).*\$%\1 $REPLACEMENT_VALUE%" /etc/ssh/sshd_config
    # install firewalld
    if sudo systemctl is-enabled firewalld; then
        printf "\n  o Firewall is already enabled\n"
    else
        printf "\n  o Enable firewall\n"
        sudo systemctl enable firewalld
        REBOOT_RQUIRED="Y"
    fi

    printf "\n  o Update local hostname\n"
    sudo hostnamectl set-hostname $LOCAL_HOSTNAME

    printf "\n  o Set time zone & enable ntp\n"
    sudo  timedatectl set-timezone $TIMEZONE
    sudo  timedatectl set-ntp true

    if [[ $DISABLE_SELINUX == "Y" ]]; then
        printf "\n  o Disable SELINUX\n"
        sudo sed -i  "s%SELINUX=enforcing%SELINUX=disabled%g" /etc/selinux/config 
        sudo setenforce 0
    fi

    ifname_change=$(grep "net.ifnames=0" /etc/default/grub)
    if [[ $ifname_change == "" ]]; then
        printf "\n  o Enable network interface name change\n"
        CMDLINE=$(awk -F'"' '/^GRUB_CMDLINE_LINUX/{print $2}' /etc/default/grub)
#        sudo sed -i "s^$CMDLINE^$CMDLINE net.ifnames=0 biosdevname=0^g" /etc/default/grub
        sudo sed -i "s^$CMDLINE^$CMDLINE net.ifnames=0^g" /etc/default/grub
        sudo grub2-mkconfig  -o /boot/grub2/grub.cfg

       #sudo systemctl disable NetworkManager

        printf "\n    *** A reboot is required ***\n\n"
        if Ask_Confirm ">>> Do you want to reboot now?" "N"; then
            sudo reboot
        else 
            return 1
        fi
    fi

    printf "\n    *** Initialization completed ***\n\n"
    
}

# ****************************************************************************
# Install xrdp
# ****************************************************************************
function Install_xrdp() {
    printf "\n  o Install xrdp\n"

    if rpm -q --quiet xrdp; then
        printf  "    - xrdp already installed\n"
        return 0
    fi

    ALLOW_CLIPBOARD="N"
    ALLOW_DRIVEMAP="N"
	while [[ true ]]; do
        if rpm -q --quiet realvnc-vnc-server; then
            printf  "   - RealVNC server was installed, it has to be removed\n"
        fi

        if  Inquiry "   - Allow user cut/copy from server?" "$ALLOW_CLIPBOARD"; then
            ALLOW_CLIPBOARD="Y"
        else
            ALLOW_CLIPBOARD="N"
        fi

        if  Inquiry "   - Allow map remote drive?" "$ALLOW_DRIVEMAP"; then
            ALLOW_DRIVEMAP="Y"
        else
            ALLOW_DRIVEMAP="N"
        fi


        # get user confirmation
	    echo ""
	    if  Ask_Confirm "   Do you confirm?" "N"; then
	        break
        else
        	if  Ask_Confirm "   Return to main menu?" "N"; then
                return 1
            fi
	    fi  
	done

    if rpm -q --quiet realvnc-vnc-server; then
        printf "\n  o Remove previous installed realVNC\n"
        sudo yum remove realvnc-vnc-server -y -q 
        sudo firewall-cmd --permanent --remove-service=vncserver-virtuald -q 
    fi

    printf "\n  o Install necessary packages\n"
    xrdp_packages=("tigervnc" "tigervnc-server" "xrdp")
    for pacakge in ${xrdp_packages[@]}; do
        Install_Single_CentOS_Package $pacakge
    done

    printf "\n  o Update xrdp.ini\n"
    XRDP_INI_FILE="/etc/xrdp/xrdp.ini"

    # enable channles
    Update_Conf "allow_channels" "true" $XRDP_INI_FILE

    # drive remap
    if [[ $ALLOW_DRIVEMAP == "Y" ]]; then
        Update_Conf "rdpdr" "true" $XRDP_INI_FILE
    else
        Update_Conf "rdpdr" "false" $XRDP_INI_FILE
    fi

    # enable sound by default
    Update_Conf "rdpsnd" "true" $XRDP_INI_FILE 

    # disable dynamic channles 
    Update_Conf "drdynvc" "false" $XRDP_INI_FILE   

    # disable remote application integration
    Update_Conf "rail" "false" $XRDP_INI_FILE 

    # enable xrdp video streaming
    Update_Conf "xrdpvr" "true" $XRDP_INI_FILE 
    
    # clipboard
    if [[ $ALLOW_CLIPBOARD == "Y" ]]; then
        Update_Conf "cliprdr" "true" $XRDP_INI_FILE
    else
        Update_Conf "cliprdr" "false" $XRDP_INI_FILE
    fi

    printf "\n o Update firewall\n"    
    sudo firewall-cmd --permanent -q --add-port=3389/tcp
    sudo firewall-cmd -q --reload

    printf "\n o Start xrdp service\n"
    sudo systemctl enable xrdp -q
    sudo systemctl restart xrdp -q

    printf "  o Enable mate-session as default \n"
    echo "mate-session" | sudo tee /etc/skel/.Xclients
    sudo chmod a+x /etc/skel/.Xclients

    printf "  o Update exisitng user homes \n"
    readarray -t homes < <(find "/home" -maxdepth 1 -type d -printf '%P\n')
    for user in ${homes[@]}; do
        printf "    - ${user}\n"
        sudo cp /etc/skel/.Xclients /home/${user}/.Xclients
        sudo chown ${user}: /home/${user}/.Xclients
        sudo chmod a+x /home/${user}/.Xclients
    done
    printf "\n    *** xrdp setup completed ***\n\n"

}

# ****************************************************************************
# Install Real VNC virtual mode
# ****************************************************************************
function Install_RealVNC() {
    printf "\n  o Setup Real VNC virtual mode\n"

    ALLOW_CLIPBOARD="N"
    ALLOW_FILESHARE="N"

    if rpm -q --quiet realvnc-vnc-server; then
        printf  "    - RealVNC server already installed\n"
        return 0
    fi

	while [[ true ]]; do
        if rpm -q --quiet xrdp; then
            printf  "    - xrdp server was installed, it has to be removed\n"
        fi

        Read_String "   - License key [xxxxx-xxxxx-xxxxx-xxxxx-xxxxx]" "" "29" "29"
        LICENSE_KEY=$READ_VALUE

        if  Inquiry "   - Allow user cut/copy from server?" "$ALLOW_CLIPBOARD"; then
            ALLOW_CLIPBOARD="Y"
        else
            ALLOW_CLIPBOARD="N"
        fi

        if  Inquiry "   - Allow file sharing?" "$ALLOW_FILESHARE"; then
            ALLOW_FILESHARE="Y"
        else
            ALLOW_FILESHARE="N"
        fi

        if  Ask_Confirm "   >>> Do you confirm?" "N"; then
            break
        else
            return 1
        fi
    done

    if rpm -q --quiet xrdp; then
        printf "\n  o Remove previous installed xrdp\n"
        sudo yum remove "tigervnc" "tigervnc-server" "xrdp" -y -q 
        sudo firewall-cmd --permanent --remove-port=3389/tcp -q
    fi

    printf "\n  o Install RealVNC Dummy video driver to support 4K\n"

    if ! rpm -q --quiet gcc; then
        printf "\n o Install prerequisted standard develeopment tools\n"
        sudo yum groupinstall "Development tools" -y
    fi 

    printf "\n   - Install vnc driver develeopment tools\n"
    vnc_dev_packages=("autoconf" "automake" "libtool" "make" "pkgconfig" "xorg-x11-server-devel" "xorg-x11-proto-devel")
    Install_CentOS_Packages "${vnc_dev_packages[@]}"

    WORK_DIR=$(mktemp -d)
    cd ${WORK_DIR}
    printf "\n   - Download driver source from Creekside ftp\n"
    ftp_get "/private/apps/realVNC/driver/xf86-video-vnc-master.zip" "${WORK_DIR}/xf86-video-vnc-master.zip"
    unzip ${WORK_DIR}/xf86-video-vnc-master.zip
    cd ${WORK_DIR}/xf86-video-vnc-master
    ${WORK_DIR}/xf86-video-vnc-master/buildAndInstall automated

    printf "\n  o Install RealVNC 6.11\n"
    printf "\n   - Download VNC server package from Creekside ftp\n"
    ftp_get "/private/apps/realVNC/server/VNC-Server-6.11.0-Linux-x64.rpm" "${WORK_DIR}/VNC-Server-6.11.0-Linux-x64.rpm"
    Install_Single_CentOS_Package "realvnc-vnc-server" ${WORK_DIR}/VNC-Server-6.11.0-Linux-x64.rpm

    printf "  o Update firewall\n"
    sudo firewall-cmd --permanent --add-service=vncserver-virtuald
    sudo firewall-cmd --reload

    printf "  o Create common.custom configuration\n"
    echo "
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
" | sudo tee /etc/vnc/config.d/common.custom &> /dev/null


if [[ $ALLOW_CLIPBOARD == "Y" ]]; then
    echo "SendCutText=TRUE" | sudo tee -a /etc/vnc/config.d/common.custom &> /dev/null
else
    echo "SendCutText=FALSE" | sudo tee -a /etc/vnc/config.d/common.custom &> /dev/null
fi


if [[ $ALLOW_FILESHARE == "Y" ]]; then
    echo "ShareFiles=TRUE" | sudo tee -a /etc/vnc/config.d/common.custom &> /dev/null
else
    echo "ShareFiles=FALSE" | sudo tee -a /etc/vnc/config.d/common.custom &> /dev/null
fi

    printf "  o Enable domain authentication\n"
    echo "auth include password-auth
account include password-auth
session include password-auth
" | sudo tee /etc/pam.d/vncserver.custom &> /dev/null

    echo "PamApplicationName=vncserver.custom" | sudo tee -a /etc/vnc/config.d/common.custom &> /dev/null

    printf "  o Add license key\n"
    vnclicense -add $LICENSE_KEY
    
    printf "  o Start virtual desktop service now\n"
    sudo systemctl enable vncserver-virtuald.service --now

    printf "  o Enable mate-session as default \n"
    echo "mate-session" | sudo tee /etc/skel/.Xclients &> /dev/null
    sudo chmod a+x /etc/skel/.Xclients

    printf "  o Update exisitng user homes \n"
    readarray -t homes < <(find "/home" -maxdepth 1 -type d -printf '%P\n')
    for user in ${homes[@]}; do
        printf "    - ${user}\n"
        sudo cp /etc/skel/.Xclients /home/${user}/.Xclients
        sudo chown ${user}: /home/${user}/.Xclients
        sudo chmod a+x /home/${user}/.Xclients
    done
    printf "\n    *** VNC Setup completed ***\n\n"
}

# install etx node 
function Install_ETX_Node() {
    ETXCN_PATH="/opt/etx/cn"

    INSTALL_PATH=/opt/etx/packages
    sudo mkdir -p $INSTALL_PATH

    if sudo systemctl is-enabled otetxcn.service &> /dev/null; then 
        path_etxsvr=$(sudo systemctl show otetxcn.service | grep "ExecStart={ path=" | awk -F\; '{print $1}' | awk -F= '{print $3}')
        printf "    - Found exisitng installation @ \"$ETXCN_PATH\"\n"
        return 0
    fi

    printf "\n o Install Exceed Turbo X node\n"    
    printf "   - Check available version\n"
    while read etx_node_file; do
        if [[ $etx_node_file ==  *"-linux-x64.tar.gz" ]]; then
            version=$(echo $etx_node_file | awk -F - '{print $2}')
            printf "     > Find version $version\n"
            break
        fi 
    done < <(curl --silent --list --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/ETXConnectionNode/)

    if [[ $etx_node_file == "" ]]; then
        printf "     > No available ETX connection node file found, exist\n"
        return -1
    fi

    INSTALL_FILE=${INSTALL_PATH}/$etx_node_file

    printf "   - Download $etx_node_file from ftp server\n"
    WORK_DIR=$(mktemp -d)
    curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/ETXConnectionNode/${etx_node_file} -o $INSTALL_FILE

    printf "   - Extract to $ETXCN_PATH\n"
    sudo mkdir -p $ETXCN_PATH
    sudo tar xzf $INSTALL_FILE --strip-components=1 -C $ETXCN_PATH

    printf "   - Install connection node\n"

    cat  <<EOF >> ${WORK_DIR}/install_options
install.etxcn.ListenPort=5510
install.etxcn.StartNow=1
install.etxcn.AllowMigrate=0
install.etxcn.CreateETXProxyUser=0
install.etxcn.CreateETXXstartUser=0
install.service.createservice=1
install.service.bBootStart=1
install.register.bAutoRegister=0
EOF
    sudo $ETXCN_PATH/bin/install -s  ${WORK_DIR}/install_options


options="install.register.r_serverurl=
install.register.r_resttoken=
install.register.r_overridehostname=
install.register.r_proxy=
install.register.r_WebAdaptor=1
install.register.WebAdaptorPort=5510
install.register.r_auth=0
install.register.r_appscan=0
install.register.r_firstdisplay=1
install.register.r_altnameserver=
install.register.r_altnameclient=
install.register.r_additionaloptions=
install.register.r_maxtotalsessions=30
install.register.r_maxsessperuser=2
install.register.r_allownewsess=
install.register.r_sshcommand=
install.register.r_notes=
install.register.r_ssrconfig=1"

    printf "   - Enable authentication\n"    
    sudo cp /etc/pam.d/sshd /etc/pam.d/exceed-connection-node

    printf "   - Prevent Gnome core dump at session termination\n"
    echo 'ulimit -c 0 > /dev/null 2>&1' | sudo tee /etc/profile.d/disable-coredumps.sh &> /dev/null

    printf "   - Update firewall\n"
    sudo firewall-cmd -q --permanent --add-port=5510/tcp
    sudo firewall-cmd -q --reload

    rm -rf ${WORK_DIR}
}

function Install_ETX_Server() {
    printf "\n o Install Exceed Turbo X server\n"

    INSTALL_PATH=/opt/etx/packages
    sudo mkdir -p $INSTALL_PATH

    if sudo systemctl is-enabled otetxsvr.service &> /dev/null; then 
        path_etxsvr=$(sudo systemctl show otetxsvr.service | grep "ExecStart={ path=" | awk -F\; '{print $1}' | awk -F= '{print $3}')
        printf "    - Found exisitng installation @ \"$path_etxsvr\"\n"
        return 0
    fi

    etx_admin_passwd="Good2Great"

    standalone="Y"
    proxy_on="Y"
    while [[ true ]]; do
        printf "\n   - Installation options\n"

        if  ! Inquiry "     > Standalone mode (N for cluster)?" "$standalone"; then
            standalone="N"
        fi

        Read_String "     > Built-in etxadmin password" "$etx_admin_passwd"  3 64
        etx_admin_passwd=$READ_VALUE

        if  Inquiry "     > Setup reverse proxy and enable cerbot?" "$proxy_on"; then
            Read_Domain "     > Domain name" "$etx_domain_name" 
            etx_domain_name=$READ_VALUE

            Read_String "     > Cloudflare API token" "$cloudflare_api_token"  40 40
            cloudflare_api_token=$READ_VALUE

            proxy_on="Y"
        else
            proxy_on="N"
        fi

        if  Inquiry "     > Install Azure oauth2 proxy?" "$oauth2_on"; then

            Read_String "     > Welcome banner" "$portal_banner" 10 50
            portal_banner=$READ_VALUE

            Read_String "     > Azure client ID" "$azure_client_id" 36 36
            azure_client_id=$READ_VALUE

            Read_String "     > Azure tenent ID" "$azure_tenet_id"  36 36
            azure_tenet_id=$READ_VALUE

            Read_String "     > Azure API secrete" "$azure_secret"  40 40
            azure_secret=$READ_VALUE

            Read_String "     > Allowed email domain" "$allowed_email_suffix"  4 128
            allowed_email_suffix=$READ_VALUE

            oauth2_on="Y"
        else
            oauth2_on="N"
        fi

        # get user confirmation
	    echo ""
	    if  ! Ask_Confirm "   >>> Do you confirm?" "N"; then
            if  Ask_Confirm "   >>> Return to main menu?" "N"; then
                return 1
            else 
                continue
            fi
        else
            break
	    fi  
    done

    printf "\n   - Check available version\n"
    
    # Find the most recent version of ETX Server
    etx_server_file=""
    latest_version=""
    latest_build=""
    
    while read filename; do
        if [[ $filename ==  *"-linux-x64.tar.gz" ]]; then
            # Extract version and build number from filename
            # Format: ETXServer-12.5.3.9413-linux-x64.tar.gz
            version_build=$(echo $filename | sed 's/ETXServer-\(.*\)-linux-x64.tar.gz/\1/')
            
            if [[ -z $latest_version ]]; then
                # First valid file found
                latest_version=$version_build
                etx_server_file=$filename
            else
                # Compare versions using sort -V (version sort)
                newer=$(printf "%s\n%s\n" "$latest_version" "$version_build" | sort -V | tail -n1)
                if [[ $newer == $version_build ]]; then
                    latest_version=$version_build
                    etx_server_file=$filename
                fi
            fi
        fi 
    done < <(curl --silent --list --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/ETXServer/)

    if [[ $etx_server_file == "" ]]; then
        printf "     > No available ETX server file found, exit\n"
        return -1
    fi
    
    printf "     > Selected latest version: $latest_version ($etx_server_file)\n"

    printf "\n   - Download $etx_server_file from ftp server\n"
    WORK_DIR=$(mktemp -d)
    curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/ETXServer/${etx_server_file} -o ${INSTALL_PATH}/${etx_server_file}

    printf "\n   - Extract to /opt\n"
    path_etxsvr="/opt/etx/svr/"
    sudo mkdir -p $path_etxsvr
    sudo tar xzf ${INSTALL_PATH}/${etx_server_file} --strip-components=1 -C $path_etxsvr

    if [[ $standalone == "Y" ]]; then
        printf "   - Prepare for standalone mode\n"
        sudo $path_etxsvr/bin/etxsvr datastore init
        sudo $path_etxsvr/bin/etxsvr bootstart enable
        sudo $path_etxsvr/bin/etxsvr config eulaAccepted=1
        sudo $path_etxsvr/bin/etxsvr etxadmin setpasswd -p $etx_admin_passwd
    fi

    printf "\n   - Check available server updates\n"
    while read etx_patch_file; do
        if [[ $etx_patch_file ==  *"-linux-x64.sh" ]]; then
            version=$(echo $etx_patch_file | awk -F - '{print $2}')
            printf "     > Find version $version\n"
            break
        fi 
    done < <(curl --silent --list-only --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/patches/server/)

    if [[ $etx_patch_file == "" ]]; then
        printf "\n     > No available runtime update found\n"
        return -1
    else
        printf "\n     >  Download $etx_patch_file from ftp server\n"
        sudo curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/patches/server/${etx_patch_file} -o ${INSTALL_PATH}/${etx_patch_file}
        etx_svr_status=$(${path_etxsvr}/bin/etxsvr status)
        if [ $? -eq 0 ]; then 
            printf "     >  Stop Exceed Turbo X server\n"
            sudo ${path_etxsvr}/bin/etxsvr stop
        fi
        printf "\n     >  Apply to Exceed Turbo X server\n"
        cd ${path_etxsvr}
        sudo cp ${INSTALL_PATH}/${etx_patch_file} ${path_etxsvr}/${etx_patch_file}
        sudo sh ${path_etxsvr}/${etx_patch_file} --quiet 
        sudo rm -f ${path_etxsvr}/${etx_patch_file}  
    fi

    printf "\n   - Update firewall\n"
    sudo firewall-cmd -q --permanent --add-port={5510/tcp,5610/tcp,8080/tcp,8443/tcp}
    sudo firewall-cmd -q --reload

    etx_svr_status=$(${path_etxsvr}/bin/etxsvr status)
    if [ $? -ne 0 ]; then 
        printf "\n   - Start Exceed Turbo X server\n"
        sudo ${path_etxsvr}/bin/etxsvr start
    fi 

    printf "\n   - Check available runtime updates\n"
    while read etx_runtime_file; do
        if [[ $etx_runtime_file ==  "etxruntime"* ]]; then
            version=$(echo $etx_runtime_file | awk -F - '{print $2}')
            printf "     > Find version $version\n"
            break
        fi 
    done < <(curl --silent --list-only --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/patches/runtime/)

    if [[ $etx_runtime_file == "" ]]; then
        printf "\n     > No available runtime update found\n"
        return -1
    else
        printf "\n     >  Download $etx_runtime_file from ftp server\n"
        curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/etx/patches/runtime/${etx_runtime_file} -o ${WORK_DIR}/${etx_runtime_file}
        printf "\n     >  Upload to Exceed Turbo X server\n"
        sudo ${path_etxsvr}/bin/etxsvr runtime add ${WORK_DIR}/${etx_runtime_file}
    fi

    if [[ $proxy_on == "Y" ]]; then

        printf "\n   - Install Nginx revers proxy and certbot\n"
        sudo yum install nginx nginx-mod-stream certbot redis -y 

        case $OS_VERSION in
            "7")
                sudo yum install python2-cloudflare python2-certbot-dns-cloudflare  -y 
                ;;
            "9")
                sudo yum install python3-cloudflare python3-certbot-dns-cloudflare -y 
                ;;        
            *)
                ;;
        esac

        printf "\n   - Generate DH parameters\n"
        sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

        printf "\n   - Setup cerbot to obtain certificate\n"
        sudo mkdir -p /etc/cloudflare
        api_key_file="/etc/cloudflare/certbot.cloudflare.api.ini"
        echo "dns_cloudflare_api_token = ${cloudflare_api_token}" | sudo tee $api_key_file
        sudo chmod 600 $api_key_file

        sudo certbot certonly --cert-name ${etx_domain_name} \
            --dns-cloudflare --dns-cloudflare-credentials ${api_key_file} \
            --server https://acme-v02.api.letsencrypt.org/directory \
            -d ${etx_domain_name} \
            -m creeksidenetworks@gmail.com --agree-tos -q

        printf "\n   - Add daily cron job to renew certs\n"
        croncmd="/usr/bin/certbot renew --noninteractive"
        cronjob="0 0 * * * $croncmd"
        ( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -

        if [[ $oauth2_on == "Y" ]]; then
            oauth2_proxy_path="/opt/oauth2-proxy"
            printf "\n   - Install oauth2-proxy\n"
            oauth2_proxy_file="oauth2-proxy-v7.2.1.linux-amd64.tar.gz"
            printf "\n     >  Download $oauth2_proxy_file from ftp server\n"
            curl -# --user downloader:Kkg94290 --insecure ${SFTP_URL}/apps/oauth2-proxy/${oauth2_proxy_file} -o ${WORK_DIR}/${oauth2_proxy_file}
            printf "\n     >  Untar to ${oauth2_proxy_path}/bin\n"
            sudo mkdir -p ${oauth2_proxy_path}/{bin,conf}
            sudo tar --strip-components=1 -xzf ${WORK_DIR}/${oauth2_proxy_file} -C "${oauth2_proxy_path}/bin"
            printf "\n     >  Generate oauth2 configuration at /opt/oauth2-proxy/conf\n"
            cookie_secret=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d -- '\n' | tr -- '+/' '-_'; echo)
            echo "## OAuth2 Proxy Config File
## Created by Creekside Networks LLC

## for nginx auth use case:
pass_user_headers = true
pass_host_header = true
set_authorization_header = true
pass_authorization_header = true
set_xauthrequest  = true

## Are we running behind a reverse proxy? Will not accept headers like X-Real-Ip unless this is set.
reverse_proxy = true

## the OAuth Redirect URL.
redirect_url = \"https://$etx_domain_name/oauth2/callback\"

## allowed email suffix, can be multiple seperated by comma
email_domains = [
     \"${allowed_email_suffix}\"
 ]


## Logging configuration
logging_filename = \"/var/log/oauth2_proxy.log\"
logging_max_size = 100
logging_max_age = 7
logging_local_time = true
logging_compress = false

## The OAuth Client ID, Secret
provider=\"azure\"
client_id=\"${azure_client_id}\"
client_secret=\"${azure_secret}\"
oidc_issuer_url=\"https://sts.windows.net/${azure_tenet_id}/\"

## Customize 
banner=\"${portal_banner}\"
footer=\"Powered by Creekside Networks\"

cookie_name = \"_oauth2_proxy\"
cookie_secret=\"${cookie_secret}\"
cookie_secure=false
cookie_expire=\"4h0m0s\"

## cookie storage at local redis
session_store_type = \"redis\"
redis_connection_url = \"redis://localhost:6379\"
" | sudo tee "${oauth2_proxy_path}/conf/oauth2_proxy.conf"

            nginx_conf_oauth_settings="
        auth_request /oauth2/auth;
        error_page 401 = /oauth2/sign_in;
        # pass Set-Cookie headers from the subrequest response back to requestor
        auth_request_set     \$auth_cookie \$upstream_http_set_cookie;
        add_header         Set-Cookie \$auth_cookie;
"
            printf "\n   - Prepare oauth2-proxy service\n"
            echo "[Unit]
Description=oauth2_proxy daemon
After=syslog.target network.target

[Service]
ExecStart=${oauth2_proxy_path}/bin/oauth2-proxy --config ${oauth2_proxy_path}/conf/oauth2_proxy.conf
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/oauth2-proxy.service
        sudo systemctl enable oauth2-proxy.service --now
        else
            nginx_conf_oauth_settings=""
        fi


        # ---------------------------------------------
        printf "\n   - Create Nginx conf file\n"

        echo "SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin

0 0 * * * /usr/bin/certbot renew --nginx --renew-hook \"/bin/systemctl reload nginx.service\"" | sudo tee /etc/cron.daily/cerbot
    sudo chmod +x /etc/cron.daily/cerbot

    echo "server {
    listen 80;
    server_name $etx_domain_name;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen     443 ssl;
    server_name $etx_domain_name;

    ssl_certificate /etc/letsencrypt/live/$etx_domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$etx_domain_name/privkey.pem;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout  10m;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    location /oauth2/ {
        proxy_pass           http://localhost:4180;
        proxy_set_header     Host                    \$host;
        proxy_set_header     X-Real-IP               \$remote_addr;
        proxy_set_header     X-Scheme                \$scheme;
        proxy_set_header     X-Auth-Request-Redirect \$request_uri;
    }

    location = /oauth2/auth {
        proxy_pass           http://localhost:4180;
        proxy_set_header     Host             \$host;
        proxy_set_header     X-Real-IP        \$remote_addr;
        proxy_set_header     X-Scheme         \$scheme;
    
        # nginx auth_request includes headers but not body
        proxy_set_header     Content-Length   \"\";
        proxy_pass_request_body off;
    }

    # whitelist .zip & .xml file
    location ~.*\.(zip|xml)?$ {
        proxy_set_header     Host \$host;
        proxy_set_header     X-Real-IP  \$remote_addr;
        proxy_set_header     X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass           http://localhost:8080;
    }

    location / {

${nginx_conf_oauth_settings}

        proxy_set_header     Host \$host;
        proxy_set_header     X-Real-IP  \$remote_addr;
        proxy_set_header     X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_redirect off;
        proxy_buffering off;
        proxy_pass         http://localhost:8080/;

    }
}
" | sudo tee /etc/nginx/conf.d/$etx_domain_name.conf



        printf "\n   - Update firewall\n"
        sudo firewall-cmd -q --permanent --add-service=http --add-service=https
        sudo firewall-cmd -q --reload

        printf "\n   - Now start Nginx\n"
        sudo systemctl enable --now nginx redis

    fi


    rm -rf ${WORK_DIR}
    printf   "\n **** Finish setting up Exceed Turbo X server****\n\n"
}

# ****************************************************************************
# Install remote desktop
# ****************************************************************************
function Setup_VirtualDesktop() {
    clear >$(tty)
    printf "\n **** Install virtual desktop **** \n"

    # Check if MATE desktop is installed
    MATE_INSTALLED="N"
    if [ -f /usr/bin/mate-session ]; then
        MATE_INSTALLED="Y"
    else
        printf "\n WARNING: mate desktop NOT installed\n"
        printf " Only ETX server installation is available without desktop\n\n"
    fi

    while [[ true ]]; do
        CONFIG_CHANGED=false

        # main menu
        printf "\n o Virtual desktop menu\n"
        
        if [[ $MATE_INSTALLED == "Y" ]]; then
            # Full menu when MATE desktop is installed
            printf   "   1. RealVNC virtual desktop\n"
            printf   "   2. xrdp\n"
            printf   "   3. ETX server\n"
            printf   "   4. ETX connection node\n"
            printf   "   0. Exit\n\n"
        else
            # Limited menu when MATE desktop is not installed
            printf   "   3. ETX server\n"
            printf   "   0. Exit\n\n"
        fi

        DEFAULT_ACTION="0"

        printf   "%55s %4s : " ">>> Your choice" "[$DEFAULT_ACTION]" 
        read INPUT
        INPUT=${INPUT:-$DEFAULT_ACTION}

        case "$INPUT" in
            "1")
                if [[ $MATE_INSTALLED == "Y" ]]; then
                    Install_RealVNC
                else
                    printf   "\n **** This option requires MATE desktop to be installed ****\n\n"
                fi
                ;;
            "2")
                if [[ $MATE_INSTALLED == "Y" ]]; then
                    Install_xrdp
                else
                    printf   "\n **** This option requires MATE desktop to be installed ****\n\n"
                fi
                ;;
            "3")
                Install_ETX_Server;;
            "4")
                if [[ $MATE_INSTALLED == "Y" ]]; then
                    Install_ETX_Node
                else
                    printf   "\n **** This option requires MATE desktop to be installed ****\n\n"
                fi
                ;;
            "0")
                break;;
            *)
                printf   "\n **** Invalid option ****\n\n";;
        esac
    done
}



# ****************************************************************************
# Update network interface settings
# ****************************************************************************
function Update_NIC() {

    printf "\n o Update local networks\n"

    printf   "   - Check grub to enable interface name change\n"
    ifname_change=$(grep "net.ifnames=0" /etc/default/grub)
    if [[ $ifname_change == "" ]]; then
        CMDLINE=$(awk -F'"' '/^GRUB_CMDLINE_LINUX/{print $2}' /etc/default/grub)
        sudo sed -i "s^$CMDLINE^$CMDLINE net.ifnames=0^g" /etc/default/grub
        sudo grub2-mkconfig  -o /boot/grub2/grub.cfg
        printf "     > Updated\n"
        printf "\n    *** A reboot is required ***\n\n"
        if Ask_Confirm ">>> Do you want to reboot now?" "N"; then
            sudo reboot
        else 
            return 1
        fi
    else
        printf "     > Already enabled\n"
    fi

    printf "\n   - Scan local networks\n"
    # get default interface name
    DEFAULT_IF=$(sudo ip -o -4 ro show to default | grep -o "dev.*" | awk '{print $2}')
    printf "     %-2s %-8s %-15s %-12s %-4s %-7s\n" "ID" "Name" "Address" "Gateway" "MTU" "DEFAULT"
    printf "     %-2s %-8s %-15s %-12s %-4s %-7s\n" "==" "========" "===============" "============" "====" "======="
    # scan local interfaces
    IF_INDX=0
    metric_min=255
    IFS=":"
    while read -r nic reminder; do
        UPDATE_IF[$IF_INDX]="N"
        NIC_NAME[$IF_INDX]=$nic
        IF_INDX=$((IF_INDX + 1))
    done < <(sudo nmcli -t -f DEVICE,TYPE,STATE device | grep ethernet)

    IF_INDX=0
    metric_min=255
    IFS=" "
    for nic in "${NIC_NAME[@]}"; do
        while read -r item value reminder; do
            NIC_CIDR[$IF_INDX]="24"     #default value
            case $item in
                "GENERAL.HWADDR:")
                    NIC_MAC[$IF_INDX]=$value ;;
                "IP4.ADDRESS[1]:")
                    NIC_IP[$IF_INDX]=${value%/*}
                    NIC_CIDR[$IF_INDX]=${value#*/} ;;
                "IP4.GATEWAY:")    
                    NIC_GW[$IF_INDX]=$value ;;
                "GENERAL.MTU:")
                    NIC_MTU[$IF_INDX]=$value ;; 
                "IP4.DNS[1]:")
                    NIC_DNS1[$IF_INDX]=$value ;;
                "IP4.SEARCHES[1]:")
                    NIC_DOMAIN[$IF_INDX]=$value ;;                       
            esac
        done < <(sudo nmcli device show $nic)
        if [[ $nic == $DEFAULT_IF ]]; then
            DEFAULTIF_ID=$IF_INDX
            DEFAULT_ROUTE[$DEFAULTIF_ID]="Y"
            printf "     %-2s %-8s %-15s %-12s %-4s %-4s\n" "$IF_INDX" "${NIC_NAME[$IF_INDX]}" "${NIC_IP[$IF_INDX]}/${NIC_CIDR[$IF_INDX]}" "${NIC_GW[$IF_INDX]}" "${NIC_MTU[$IF_INDX]}" "Y"
        else
            printf "     %-2s %-8s %-15s %-12s %-4s %-4s\n" "$IF_INDX" "${NIC_NAME[$IF_INDX]}" "${NIC_IP[$IF_INDX]}/${NIC_CIDR[$IF_INDX]}" "${NIC_GW[$IF_INDX]}" "${NIC_MTU[$IF_INDX]}" "-"
        fi        
        IF_INDX=$((IF_INDX + 1))
    done

    # get current dns settings
    i=0
    while read -r cur_dns reminder; do
        local_dns[$i]=$cur_dns
        i=$((i+1))
    done < <(sudo cat /etc/resolv.conf | grep -o "nameserver.*" | awk '{print $2}')



    ## update network interface
    while [[ true ]]; do
        echo ""
        UPDATE_INTERFACE="N"
        for ((i=0; i<$IF_INDX; i++)) do
            UPDATE_IF[$i]=${UPDATE_IF[$i]:="N"}
            if Inquiry "    - Update interface [$i] - ${NIC_NAME[$i]}" ${UPDATE_IF[$i]}; then
                UPDATE_IF[$i]="Y"
                UPDATE_INTERFACE="Y"
                NIC_NEWNAME[$i]=${NIC_NEWNAME[$i]:="eth$i"}
                printf "%-49s %10s : " "      > New name" "[${NIC_NEWNAME[$i]}]"
                read INPUT
                NIC_NEWNAME[$i]=${INPUT:=${NIC_NEWNAME[$i]}}   

                if Inquiry "      > Use fixed IP (${NIC_IP[$i]} / ${NIC_CIDR[$i]}) " ${FIXED_IP[i]}; then 
                    while [[ true ]]; do
                        if [[ ${NIC_CIDR[$i]} != 24 ]] || [[ ${NIC_IP[$i]} == "" ]]; then  
                            Read_IP "       ~ IP address" "${NIC_IP[$i]}"
                            NIC_IP[$i]=$READ_VALUE

                            Read_IP "       ~ Gateway"     "${NIC_GW[$i]}" 
                            NIC_GW[$i]=$READ_VALUE
                        else
                            Read_IP24 "       ~ IP address " ${NIC_IP[$i]}
                            NIC_IP[$i]=$READ_VALUE

                            Read_IP24 "       ~ Gateway " ${NIC_GW[$i]}
                            NIC_GW[$i]=$READ_VALUE
                        fi

                        if [[ ${NIC_IP[$i]} == ${NIC_GW[$i]} ]]; then
                            printf "\n **** Error! Interface IP can not be same as gateway IP **** \n\n"
                            continue
                        else
                            break
                        fi
                    done

                    FIXED_IP[$i]="Y"
                else
                    FIXED_IP[$i]="N"
                fi

                Read_Number "      > MTU" ${NIC_MTU[$i]} 1000 9000
                NIC_MTU[$i]=$READ_VALUE

                if Inquiry "      > Use as default route" "${DEFAULT_ROUTE[$i]}"; then
                    DEFAULT_ROUTE[$i]="Y"
                    DEFAULT_IP=${NIC_IP[$i]}
                else
                    DEFAULT_ROUTE[$i]="N"
                fi
            else
                NIC_NEWNAME[$i]=${NIC_NAME[$i]}
            fi
            echo ""
        done

        if [[ $UPDATE_INTERFACE == "Y" ]]; then
            i=0
            USE_GW_AS_DNS=${USE_GW_AS_DNS:-"Y"}
            if Inquiry "    - Use gateway as default DNS?" $USE_GW_AS_DNS; then
                USE_GW_AS_DNS="Y"
            else
                for ((i=0; i<4; i++)) do
                    Read_IP "      > Name server [$i]" "${local_dns[$i]}" "Y"
                        if [[ $READ_VALUE == "" ]]; then
                            local_dns[$i]=""
                            break
                        else
                            local_dns[$i]=$READ_VALUE
                        fi
                done
                USE_GW_AS_DNS="N"
            fi
        fi

        # get user confirmation
        echo ""
        if  Ask_Confirm "   >>> Do you confirm?" "N"; then
            break
        else
            if  Ask_Confirm "   >>> Return to main menu?" "N"; then
                return 1
            fi
        fi  
    done

    for ((i=0; i<$IF_INDX; i++)) do
        if [[ ${UPDATE_IF[$i]} == "N" ]]; then continue; fi

        # udpate interface name
        nic=${NIC_NAME[$i]} 
        new_nic=${NIC_NEWNAME[$i]}    
        new_nic_file="/etc/sysconfig/network-scripts/ifcfg-$new_nic"
        printf "\n  o Update interface [%s]\n" "$new_nic"
        printf   "    -----------------------------------------\n" 
        if sudo test -f /etc/sysconfig/network-scripts/ifcfg-$nic; then
            sudo mv /etc/sysconfig/network-scripts/ifcfg-$nic /var/log/ifcfg-$nic.backup
        fi

        if [[ ${DEFAULT_ROUTE[$i]} == "Y" ]]; then
            DEFROUTE="yes"
        else
            DEFROUTE="no"
        fi 

        nic_uuid=$(uuidgen)
        echo "# Generated by Creekside Networks LLC #
NAME=$new_nic
DEVICE=$new_nic
HWADDR=${NIC_MAC[$i]}
UUID=$nic_uuid
TYPE=Ethernet
IPV4_FAILURE_FATAL=no
IPV6INIT=no
ONBOOT=yes
DEFROUTE=$DEFROUTE
MTU=${NIC_MTU[$i]}" | sudo tee $new_nic_file

        if [[ ${FIXED_IP[$i]} == "Y" ]]; then
            echo "BOOTPROTO=none
IPADDR=${NIC_IP[$i]}
PREFIX=${NIC_CIDR[$i]}
GATEWAY=${NIC_GW[$i]}" | sudo tee -a $new_nic_file
        else
            echo "BOOTPROTO=dhcp" | sudo tee -a $new_nic_file
        fi

        if [[ $USE_GW_AS_DNS == "Y" ]]; then
            echo "DNS1=${NIC_GW[$i]}"  | sudo tee -a $new_nic_file
        else
            for ((k=0; k<4; k++)) do
                if [[ ${local_dns[$k]} != "" ]]; then 
                    echo "DNS$((k+1))=${local_dns[$k]}"  | sudo tee -a $new_nic_file
                else
                    break
                fi
            done
        fi


        REBOOT="Y"
    done

    if [[ $REBOOT == "Y" ]]; then
        # sudo systemctl disable NetworkManager
        printf "\n    *** A reboot is required ***\n\n"
        if Ask_Confirm ">>> Do you want to reboot now?" "N"; then
            sudo reboot
        fi
    fi

    printf   "\n **** All done, thank you ****\n\n"

}

# ****************************************************************************
# Setup Active Domain
# ****************************************************************************
function Join_ActiveDomain() {
    ad_package_list=("sssd" "realmd" "oddjob" "oddjob-mkhomedir" \
        "adcli" "samba-common" "samba-common-tools" "krb5-workstation" \
        "openldap-clients" "autofs" "zsh" "ksh" "tcsh")
    ACCESS_CONF_FILE="/etc/security/access.conf"
    SUDO_CONF_FILE="/etc/sudoers.d/adsudoers"
    PERMENENT_ACCESS_GRPS=("root" "domain admins")
    PERMENENT_SUDOER_GRPS=("domain admins")

    printf "\n  o Install AD client packages\n"

    for pacakge in ${ad_package_list[@]}; do
        Install_Single_CentOS_Package $pacakge
    done

    CURRHOSTNAME=$(hostname)
    CURRHOSTNAME=${CURRHOSTNAME%%.*}
    NEWHOSTNAME=${NEWHOSTNAME:=$CURRHOSTNAME}

    while [[ true ]]; do

        printf "\n  o Check if already joined\n"
        EXIST_DOMAIN=$(realm list | grep domain-name | cut -d ':' -f 2 | xargs)

        if [[ $EXIST_DOMAIN != "" ]]; then
            printf "    *** This computer has already joined [$EXIST_DOMAIN]\n"
            break
        fi

        printf "\n  o Information required to join new domain\n"
        Read_Domain "    - Domain name" "$DOMAIN"
        DOMAIN=$READ_VALUE

        if [[ $(sudo realm discover $DOMAIN | grep domain-name | cut -d ':' -f 2 | xargs) == "" ]]; then 
            printf "\n    ***  Active domain [$DOMAIN] not found ***\n\n"
            continue
        fi

        Read_Hostname "    - Hostname" "$NEWHOSTNAME"

        if [[ $READ_VALUE != ${READ_VALUE/.} ]]; then
            NEWHOSTNAME=${READ_VALUE%%.*}
        else
            NEWHOSTNAME=$READ_VALUE
        fi

        Read_String "    - Admin user id" "$DC_ADMIN"  3 32
        DC_ADMIN=$READ_VALUE

        Read_String "    - Admin password" "$DC_ADMIN_PASS"  3 64
        DC_ADMIN_PASS=$READ_VALUE

        printf "\n  o Default shell\n"   
    
        SHELLS=("/usr/bin/bash" "/usr/bin/csh" "/usr/bin/ksh" "/usr/bin/zsh")
        SimpleMenu ${SHELLS[@]}
        SHELL=${SHELLS[$MENU_CHOICE]}

        # get user confirmation
	    echo ""
	    if  ! Ask_Confirm "   >>> Do you confirm?" "N"; then
            if  Ask_Confirm "   >>> Return to main menu?" "N"; then
                return 1
            else 
                continue
            fi
	    fi  

        # Update host records

        DEFAULT_NIC=$(sudo ip route show | grep default | grep -o 'dev.*' | awk '{print $2}')
        MY_IP=$(sudo ip -4 addres show $DEFAULT_NIC | grep -o 'inet.*' | awk '{print $2}')
        MY_IP=${MY_IP%%/*}

        printf "\n  o Update host records for $NEWHOSTNAME.$DOMAIN\n"
        sudo hostnamectl set-hostname $NEWHOSTNAME.$DOMAIN
        Update_Hosts_File "$MY_IP" "$NEWHOSTNAME" "$DOMAIN"

        DeleteLines $MY_IP /etc/hosts
        DeleteLines $NEWHOSTNAME /etc/hosts
        echo "$MY_IP $NEWHOSTNAME.$DOMAIN $NEWHOSTNAME" | sudo tee -a /etc/hosts &> /dev/null

        # Now join freeIPA
        printf "\n  o Join Active Directory [$DOMAIN]\n\n"

        echo $DC_ADMIN_PASS | sudo realm join -U $DC_ADMIN $DOMAIN

        if [ $? -ne 0 ]; then
            printf "\n    ***  Failed to join [$DOMAIN] ***\n\n"
            continue
        fi

        printf "\n  o Update SSSD to use default AD domain\n"
        Update_Conf "use_fully_qualified_names" "False" /etc/sssd/sssd.conf 
        Update_Conf "fallback_homedir" "/home/%u" /etc/sssd/sssd.conf
        Update_Conf "ad_gpo_access_control" "disabled" /etc/sssd/sssd.conf
        Update_Conf "ad_gpo_map_remote_interactive" "+xrdp-sesman" /etc/sssd/sssd.conf
        Update_Conf "default_shell" "$SHELL" /etc/sssd/sssd.conf 
    
        # clean sssd cache
        sudo systemctl stop sssd
        sudo rm -rf /var/lib/sss/db/*
        sudo systemctl start sssd

        printf   "\n **** Successful joined $DOMAIN ****\n\n"
        break

    done

    while [[ true ]]; do

        # get current access group list
        IFS=$'\n'; current=( $(cat $ACCESS_CONF_FILE | grep -e "^+.*" | awk -F : '{print $2}'  | cut -d "@" -f 1 ) )
        printf "\n  o Add/remove allowed user groups ["x" to remove, "-" to end]\n"        
        index="0"
        access_groups=()
        while [[ true ]]; do
            if [[ $index < ${#current[@]} ]]; then
                # bypass permanent groups
                if SearchArray "${current[$index]}" PERMENENT_ACCESS_GRPS; then
                    printf "%-60s : %s\n" "      $index. Permanet user group" "${current[$index]}" 
                    index=$((index+1))
                    continue
                fi 

                Read_String "      $index. Existing user group" "${current[$index]}"  "1" "32"
            else
                Read_String "      $index. New user group" "-"  "1" "32"
            fi
            
            if [[ $READ_VALUE == "-" ]]; then 
                break; 
            elif [[ $READ_VALUE == "x" ]]; then 
                printf "         *** ${current[$index]} will be removed from the access list\n"
                index=$((index+1))
                continue
            elif [[ " ${access_groups[@]} " =~ " ${READ_VALUE} " ]]; then
                printf "         *** This group already in the access list\n\n"
                continue
            elif ! Check_Usergroup $READ_VALUE; then 
                printf "         *** User group $USER_GRP does not exist\n\n"
                continue
            else
                access_groups+=("$READ_VALUE")
                index=$((index+1))
            fi
        done

        # get current access group list
        printf "\n  o Add/remove sudo user groups ["x" to remove, "-" to end]\n"        
        if [ -f $SUDO_CONF_FILE ]; then
            IFS=$'\n'; current=( $(cat $SUDO_CONF_FILE | grep -e "^%.*" | awk '{sub(/ALL.*/,x)}1' | sed -e 's#^%##; s#\\##; s/[[:space:]]*$//' ))
        else
            current=()
        fi

        index="0"
        while [[ true ]]; do
            if [[ $index < ${#current[@]} ]]; then
                # bypass permanent groups
                if SearchArray "${current[$index]}" PERMENENT_SUDOER_GRPS; then
                    printf "%-60s : %s\n" "      $index. Permanet sudo group" "${current[$index]}" 
                    index=$((index+1))
                    continue
                fi 
                Read_String "      $index. Existing sudoer group" "${current[$index]}"  "1" "32"
            else
                Read_String "      $index. New sudoer group" "-"  "1" "32"
            fi
            
            if [[ $READ_VALUE == "-" ]]; then 
                break; 
            elif [[ $READ_VALUE == "x" ]]; then 
                printf "         *** ${current[$index]} will be removed from the sudoers list\n"
                index=$((index+1))
                continue
            elif [[ " ${sudoer_groups[@]} " =~ " ${READ_VALUE} " ]]; then
                printf "        *** This group already in the sudoers list\n\n"
                continue
            elif ! Check_Usergroup $READ_VALUE; then 
                printf "        *** User group $USER_GRP does not exist\n\n"
                continue
            else
                sudoer_groups+=("$READ_VALUE")
                index=$((index+1))
            fi

            if [[ ! " ${access_groups[@]} " =~ " ${READ_VALUE} " ]]; then
                printf "        *** Add this group to access list\n"
                access_groups+=("${READ_VALUE}")
            fi
        done

        printf "\n  o Summary\n"
        printf "    - Access groups\n"
        index="0"
        for group in ${PERMENENT_ACCESS_GRPS[@]}; do
            printf "      $index. $group\n"
            index=$((index+1))
        done  
        for group in ${access_groups[@]}; do
            printf "      $index. $group\n"
            index=$((index+1))
        done  

        printf "    - Sudoers groups\n"
        index="0"
        for group in ${PERMENENT_SUDOER_GRPS[@]}; do
            printf "      $index. $group\n"
            index=$((index+1))
        done 
        for group in ${sudoer_groups[@]}; do
            printf "      $index. $group\n"
            index=$((index+1))
        done  

        # get user confirmation
	    echo ""
	    if Ask_Confirm "   >>> Do you confirm?" "N"; then
            break
        else
            if  Ask_Confirm "   >>> Return to main menu?" "N"; then
                return 1
            else 
                continue
            fi
	    fi  

    done

    TS=$(date +"%Y-%m-%d %T")

    printf "\n  o Update access conf file [$ACCESS_CONF_FILE]\n"
    echo "# This configuraion was generated by Creekside Networks on $TS" | sudo tee $ACCESS_CONF_FILE #&> /dev/null
    for group in ${PERMENENT_ACCESS_GRPS[@]}; do
        printf "+:${group}:ALL\n" | sudo tee -a $ACCESS_CONF_FILE #&> /dev/null
    done
    for group in ${access_groups[@]}; do
        printf "+:${group}:ALL\n" | sudo tee -a $ACCESS_CONF_FILE #&> /dev/null
    done
    echo "-:ALL:ALL" | sudo tee -a $ACCESS_CONF_FILE #&> /dev/null

    printf "\n  o Update sudoers conf file [$ACCESS_CONF_FILE]\n"
    echo "# This configuraion was generated by Creekside Networks on $TS"  | sudo tee $SUDO_CONF_FILE #&> /dev/null
    for group in ${PERMENENT_SUDOER_GRPS[@]}; do
        printf "%%%-40s ALL=(ALL)   NOPASSWD: ALL\n"  ${group// /\\ }  | sudo tee -a $SUDO_CONF_FILE #&> /dev/null
    done
    for group in ${sudoer_groups[@]}; do
        printf "%%%-40s ALL=(ALL)   NOPASSWD: ALL\n"  ${group// /\\ }  | sudo tee -a $SUDO_CONF_FILE #&> /dev/nul
    done

    return 0


}


# ****************************************************************************
# Install FreeIPA or FreeIPA replica server
# Usage:
#      Install_FreeIPA 
# ****************************************************************************

function Install_FreeIPA_Server() {

    if [[ $1 == "R" ]]; then
        printf "\n *** Install replica freeIPA & freeRadius server ***\n"
        FREEIPA_OPTION="REPLICA"
    else
        printf "\n *** Install standalone freeIPA & freeRadius server ***\n"
        FREEIPA_OPTION="STANDALONE"
    fi

    DEFAULT_NIC=$(sudo ip route show | grep default | grep -o 'dev.*' | awk '{print $2}')
    LOCAL_IP=$(sudo ip -4 addres show $DEFAULT_NIC | grep -o 'inet.*' | awk '{print $2}')
    LOCAL_IP=${LOCAL_IP%%/*}

    while [[ true ]]; do
        # Get hostname first
        Read_Hostname  "   - Local Hostname" $HOSTNAME
        LOCAL_HOSTNAME=$READ_VALUE

        # Check if hostname contain domain information
        if [[ $LOCAL_HOSTNAME != ${LOCAL_HOSTNAME/.} ]]; then
            IPA_DOMAIN=$(echo $LOCAL_HOSTNAME | cut -d '.' -f2-)
            LOCAL_HOSTNAME=$(echo $LOCAL_HOSTNAME | cut -d . -f 1)
        fi

        #Confirm domain name
        Read_Domain "   - IPA Domain name" $IPA_DOMAIN
        IPA_DOMAIN=$READ_VALUE

        Read_String "   - Directory Manager's Password" "Good2Great+" 3 16 
        IPA_DM_PASS=$READ_VALUE

        Read_String "   - Admin's Password" "Good2Great"  3 16
        IPA_ADMIN_PASS=$READ_VALUE

        Read_String "   - Freeradius client secret" "Good2Great"  3 16
        RADIUS_CLIENT_SECRET=$READ_VALUE

        if  Ask_Confirm "   >>> Do you confirm?"; then
            break
        else 
            if  Ask_Confirm "   >>> Return to main menu?" "Y"; then
                return 1
            fi
        fi
    done
	
    printf "\n o Install necessary packages\n"
    freeIPA_packages=("bind" "bind-dyndb-ldap" "ipa-server" "ipa-server-dns" "freeipa-server-trust-ad" "freeradius" "freeradius-ldap" "freeradius-krb5" "freeradius-utils")
    Install_CentOS_Packages "${freeIPA_packages[@]}"

	printf "\n o Update local host names [%s]\n" $LOCAL_HOSTNAME.$IPA_DOMAIN
    sudo  hostnamectl set-hostname $LOCAL_HOSTNAME.$IPA_DOMAIN
    Update_Hosts_File "$LOCAL_IP"  "$LOCAL_HOSTNAME" "$IPA_DOMAIN"

    printf "\n o Update firewall\n"
    sudo firewall-cmd -q --permanent --add-service={ntp,dns,freeipa-ldap,freeipa-ldaps,freeipa-replication,freeipa-trust,radius}
    sudo firewall-cmd -q --reload

    if [[ $FREEIPA_OPTION == "STANDALONE" ]]; then
        printf "\n o Install Standalone freeIPA server\n"

        RunCmd "sudo ipa-server-install\
            --ds-password=$IPA_DM_PASS\
            --admin-password=$IPA_ADMIN_PASS\
            --ip-address=$LOCAL_IP \
            --domain=$IPA_DOMAIN\
            --setup-adtrust\
            --realm=${IPA_DOMAIN^^}\
            --hostname=$LOCAL_HOSTNAME.$IPA_DOMAIN \
            --setup-dns\
            --mkhomedir \
            --allow-zone-overlap  \
            --auto-reverse \
            --auto-forwarders \
            --unattended"
    else
#        if [[ $IPA_ENABLED == "N" ]]; then
#            printf "\n o Join freeIPA domain [$IPA_DOMAIN]\n"
#
#            RunCmd "sudo ipa-client-install -p admin -w $IPA_ADMIN_PASS -U"
#        fi

        printf "\n o Add [$LOCAL_HOSTNAME] to ipaservers group \n"
        echo "$IPA_ADMIN_PASS" | sudo kinit admin
        if [ $? -ne 0 ]; then 
            printf "Incorrent IPA admin password! return to main menu"
            return 0
        fi

        sudo ipa hostgroup-add-member ipaservers --hosts $LOCAL_HOSTNAME.$IPA_DOMAIN

        printf "\n o Install replica freeIPA server \n"
        RunCmd "sudo ipa-replica-install\
            --setup-adtrust\
            --setup-ca\
            --setup-dns\
            --mkhomedir \
            --allow-zone-overlap  \
            --auto-reverse \
            --auto-forwarders \
            --unattended"
    fi

	printf "\n o Setup freeradius\n"
    CREEKSIDE_CFG_DIR="/etc/creekside"
    RADIUS_IPA_LDAP_CFG=$CREEKSIDE_CFG_DIR/radius/radius-ldap.cfg
    RADIUS_DEFAULT_CFG=$CREEKSIDE_CFG_DIR/radius/radius-default.cfg
    RADIUS_LOCAL_USERS=$CREEKSIDE_CFG_DIR/radius/radius-users
    RADIUS_CLIENTS_CONF=$CREEKSIDE_CFG_DIR/radius/radius-clients.conf
    RADIUS_EAP_CFG=$CREEKSIDE_CFG_DIR/radius/mods-eap.conf

	printf   "   - Create default certs\n"

    sudo bash /etc/raddb/certs/bootstrap

	printf   "   - freeIPA LDAP authentication\n"
    # create creekside radius directory
    sudo mkdir -p $CREEKSIDE_CFG_DIR/radius
	# copy ldap template file & link to freeradius working directory
	sudo cp /etc/raddb/mods-available/ldap $RADIUS_IPA_LDAP_CFG
	sudo ln -fs $RADIUS_IPA_LDAP_CFG /etc/raddb/mods-enabled/
	
	# update server
	#printf "     > Add IPA server [$LOCAL_IP]\n"
	#search_line="server = 'localhost'"
	#echo $search_line
	#sudo sed -i "s/$search_line/$search_line\n\tserver = $IPA_SERVER_IP/g" $RADIUS_IPA_LDAP_CFG
	
	printf "     > Update IPA authentication credentials\n"
	
	search_line=$(sudo cat $RADIUS_IPA_LDAP_CFG | grep "identity = 'cn=admin,dc=example,dc=org'")
	new_line="identity = 'cn=Directory Manager'"
	sudo sed -i "s/$search_line/\t$new_line/g" $RADIUS_IPA_LDAP_CFG
	
	search_line=$(sudo cat $RADIUS_IPA_LDAP_CFG | grep "password = mypass")
	new_line="password = '$IPA_DM_PASS'"
	sudo sed -i "s/$search_line/\t$new_line/g" $RADIUS_IPA_LDAP_CFG
	
	# split IPA domain name 
	ipa_dc_name=$IPA_DOMAIN
	ipa_dc_0=${ipa_dc_name##*.}
	ipa_dc_name=${ipa_dc_name%.*}
	ipa_dc_1=${ipa_dc_name##*.}

	printf "     > Update base dn to [cn=accounts,dc=$ipa_dc_1,dc=$ipa_dc_0]\n"	
	basedn="base_dn = 'cn=accounts,dc=$ipa_dc_1,dc=$ipa_dc_0'"
	search_line="base_dn = 'dc=example,dc=org'"
	sudo sed -i "s/$search_line/$basedn/g" $RADIUS_IPA_LDAP_CFG
	
	# user ipaHash for password authentication
	printf "     > Use ipaNTHash for password authentication\n"
	search_line=$(sudo cat $RADIUS_IPA_LDAP_CFG | grep "control:NT-Password")
	sudo sed -i "s/$search_line/\t\tcontrol:NT-Password\t\t:= 'ipaNTHash'/g" $RADIUS_IPA_LDAP_CFG
	
	printf "     > Add 'memeberOf' to radius dictionary\n"
	search_line=$(sudo cat /etc/raddb/dictionary | grep "memberOf")
	if [[ $search_line == "" ]]; then
	    echo -e "ATTRIBUTE\tmemberOf\t\t3101\tstring" | sudo tee -a /etc/raddb/dictionary &> /dev/null
	fi
	
	printf "     > Add reply message with class-group\n"
	search_line=$(sudo cat $RADIUS_IPA_LDAP_CFG | grep "reply:Tunnel-Private-Group-ID")
	sudo sed -i "s/$search_line/\t\treply:memberOf                  += 'memberOf'/g" $RADIUS_IPA_LDAP_CFG
	
	# update default sites config with return of group membership
    printf "     > Update default sites\n"
	sudo cp /etc/raddb/sites-available/default  $RADIUS_DEFAULT_CFG
	sudo sed -i 's#post-auth {#post-auth {\n\tforeach \&reply:memberOf {\n\t\tif (\"%{Foreach-Variable-0}\" =~ /cn=groups/i) {\n\t\t\tif (\"%{Foreach-Variable-0}\" =~ /cn=([^,=]+)/i) {\n\t\t\t\tupdate reply {\n\t\t\t\t\tClass += "%{1}"\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}#g' $RADIUS_DEFAULT_CFG
	sudo ln -fs $RADIUS_DEFAULT_CFG /etc/raddb/sites-enabled/default

    # change eap default type to mschapv2
    printf "     > Update eap auth-type to mschapv2\n"
    sudo cp /etc/raddb/mods-available/eap  $RADIUS_EAP_CFG
    sudo sed -i '0,/default_eap_type = md5/s//default_eap_type = mschapv2/' $RADIUS_EAP_CFG
    sudo ln -fs $RADIUS_EAP_CFG /etc/raddb/mods-enabled/eap

	#..............................................................................
	# Create freeradius client configuration file
	#..............................................................................
	printf "   - Radius Client configure [$RADIUS_CLIENTS_CONF]\n"
	echo -e "# Freeradius clients (by Creekside Networks LLC)
client localnet {
        ipaddr = 0.0.0.0/0
        proto = *
        secret = $RADIUS_CLIENT_SECRET
        nas_type = other                 
        limit {
               max_connections = 16
               lifetime = 0
               idle_timeout = 30
        }
}

client localhost {
        ipaddr = 127.0.0.1
        proto = *
        secret = $RADIUS_CLIENT_SECRET
        nas_type = other           
        limit {
               max_connections = 16
               lifetime = 0
               idle_timeout = 30
        }
}"              | sudo tee $RADIUS_CLIENTS_CONF  &> /dev/null

	if ! sudo test -f /etc/raddb/clients.conf.orig; then
	    # backup original local user authentication file
	    sudo mv /etc/raddb/clients.conf /etc/raddb/clients.conf.orig
	fi
	sudo ln -fs $RADIUS_CLIENTS_CONF /etc/raddb/clients.conf

	printf "\n o Start freeradius services\n"
	sudo systemctl -q enable radiusd 
	sudo systemctl -q restart radiusd 

    printf "\n *** FreeIPA / Freeradius installation done ****\n\n"

    return 0
}

# ****************************************************************************
# Setup freeIPA client
# Usage:
#      Join_FreeIPA
# ****************************************************************************
function Join_FreeIPA() {

    printf "\n *** Join freeIPA domain ***\n"

    # Collect system configuration options
    LOCAL_HOSTNAME=$(hostname)
    IPA_HOSTNAME=${IPA_HOSTNAME:="ipa"}
    DEFAULT_NIC=$(sudo ip route show | grep default | grep -o 'dev.*' | awk '{print $2}')
    DEFAULT_IP=$(sudo ip -4 addres show $DEFAULT_NIC | grep -o 'inet.*' | awk '{print $2}')
    DEFAULT_IP=${DEFAULT_IP%%/*}

    IPA_ADMIN=${IPA_ADMIN:="admin"}

    while [[ true ]]; do
        printf "\n o Collect configuration options\n"

        printf "\n   - Local host\n"
        printf "%-20s %39s : " "     > Hostname" "[$LOCAL_HOSTNAME]"
        read INPUT
        LOCAL_HOSTNAME=${INPUT:-$LOCAL_HOSTNAME}
        if [[ $LOCAL_HOSTNAME != ${LOCAL_HOSTNAME/.} ]]; then
            IPA_DOMAIN=${LOCAL_HOSTNAME#*.}
            LOCAL_HOSTNAME=${LOCAL_HOSTNAME%%.*}
        fi

        printf "%-20s %39s : \n" "     > IP address" "[$DEFAULT_IP]"        

        printf "\n   - FreeIPA server\n"
        printf "%-20s %39s : " "     > Hostname" "[$IPA_HOSTNAME]"
        read INPUT
        IPA_HOSTNAME=${INPUT:-$IPA_HOSTNAME}
        if [[ $IPA_HOSTNAME != ${IPA_HOSTNAME/.} ]]; then
            IPA_DOMAIN=${IPA_HOSTNAME#*.}
            IPA_HOSTNAME=${IPA_HOSTNAME%%.*}
        fi

        while [[ true ]]; do
            printf "%-20s %39s : " "     > Domain name" "[$IPA_DOMAIN]"
            read INPUT
            INPUT=${INPUT:-$IPA_DOMAIN}

            if [[ $INPUT =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then 
                IPA_DOMAIN=$INPUT
            else
                printf "\n  *** A valid domain (xx.xx) is required! ***\n"
                continue
            fi
            IPA_DNSNAME=$IPA_HOSTNAME.$IPA_DOMAIN

            # try to get IPA address by dns lookup
            IPA_SERVER_IP=$(host -t A -W 15 $IPA_DNSNAME | grep -o "address.*" | awk '{print $2}')
            if [[ $IPA_SERVER_IP == "" ]]; then
                printf "\n  *** Can't resolve \"$IPA_DNSNAME\", fix required ***\n"
                continue
            else
                printf "%-20s %39s : \n" "     > IP address" "[$IPA_SERVER_IP]"
                break
            fi
        done

        printf "\n   - Adminstrator account\n"
        printf "%-25s %34s : " "     > User ID" "[$IPA_ADMIN]"
        read INPUT
        IPA_ADMIN=${INPUT:-$IPA_ADMIN}

        while [[ true ]]; do
            printf "%-25s %34s : " "     > Password" "[$IPA_ADMIN_PASS]"
            read INPUT
            INPUT=${INPUT:-$IPA_ADMIN_PASS}
            if [[ $INPUT == "" ]]; then
                printf "\n  *** $IPA_ADMIN's password is required! ***\n"
                continue;
            else 
                IPA_ADMIN_PASS=${INPUT:-$IPA_ADMIN_PASS}
                break
            fi
        done

        # get user confirmation
	    echo ""
	    if  Ask_Confirm "   >>> Do you confirm?" "N"; then
	        break
        else
        	if  Ask_Confirm "   >>> Return to main menu?" "N"; then
                return 1
            fi
	    fi  
    done

    # Update host records
    printf "\n  o Update host records\n"
    sudo hostnamectl set-hostname $LOCAL_HOSTNAME.$IPA_DOMAIN

    echo     "    - Update $DEFAULT_IP $LOCAL_HOSTNAME.$IPA_DOMAIN $LOCAL_HOSTNAME"
    Update_Hosts_File "$DEFAULT_IP"  "$LOCAL_HOSTNAME" "$IPA_DOMAIN"
    
    echo     "    - Update $IPA_SERVER_IP $IPA_HOSTNAME.$IPA_DOMAIN $IPA_HOSTNAME"
    Update_Hosts_File "$IPA_SERVER_IP"  "$IPA_HOSTNAME" "$IPA_DOMAIN"

    printf "\n  o Install freeipa client packages\n"
    Install_Single_CentOS_Package "ipa-admintools"

    # Now join freeIPA
    printf "\n  o Join freeIPA domain [$IPA_DOMAIN]\n"
    if sudo ipa-client-install --server=$IPA_DNSNAME --domain=$IPA_DOMAIN --hostname=$LOCAL_HOSTNAME.$IPA_DOMAIN \
        --ip-address=$DEFAULT_IP --mkhomedir --force-join  -p $IPA_ADMIN -w $IPA_ADMIN_PASS  --force-ntpd --unattended -q; then
        printf "    - Completed\n"
        return 0
    else
        printf "\n    ***  Failed to join freeIPA domain [$IPA_DOMAIN] ***\n\n"
        return 1
    fi
}

function Domain_Service() {
    clear >$(tty)
    printf "\n **** Domain service **** \n"

    while [[ true ]]; do
        CONFIG_CHANGED=false

        # main menu
        printf "\n o Domain service menu\n"
        printf   "   1. Join Active Domain\n"
        printf   "   2. Join FreeIPA\n"
        printf   "   3. Install standalone FreeIPA server\n"
        printf   "   4. Install replica FreeIPA server\n"
        printf   "   0. Exit\n\n"

        DEFAULT_ACTION="0"

        printf   "%55s %4s : " ">>> Your choice" "[$DEFAULT_ACTION]" 
        read INPUT
        INPUT=${INPUT:-$DEFAULT_ACTION}

        case "$INPUT" in
            "1")
                Join_ActiveDomain;;
            "2")
                Join_FreeIPA;;
            "3")
                Install_FreeIPA_Server;;
            "4")
                Install_FreeIPA_Server "R";;
            "0")
                break;;
            *)
                printf   "\n **** Feature not implemented yet ****\n\n";;
        esac
    done


}

# ****************************************************************************
# Main script
# ****************************************************************************

function main() {
    clear >$(tty)

    # print title and copyright box
    cat <<EOF

 ***********************************************************
 * CentOS/Rocky OS Setup scripts v1.1                      *
 * (c) Jackson Tong / Creekside Networks LLC 2021-2023     *
 * Usage: ssh -t <host> "\$(<centos.sh)"                    *
 ***********************************************************
EOF

    # check os version
    OS_TYPE=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
    OS_TYPE=${OS_TYPE//\"}
    OS_RELEASE=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release)
    OS_RELEASE=${OS_RELEASE//\"}
    OS_VERSION=${OS_RELEASE%.*}

    case "${OS_TYPE} ${OS_VERSION}"  in
        "CentOS Linux 7" | "Rocky Linux 8" | "Rocky Linux 9" | "Oracle Linux Server 8" | "Oracle Linux Server 9"):             
            ;;
        *)
            printf   "\n **** This OS \"${OS_TYPE} ${OS_RELEASE}\" is not supported\n\n"
            exit -1
            ;;
    esac

    # scan local nic
    #DEFAULT_NIC=$(sudo ip -o -4 ro show to default | grep -o "dev.*" | awk '{print $2}')
    #readarray -t LOCAL_IPS <<< "$(sudo ip -4 addr show dev $DEFAULT_NIC | grep -o "inet.*" | awk '{print $2}')"

    #printf "\nOS detected: \"${OS_TYPE} ${OS_RELEASE}\"\n"
    #printf   "default NIC: \"${DEFAULT_NIC}\" - \"${LOCAL_IPS[0]}\"\n\n"

    while [[ true ]]; do
        CONFIG_CHANGED=false

        # main menu
        printf "\n o Main menu\n"
        printf   "   1. Initialization\n"
        printf   "   2. Install Linux desktop\n"
        printf   "   3. Install office applications\n"
        printf   "   4. Update network\n"
        printf   "   5. Domain service\n"
        printf   "   6. Install virtual desktop\n"
        printf   "   7. Install development tools\n"
        printf   "   0. Exit\n\n"

        DEFAULT_ACTION="0"

        printf   "%55s %4s : " ">>> Your choice" "[$DEFAULT_ACTION]" 
        read INPUT
        INPUT=${INPUT:-$DEFAULT_ACTION}

        case "$INPUT" in
            "1")
                OS_Init;;
            "2")
                Install_MateDesktop;;
            "3")
                Install_OfficeApps;;
            "4")
                Update_NIC;;
            "5")
                Domain_Service;;
            "6")
                Setup_VirtualDesktop;;
            "7")
                Install_DevTools;;
            "0")
                break;;
            *)
                printf   "\n **** Feature not implemented yet ****\n\n";;
        esac
    done

    printf   "\n **** All done, thank you ****\n\n"

    exit 0
}

main