
# Pterodactyl Installer for Linux and Windows (via WSL)

This script provides an easy way to install and manage the **Pterodactyl Panel** and **Wings** daemon on both **Linux** (Ubuntu/Debian) and **Windows** (via **WSL** – Windows Subsystem for Linux). It supports the automatic setup of necessary software, Nginx, SSL certificates, Cloudflare DNS, and more.

### Features
- **Cross-platform support**: Automatically detects whether it’s running on Linux or Windows (via WSL).
- **Automated setup** for:
  - **Pterodactyl Panel** installation.
  - **Wings Daemon** installation.
  - **SSL certificates** via Certbot for secure communication.
  - **Nginx** installation and configuration.
- **Version updates**: Option to automatically update both the Pterodactyl Panel and Wings daemon to their latest versions.

### Supported Operating Systems
- **Linux**: Ubuntu and Debian distributions.
- **Windows**: Requires WSL with Ubuntu or Debian installed.

### Prerequisites
- **Linux**: Ubuntu or Debian-based distribution.
- **Windows**: WSL with Ubuntu or Debian installed.

### Installation Steps

#### On Linux (Ubuntu/Debian)
1. Clone the repository:
   ```bash
   bash <(curl -s https://installer.gamepanel.se/install.sh)
   ```
2. Follow the on-screen instructions to install either the **Pterodactyl Panel**, **Wings**

#### On Windows (via WSL)
1. Install **WSL** and a **Linux distribution** (Ubuntu or Debian) from the Microsoft Store.
2. Clone the repository:
   ```bash
   bash <(curl -s https://installer.gamepanel.se/install.sh)
   ```

4. Follow the on-screen instructions to install either the **Pterodactyl Panel**, **Wings**

### Configuration
- **SSL Certificates**: Certbot will be used to generate and configure SSL certificates for the domains/subdomains `panel.yourdomain.com` and `wings.yourdomain.com`.

### Options
The script offers the following options:
1. **Install Pterodactyl Panel**: Installs the latest version of the Pterodactyl Panel.
2. **Install Wings Daemon**: Installs the Wings daemon.
4. **Exit**: Exits the script.

### Troubleshooting
- Ensure that **Docker** is properly installed and running for the Wings installation.
- Verify that **WSL** is properly set up on Windows and that Ubuntu/Debian is installed.
- If you encounter issues with Cloudflare DNS or SSL generation, double-check your API credentials.

### License
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
