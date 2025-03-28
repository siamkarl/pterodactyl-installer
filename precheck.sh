#!/bin/bash

# ANSI escape sequences for colors
RESET="\033[0m"
GREEN="\033[32m"
RED="\033[31m"
CYAN="\033[36m"
YELLOW="\033[33m"

# Function to install dos2unix if not installed
install_dos2unix() {
    if ! command -v dos2unix &> /dev/null; then
        echo -e "${CYAN}Installing dos2unix...${RESET}"
        if [ -x "$(command -v apt)" ]; then
            sudo apt update && sudo apt install -y dos2unix
        elif [ -x "$(command -v dnf)" ]; then
            sudo dnf install -y dos2unix
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y dos2unix
        else
            echo -e "${RED}No compatible package manager found. Please install dos2unix manually.${RESET}"
            exit 1
        fi
    else
        echo -e "${GREEN}dos2unix is already installed.${RESET}"
    fi
}

# Check if we are in WSL (Windows Subsystem for Linux)
is_wsl() {
    if grep -qEi "(microsoft|WSL)" /proc/version &> /dev/null; then
        return 0  # We are in WSL
    else
        return 1  # Not in WSL
    fi
}

# Run the dos2unix installation check
install_dos2unix

# Check the platform and proceed accordingly
if is_wsl; then
    echo -e "${CYAN}You are in WSL, preparing for Linux installation...${RESET}"
    bash install_linux.sh
else
    echo -e "${CYAN}You are on Windows, preparing for Windows installation...${RESET}"
    bash install_windows.sh
fi
