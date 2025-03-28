# !/bin/bash

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

# Function to install dos2unix (Linux only)
install_dos2unix() {
    if ! command -v dos2unix &> /dev/null; then
        echo -e "${CYAN}Installing dos2unix...${RESET}"
        install_package "dos2unix"
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

# Install necessary tools and proceed to correct installation file
install_dos2unix
clear

# Check for OS and run respective install script
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${CYAN}Proceeding to Linux installation...${RESET}"
    bash install_linux.sh
elif [[ "$OSTYPE" == "msys" ]]; then
    echo -e "${CYAN}Proceeding to Windows installation...${RESET}"
    bash install_windows.sh
else
    echo -e "${RED}Unsupported OS. Exiting.${RESET}"
    exit 1
fi
