#!/bin/bash

# ANSI escape sequences for colors
RESET="\033[0m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"

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

# Function to install Nginx
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo -e "${CYAN}Installing Nginx...${RESET}"
        install_package "nginx"
        sudo systemctl enable nginx && sudo systemctl start nginx
    else
        echo -e "${GREEN}Nginx is already installed.${RESET}"
    fi
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
    
    # Database setup (using random password)
    DB_PASSWORD=$(openssl rand -base64 16)
    DB_USER="pterodactyl"
    DB_NAME="panel"
    
    echo -e "${YELLOW}Configuring the database...${RESET}"
    mysql -u root -e "CREATE DATABASE $DB_NAME; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
    
    echo -e "${GREEN}Database user: $DB_USER"
    echo -e "${GREEN}Database password: $DB_PASSWORD"
    echo -e "${GREEN}Database name: $DB_NAME${RESET}"
    
    # Continue the installation (Pterodactyl specific)
    echo -e "${CYAN}Downloading Pterodactyl Panel...${RESET}"
    curl -Lo /var/www/pterodactyl/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
    tar -xzvf panel.tar.gz
    cp .env.example .env
    chmod -R 755 /var/www/pterodactyl
    chown -R www-data:www-data /var/www/pterodactyl
    composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    php artisan migrate --force
    php artisan db:seed --force
    php artisan storage:link
    echo -e "${GREEN}Pterodactyl Panel installed!${RESET}"
    
    # Restart Nginx
    sudo systemctl restart nginx
}

# Main script execution
clear
echo -e "${CYAN}Starting Linux installation...${RESET}"

# Detect package manager
detect_package_manager

# Install the panel
install_panel
