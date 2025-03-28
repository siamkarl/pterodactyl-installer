#!/bin/bash

# Function to check if we are running under WSL
is_wsl() {
    if grep -qEi "(microsoft|WSL)" /proc/version &> /dev/null; then
        return 0  # Return true if in WSL
    else
        return 1  # Return false if not in WSL
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
        echo "Unsupported package manager. Exiting."
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
    echo "You are in WSL, starting installation..."
else
    echo "Not in WSL. Please run this script inside WSL."
    exit 1
fi

# Check for Ubuntu or any other Linux version and use respective package manager
detect_package_manager

# Function to install Nginx
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo "Installing Nginx..."
        install_package "nginx"
        sudo systemctl enable nginx && sudo systemctl start nginx
    else
        echo "Nginx is already installed."
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

# Function to install Pterodactyl Panel
install_panel() {
    install_nginx
    echo "Installing Pterodactyl Panel..."
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

    echo "Configure the database:"
    read -p "Database user: " db_user
    read -p "Database password: " db_pass
    read -p "Database name: " db_name
    mysql -u root -e "CREATE DATABASE $db_name; CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass'; GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost'; FLUSH PRIVILEGES;"

    php artisan migrate --force
    php artisan db:seed --force
    php artisan storage:link
    create_cloudflare_dns "panel"
    generate_ssl
    echo "Panel is installed and SSL is configured!"
    sudo systemctl restart nginx
}

# Function to install Wings
install_wings() {
    install_nginx
    echo "Installing Wings..."
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
    echo "Wings is installed and SSL is configured!"
}

# Function to update all
update_all() {
    echo "Updating everything to the latest version..."
    sudo apt update && sudo apt upgrade -y
    cd /var/www/pterodactyl && php artisan down
    curl -Lo /var/www/pterodactyl/panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    composer install --no-dev --optimize-autoloader
    php artisan migrate --force
    php artisan up
    echo "Panel is updated!"
    systemctl stop wings
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    systemctl restart wings
    echo "Wings is updated!"
}

# Main menu
echo "Select an option:"
echo "1) Install Pterodactyl Panel"
echo "2) Install Wings"
echo "3) Update everything to the latest version"
echo "4) Exit"
read -p "Your choice: " choice

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
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice, please try again."
        ;;
esac
