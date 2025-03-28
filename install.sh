#!/bin/bash

# Check for WSL installation
if ! wsl --list --verbose &> /dev/null; then
    echo "WSL is not installed. Installing WSL..."
    powershell.exe -Command "wsl --install"
    exit 1
fi

# Install Ubuntu if not already installed
if ! wsl --list --quiet | grep -q "Ubuntu"; then
    echo "Ubuntu is not installed. Installing Ubuntu..."
    powershell.exe -Command "wsl --install -d Ubuntu"
    exit 1
fi

# Run the installation within WSL (Ubuntu)
wsl << 'EOF'
# Check if the operating system is Ubuntu (since we're using Ubuntu on WSL)
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')

if [[ "$OS_ID" != "ubuntu" ]]; then
    echo "This script only supports Ubuntu."
    exit 1
fi

echo "Select an option:"
echo "1) Install Pterodactyl Panel"
echo "2) Install Wings"
echo "3) Update everything to the latest version"
echo "4) Exit"
read -p "Your choice: " choice

CLOUDFLARE_API_KEY="your_cloudflare_api_key"
CLOUDFLARE_EMAIL="your_cloudflare_email"
ZONE_ID="your_zone_id"
DOMAIN="yourdomain.com"

install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo "Installing Nginx..."
        sudo apt update && sudo apt install -y nginx
        sudo systemctl enable nginx && sudo systemctl start nginx
    else
        echo "Nginx is already installed."
    fi
}

generate_ssl() {
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx --agree-tos --redirect --email $CLOUDFLARE_EMAIL -d panel.$DOMAIN -d wings.$DOMAIN
}

create_cloudflare_dns() {
    local subdomain=$1
    local ip=$(curl -s http://checkip.amazonaws.com)
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
         -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
         -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
         -H "Content-Type: application/json" \
         --data '{"type":"A","name":"'$subdomain.$DOMAIN'","content":"'$ip'","ttl":120,"proxied":true}'
}

install_panel() {
    install_nginx
    echo "Installing Pterodactyl Panel..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y mariadb-server unzip curl tar composer redis-server php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-gd php-fpm php-tokenizer php-mysql
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

install_wings() {
    install_nginx
    echo "Installing Wings..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl tar unzip git redis-server docker.io
    systemctl enable --now docker
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    create_cloudflare_dns "wings"
    generate_ssl
    echo "Wings is installed and SSL is configured!"
}

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
EOF
