#!/bin/bash

# ANSI escape sequences for colors
RESET="\033[0m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"

echo -e "${CYAN}Starting Windows (WSL) installation...${RESET}"

# Check if WSL is installed
if ! wsl --list --verbose &> /dev/null; then
    echo -e "${RED}WSL is not installed. Please install WSL first.${RESET}"
    exit 1
fi

# Check if Ubuntu is installed in WSL
if ! wsl --list --quiet | grep -q "Ubuntu"; then
    echo -e "${CYAN}Ubuntu is not installed. Installing Ubuntu...${RESET}"
    powershell.exe -Command "wsl --install -d Ubuntu"
    exit 1
fi

# Proceed with Linux installation inside WSL
bash install_linux.sh
