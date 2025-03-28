#!/bin/bash

# ANSI escape sequences for colors
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
RED="\033[31m"

# URL till skripten
INSTALL_LINUX_URL="https://installer.gamepanel.se/install_linux.sh"
INSTALL_WINDOWS_URL="https://installer.gamepanel.se/install_windows.sh"

# Funktion för att identifiera operativsystemet
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Kontrollera operativsystem
OS_TYPE=$(detect_os)

# Kontrollera om curl är installerat
echo -e "${CYAN}Checking if curl is installed...${RESET}"
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl is not installed. Please install it first.${RESET}"
    exit 1
fi

# Beroende på OS, hämta rätt installationsskript
if [ "$OS_TYPE" == "linux" ]; then
    echo -e "${CYAN}Detected Linux OS. Fetching Linux installation script...${RESET}"
    curl -s -o /tmp/install_linux.sh "$INSTALL_LINUX_URL"
    if [ ! -f /tmp/install_linux.sh ]; then
        echo -e "${RED}Failed to download install_linux.sh. Exiting.${RESET}"
        exit 1
    fi
    chmod +x /tmp/install_linux.sh
    bash /tmp/install_linux.sh
elif [ "$OS_TYPE" == "windows" ]; then
    echo -e "${CYAN}Detected Windows OS. Fetching Windows installation script...${RESET}"
    curl -s -o /tmp/install_windows.sh "$INSTALL_WINDOWS_URL"
    if [ ! -f /tmp/install_windows.sh ]; then
        echo -e "${RED}Failed to download install_windows.sh. Exiting.${RESET}"
        exit 1
    fi
    chmod +x /tmp/install_windows.sh
    bash /tmp/install_windows.sh
else
    echo -e "${RED}Unsupported operating system detected. Exiting.${RESET}"
    exit 1
fi

# Rensa upp genom att ta bort temporära skript
echo -e "${CYAN}Cleaning up...${RESET}"
rm -f /tmp/install_linux.sh /tmp/install_windows.sh

echo -e "${GREEN}Installation process started successfully!${RESET}"
