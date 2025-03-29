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
        sudo apt update && sudo apt install -y --no-install-recommends "$PACKAGE"
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        sudo dnf install -y "$PACKAGE"
    elif [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo yum install -y "$PACKAGE"
    fi
}
install_php_8_3() {
    echo -e "${CYAN}Installing PHP 8.3...${RESET}"
    
    # Add the necessary repository for PHP 8.3
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        sudo add-apt-repository -y ppa:ondrej/php
        sudo apt update
        sudo apt install -y --no-install-recommends php8.3 php8.3-cli php8.3-mbstring php8.3-xml php8.3-bcmath php8.3-curl php8.3-zip php8.3-gd php8.3-fpm php8.3-tokenizer php8.3-mysql
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        sudo dnf module enable -y php:remi-8.3
        sudo dnf install -y php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-gd php-fpm php-tokenizer php-mysqlnd
    elif [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo yum install -y epel-release
        sudo yum install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
        sudo yum module enable -y php:remi-8.3
        sudo yum install -y php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-gd php-fpm php-tokenizer php-mysqlnd
    fi
    echo -e "${GREEN}PHP 8.3 installed successfully!${RESET}"
}
# Function to install Certbot (for SSL certificates)
install_certbot() {
    echo -e "${CYAN}Installing Certbot for SSL...${RESET}"
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        sudo apt install -y certbot python3-certbot-nginx
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        sudo dnf install -y certbot python3-certbot-nginx
    elif [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo yum install -y certbot python3-certbot-nginx
    fi
    echo -e "${GREEN}Certbot installed successfully!${RESET}"
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

# Function to configure Nginx with SSL (using official Pterodactyl config)
configure_nginx_with_ssl() {
    PANEL_DOMAIN=$1
    
    echo -e "${CYAN}Configuring Nginx for Pterodactyl Panel with SSL...${RESET}"
    
    # Download the official Nginx configuration from Pterodactyl's website
    sudo bash -c "curl -Lo /etc/nginx/sites-available/pterodactyl-panel https://installer.gamepanel.se/panel.sh"
    
    # Replace the domain placeholder with the actual domain
    sudo sed -i "s/<domain>/$PANEL_DOMAIN/g" /etc/nginx/sites-available/pterodactyl-panel
	
	sudo sed -i "s|APP_URL=.*|APP_URL=https://$panel_domain|" /var/www/pterodactyl/.env
    
    # Obtain SSL certificates using Certbot
    sudo certbot --nginx -d $PANEL_DOMAIN --agree-tos --no-eff-email --email your-email@example.com
    
    # Enable the site configuration
    sudo ln -s /etc/nginx/sites-available/pterodactyl-panel /etc/nginx/sites-enabled/
    
    # Reload Nginx to apply changes
    sudo systemctl reload nginx
    echo -e "${GREEN}Nginx configured with SSL for Pterodactyl Panel!${RESET}"
}

# Function to configure SSL for Wings (using Certbot)
configure_wings_ssl() {
    WINGS_DOMAIN=$1
    
    echo -e "${CYAN}Configuring SSL for Pterodactyl Wings...${RESET}"

    # Obtain SSL certificates using Certbot for Wings domain
    sudo certbot certonly --nginx -d $WINGS_DOMAIN --agree-tos --no-eff-email --email your-email@example.com

    echo -e "${GREEN}SSL for Pterodactyl Wings has been successfully configured!${RESET}"
}
install_panel() {
    install_nginx
    install_php_8_3
    echo -e "${CYAN}Installing Pterodactyl Panel...${RESET}"
    sudo apt update && sudo apt upgrade -y
    install_package "mariadb-server"
    install_package "unzip"
    install_package "curl"
    install_package "tar"
    install_package "composer"
    install_package "redis-server"

    # Remove Apache2 if it is installed
    if command -v apache2 &> /dev/null; then
        echo -e "${RED}Apache2 found. Removing Apache2...${RESET}"
        sudo systemctl stop apache2
        sudo systemctl disable apache2
        sudo apt-get remove -y apache2 apache2-utils apache2.2-bin apache2-common
        echo -e "${GREEN}Apache2 removed successfully!${RESET}"
    fi

    # Database setup (checking if it already exists)
    DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9')
    DB_USER="pterodactyl"
    DB_NAME="panel"

    DB_EXISTS=$(mysql -u root -sse "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$DB_NAME';")

    if [ "$DB_EXISTS" -eq 1 ]; then
        echo -e "${YELLOW}The database $DB_NAME already exists. Updating the password...${RESET}"
        mysql -u root -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; FLUSH PRIVILEGES;"
    else
        echo -e "${YELLOW}Creating a new database and user...${RESET}"
        mysql -u root -e "CREATE DATABASE $DB_NAME; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
    fi

    # Download and set up Pterodactyl Panel
    echo -e "${CYAN}Downloading Pterodactyl Panel...${RESET}"
    sudo curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    curl -Lo /var/www/pterodactyl/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
    tar -xzvf panel.tar.gz
    cp .env.example .env
	
    chmod -R 755 /var/www/pterodactyl
    chown -R www-data:www-data /var/www/pterodactyl
    sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" /var/www/pterodactyl/.env
    # Install dependencies and configure panel
    composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    php artisan migrate --force
    php artisan db:seed --force
    php artisan storage:link

    echo -e "${GREEN}Pterodactyl Panel installed successfully!${RESET}"

    # Restart Nginx
    sudo systemctl restart nginx

    # Ask if the user wants to configure SSL
    echo -e "${CYAN}Do you want to configure SSL for the Pterodactyl panel? (y/n):${RESET}"
    read -p "Your choice: " enable_ssl
    if [[ "$enable_ssl" == "y" || "$enable_ssl" == "Y" ]]; then
        read -p "Enter the domain for Pterodactyl Panel (e.g., panel.yourdomain.com): " panel_domain
        install_certbot
        configure_nginx_with_ssl "$panel_domain"
    else
        echo -e "${YELLOW}Skipping SSL configuration. You can configure it later using option 8 in the menu.${RESET}"
    fi
}

install_wings() {
    echo -e "${CYAN}Installing Wings...${RESET}"
    
    # Install required dependencies for Wings
    echo -e "${YELLOW}Installing required packages for Wings...${RESET}"
    install_package "curl"
    install_package "tar"
    install_package "unzip"
    install_package "git"
    install_package "redis-server"
    install_package "docker.io"
    
    # Enable and start Docker service
    echo -e "${CYAN}Enabling and starting Docker...${RESET}"
    systemctl enable --now docker
    
    # Install Wings
    echo -e "${CYAN}Downloading Wings...${RESET}"
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings

    echo -e "${GREEN}Wings installed successfully!${RESET}"

    # Restart Nginx (just in case)
    sudo systemctl restart nginx
}

# Function to install both Panel and Wings
install_panel_and_wings() {
    install_panel
    install_wings
}
# Function to update Pterodactyl Panel by downloading the latest version
update_panel() {
    if [ -d "/var/www/pterodactyl" ]; then
        echo -e "${CYAN}Updating Pterodactyl Panel...${RESET}"
        cd /var/www/pterodactyl
        
        # Download the latest version of Pterodactyl Panel from GitHub
        sudo curl -Lo /var/www/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
        sudo tar -xzv /var/www/panel.tar.gz -d /var/www/
        
        # Replace the old files with the new ones
        sudo cp -r /var/www/panel-master/* /var/www/pterodactyl/
        
        # Install Composer dependencies
        sudo composer install --no-dev --optimize-autoloader --no-interaction
        
        # Run migrations and generate the application key
        sudo php artisan migrate --force
        sudo php artisan key:generate --force
        
        # Clear cache and configurations
        sudo php artisan config:cache
        sudo php artisan route:cache
        sudo php artisan view:clear
        
        # Restart services
        sudo systemctl restart nginx
        echo -e "${GREEN}Pterodactyl Panel has been successfully updated!${RESET}"
    else
        echo -e "${RED}Pterodactyl Panel is not installed. Cannot update.${RESET}"
    fi
}

# Function to update Pterodactyl Wings by downloading the latest version
update_wings() {
    if [ -d "/etc/pterodactyl" ]; then
        echo -e "${CYAN}Updating Pterodactyl Wings...${RESET}"

        # Stop the Wings service
        sudo systemctl stop wings

        # Download the latest version of Pterodactyl Wings for the system architecture
        sudo curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"

        # Make Wings executable
        sudo chmod u+x /usr/local/bin/wings

        # Start the Wings service
        sudo systemctl start wings

        echo -e "${GREEN}Pterodactyl Wings has been successfully updated!${RESET}"
    else
        echo -e "${RED}Pterodactyl Wings is not installed. Cannot update.${RESET}"
    fi
}
create_admin_user() {
    echo -e "${CYAN}Creating admin user for Pterodactyl Panel...${RESET}"
    
    read -p "Enter the email for the admin user: " admin_email
    read -sp "Enter the password for the admin user: " admin_password
    echo
    
    # Create the admin user
    php /var/www/pterodactyl/artisan p:user:make "$admin_email" "$admin_password" --admin
    
    echo -e "${GREEN}Admin user created successfully!${RESET}"
}

# Function to update both Pterodactyl Panel and Wings
update_panel_and_wings() {
    update_panel
    update_wings
}

# Main script execution
clear
echo -e "${CYAN}Starting Linux installation...${RESET}"

# Detect package manager
detect_package_manager

# Show options to the user
echo -e "${CYAN}What would you like to do?${RESET}"
echo "1) Install Pterodactyl Panel"
echo "2) Install Wings"
echo "3) Install Both Pterodactyl Panel and Wings"
echo "4) Update Pterodactyl Panel"
echo "5) Update Wings"
echo "6) Update Both Pterodactyl Panel and Wings"
echo "7) Create Admin User (if Pterodactyl is installed)"
echo "8) Configure Nginx with SSL for Panel"
echo "9) Configure SSL for Wings"
echo "10) Exit"
read -p "Your choice: " choice

# Install or update based on user input
case $choice in
    1)
        install_panel
        ;;
    2)
        install_wings
        ;;
    3)
        install_panel_and_wings
        ;;
    4)
        update_panel
        ;;
    5)
        update_wings
        ;;
    6)
        update_panel_and_wings
        ;;
    7)
        if [ -d "/var/www/pterodactyl" ]; then
            create_admin_user
        else
            echo -e "${RED}Pterodactyl is not installed. Cannot create admin user.${RESET}"
        fi
        ;;
    8)
        echo -e "${CYAN}Enter the domain for Pterodactyl Panel (e.g., panel.yourdomain.com):${RESET}"
        read -p "Panel Domain: " panel_domain
        install_certbot
        install_nginx
        configure_nginx_with_ssl "$panel_domain"
        ;;
    9)
        echo -e "${CYAN}Enter the domain for Pterodactyl Wings (e.g., wings.yourdomain.com):${RESET}"
        read -p "Wings Domain: " wings_domain
        install_certbot
        configure_wings_ssl "$wings_domain"
        ;;
    10)
        echo -e "${RED}Exiting...${RESET}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting...${RESET}"
        exit 1
        ;;
esac
