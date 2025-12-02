# Rocky Linux Setup Utility

A comprehensive, menu-driven setup and configuration utility for Rocky Linux 8 and 9.

## Features

- **System Initialization**: Complete system setup including timezone, packages, and repositories
- **Mirror Configuration**: Regional mirror selection for faster downloads (US, UK, China, UAE)
- **Desktop Environments**: Install Xfce and MATE desktop environments with common applications
- **Development Tools**: Install compilers, libraries, and development packages
- **Network Configuration**: Configure interfaces, create bond interfaces, set static IPs
- **Domain Enrollment**: Join Active Directory or FreeIPA domains with SSSD configuration

## Requirements

- Rocky Linux 8 or 9
- Root privileges
- Network connectivity (for package installation)

## Installation

Clone or download the script to your Rocky Linux system:

```bash
git clone https://github.com/creeksidenetworks/linux-tools.git
cd linux-tools/setup
chmod +x rocky-setup.sh
```

## Usage

### Local Execution

Run directly on the target system:

```bash
sudo ./rocky-setup.sh
```

### Remote Execution

Execute on a remote host via SSH (useful for fresh installations):

```bash
ssh -t root@<hostname> "$(<./rocky-setup.sh)"
```

Or with a specific IP:

```bash
ssh -t 10.81.40.56 "$(<./rocky-setup.sh)"
```

> **Note**: The `-t` flag allocates a pseudo-terminal, which is required for interactive menus.

## Main Menu Options

### 1. Initialization

Performs complete system initialization:

- Detects geographic location via IP geolocation
- Configures timezone
- Sets up yum proxy (optional)
- Installs and configures EPEL repository
- Enables RPM Fusion (free and non-free) repositories
- Configures regional mirror URLs
- Disables SELinux
- Sets hostname (optional)
- Installs essential packages:
  - Shells: zsh, ksh, tcsh
  - Utilities: vim, nano, htop, tree, jq, wget, curl
  - Network tools: bind-utils, tcpdump, net-tools, traceroute, mtr
  - File sharing: nfs-utils, cifs-utils, samba-client, autofs
  - Archive tools: tar, zip, unzip, p7zip
  - Domain tools: sssd, realmd, adcli, krb5-workstation
- Installs Docker CE with Compose plugin:
  - Uses NJU mirror (`mirrors.nju.edu.cn`) for China servers
  - Includes docker-ce, docker-ce-cli, containerd.io
  - Includes docker-buildx-plugin, docker-compose-plugin
  - Enables and starts Docker service automatically

### 2. Update Yum Mirrors

Update repository mirror URLs based on your region:

| Region | Base Mirror | EPEL Mirror |
|--------|-------------|-------------|
| US | dl.rockylinux.org | dl.fedoraproject.org |
| UK | rockylinux.mirrorservice.org | mirrorservice.org |
| China | mirrors.nju.edu.cn | mirrors.nju.edu.cn |
| UAE | mirror.ourhost.az | mirror.yer.az |

### 3. Install Desktop Environment

Installs desktop environments and applications:

**Desktop Environments:**
- Xfce (lightweight, fast)
- MATE (traditional GNOME 2 experience)

**Applications:**
- Browsers: Firefox, Google Chrome
- Office: LibreOffice
- Media: VLC, GIMP, Ristretto
- Utilities: File Roller, GNOME Calculator, Evince
- Editors: Sublime Text, Pluma
- Terminal: Tilix
- Other: Thunderbird, FileZilla, Transmission, HexChat

### 4. Install Development Tools

Installs development packages:

- **Build Tools**: gcc, make, bison, flex, libtool
- **Debugging**: gdb, strace, ltrace, valgrind
- **Libraries**: OpenSSL, libcurl, libxml2, zlib, ncurses
- **Languages**: Python 3.9, Perl, Java 11 OpenJDK
- **Kernel Development**: kernel-devel, kernel-headers

