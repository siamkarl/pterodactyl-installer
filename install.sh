#!/bin/bash

# ANSI escape sequences for colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
WHITE="\033[97m"

# Function to check if we are running under WSL
is_wsl() {
    if grep -qEi "(microsoft|WSL)" /proc/version &> /dev/null; then
        return 0  # Return true if in WSL
    else
        return 1  # Return false if not in WSL
    fi
}

# Function to install dos2unix if not already installed
install_dos2unix() {
    if ! command -v dos2unix &> /dev/null; then
        echo -e "${CYAN}Installing dos2unix...${RESET}"
        sudo apt update && sudo apt install -y dos2unix
    else
        echo -e "${GREEN}dos2unix is already installed.${RESET}"
    fi
}

# Function to detect the OS and set the package manager accordingly
detect_package_manager() {
    if command -v apt &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    else
        echo -e "${RED}Unsupported package manager. Exiting.${RESET}"
        exit 1
    fi
}

# Function to install packages using the appropriate package manager
install_package() {
    PACKAGE=$1
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        sudo apt update && sudo apt install -y "$PACKAGE"
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        sudo dnf install -y "$PACKAGE"
    elif [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo yum install -y "$PACKAGE"
    fi
}

# If already in WSL, start installation
if is_wsl; then
    echo -e "${CYAN}You are in WSL, starting installation...${RESET}"
    install_dos2unix
else
    echo -e "${RED}Not in WSL. Please run this script inside WSL.${RESET}"
    exit 1
fi

# Check for Ubuntu or any other Linux version and use respective package manager
detect_package_manager

# Function to install Nginx (no Apache2 installation)
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo -e "${CYAN}Installing Nginx...${RESET}"
        install_package "nginx"
        sudo systemctl enable nginx && sudo systemctl start nginx
    else
        echo -e "${GREEN}Nginx is already installed.${RESET}"
    fi
}

# Function to generate SSL using Certbot
generate_ssl() {
    install_package "certbot"
    install_package "python3-certbot-nginx"
    sudo certbot --nginx --agree-tos --redirect --email $CLOUDFLARE_EMAIL -d panel.$DOMAIN -d wings.$DOMAIN
}

# Function to create Cloudflare DNS record
create_cloudflare_dns() {
    local subdomain=$1
    local ip=$(curl -s http://checkip.amazonaws.com)
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
         -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
         -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
         -H "Content-Type: application/json" \
         --data '{"type":"A","name":"'$subdomain.$DOMAIN'","content":"'$ip'","ttl":120,"proxied":true}'
}

# Function to generate a random password
generate_random_password() {
    # Generate a random password with 16 characters
    echo $(openssl rand -base64 16)
}

# Function to install Pterodactyl Panel
install_panel() {
    install_nginx
    echo -e "${CYAN}Installing Pterodactyl Panel...${RESET}"
    sudo apt update && sudo apt upgrade -y
    install_package "mariadb-server"
    install_package "unzip"
    install_package "curl"
    install_package "tar"
    install_package "composer"
    install_package "redis-server"
    install_package "php"
    install_package "php-cli"
    install_package "php-mbstring"
    install_package "php-xml"
    install_package "php-bcmath"
    install_package "php-curl"
    install_package "php-zip"
    install_package "php-gd"
    install_package "php-fpm"
    install_package "php-tokenizer"
    install_package "php-mysql"

    curl -Lo /var/www/pterodactyl/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
    tar -xzvf panel.tar.gz
    cp .env.example .env
    chmod -R 755 /var/www/pterodactyl
    chown -R www-data:www-data /var/www/pterodactyl
    composer install --no-dev --optimize-autoloader
    php artisan key:generate --force

    echo -e "${CYAN}Generating random database password for user 'pterodactyl'...${RESET}"
    DB_PASSWORD=$(generate_random_password)

    echo -e "${YELLOW}Configuring the database...${RESET}"
    DB_USER="pterodactyl"
    DB_NAME="panel"
    
    mysql -u root -e "CREATE DATABASE $DB_NAME; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

    echo -e "${GREEN}Database user: $DB_USER"
    echo -e "${GREEN}Database password: $DB_PASSWORD"
    echo -e "${GREEN}Database name: $DB_NAME${RESET}"

    php artisan migrate --force
    php artisan db:seed --force
    php artisan storage:link
    create_cloudflare_dns "panel"
    generate_ssl
    echo -e "${GREEN}Panel is installed and SSL is configured!${RESET}"
    sudo systemctl restart nginx
}

# Function to install Wings
install_wings() {
    install_nginx
    echo -e "${CYAN}Installing Wings...${RESET}"
    sudo apt update && sudo apt upgrade -y
    install_package "curl"
    install_package "tar"
    install_package "unzip"
    install_package "git"
    install_package "redis-server"
    install_package "docker.io"
    
    systemctl enable --now docker
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    create_cloudflare_dns "wings"
    generate_ssl
    echo -e "${GREEN}Wings is installed and SSL is configured!${RESET}"
}

# Function to update all
update_all() {
    echo -e "${CYAN}Updating everything to the latest version...${RESET}"
    sudo apt update && sudo apt upgrade -y
    cd /var/www/pterodactyl && php artisan down
    curl -Lo /var/www/pterodactyl/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    composer install --no-dev --optimize-autoloader
    php artisan migrate --force
    php artisan up
    echo -e "${GREEN}Panel is updated!${RESET}"
    systemctl stop wings
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    systemctl restart wings
    echo -e "${GREEN}Wings is updated!${RESET}"
}

# Main menu
clear
echo -e "${BLUE}${BOLD}Pterodactyl Installer Script${RESET}"
echo -e "${WHITE}Select an option:${RESET}"
echo -e "1) ${CYAN}Install Pterodactyl Panel${RESET}"
echo -e "2) ${CYAN}Install Wings${RESET}"
echo -e "3) ${CYAN}Update everything to the latest version${RESET}"
echo -e "4) ${RED}Exit${RESET}"
echo -n "Your choice: "
read -p "" choice

case $choice in
    1)
        install_panel
        ;;
    2)
        install_wings
        ;;
    3)
        update_all
        ;;
    4)
        echo -e "${RED}Exiting...${RESET}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice, please try again.${RESET}"
        ;;
esac