### 5. Update Network Settings

Network configuration submenu:

#### List Network Interfaces
Displays all interfaces with:
- MAC address
- MTU
- Operational state
- IPv4 address

> Bond slave interfaces are hidden from the list.

#### Configure Existing Interface
- Rename interface
- Set MTU (576-9000)
- Configure DHCP or static IP
- Supports CIDR notation (e.g., `192.168.1.100/24`)
- Auto-detects current IP as default value

#### Create Bond Interface
Create bonded interfaces from multiple physical NICs:

| Mode | Description |
|------|-------------|
| balance-rr | Round-robin load balancing |
| active-backup | Failover (recommended for most cases) |
| balance-xor | XOR hash-based load balancing |
| broadcast | Transmit on all slaves |
| 802.3ad | LACP (requires switch support) |
| balance-tlb | Adaptive transmit load balancing |
| balance-alb | Adaptive load balancing |

### 6. Join AD/FreeIPA Domain

Enroll the system to a directory service:

**Active Directory:**
- Discovers domain via realm
- Joins using realm join
- Configures SSSD with optimized settings:
  - Short usernames (no @domain.com)
  - Home directories at /home/username
  - GPO access control disabled
  - XRDP support enabled
- Configures passwordless sudo for admin groups
- Sets up access control via realm permit

**FreeIPA:**
- Uses ipa-client-install
- Configures home directory creation
- Unattended installation

## Network Configuration Details

### Static IP Configuration

When configuring static IPs:

1. **IP Address**: Enter in standard format (`192.168.1.100`) or CIDR notation (`192.168.1.100/24`)
2. **Netmask**: Auto-calculated from CIDR, or defaults to `255.255.255.0`
3. **Gateway**: Optional - if not specified:
   - DNS configuration is skipped
   - Interface is set as non-default route
4. **DNS**: Primary and secondary DNS servers (only prompted if gateway is set)
5. **Default Route**: Whether to use this interface as the default gateway

### Bond Interface Notes

- Requires at least 2 physical interfaces
- Interfaces already in a bond are excluded from selection
- Configuration files are created in `/etc/sysconfig/network-scripts/`
- Bonding kernel module is loaded automatically
- **Reboot required** to apply changes

## Configuration Files

The script generates/modifies these files:

| File | Purpose |
|------|---------|
| `/etc/yum.conf` | Proxy configuration |
| `/etc/yum.repos.d/*.repo` | Mirror URLs |
| `/etc/selinux/config` | SELinux disabled |
| `/etc/sysconfig/network-scripts/ifcfg-*` | Network interface configs |
| `/etc/sssd/sssd.conf` | SSSD configuration |
| `/etc/sudoers.d/90-ad-groups` | AD group sudo rules |
| `/root/.ssh/authorized_keys` | SSH public keys |
| `/root/.bashrc` | Proxy environment variables |

## SSH Keys

The script automatically adds predefined SSH public keys to `/root/.ssh/authorized_keys` for administrative access.

## Troubleshooting

### Script exits immediately
Ensure you're running as root:
```bash
sudo ./rocky-setup.sh
```

### Menu doesn't display properly via SSH
Use the `-t` flag to allocate a pseudo-terminal:
```bash
ssh -t user@host "$(<./rocky-setup.sh)"
```

### Package installation fails
1. Check network connectivity
2. Verify DNS resolution
3. Try running initialization first to configure mirrors

### Domain join fails
1. Verify DNS resolves the domain
2. Check network connectivity to domain controllers
3. Ensure correct admin credentials
4. Verify time synchronization with domain

### Network changes don't apply
Network configuration changes require a reboot:
```bash
reboot
```

## License

MIT License - Copyright (c) 2021-2025 Jackson Tong / Creekside Networks LLC

## Contributing

Contributions are welcome! Please submit pull requests to:
https://github.com/creeksidenetworks/linux-tools
