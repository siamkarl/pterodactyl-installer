#!/bin/bash

# Remove Windows-style line endings (CRLF -> LF)
sed -i 's/\r//' "$0"

# Check for necessary utilities
install_dos2unix() {
    if ! command -v dos2unix &> /dev/null; then
        echo "dos2unix is not installed. Installing dos2unix..."
        sudo apt update && sudo apt install -y dos2unix
    else
        echo "dos2unix is already installed."
    fi
}

# Check for WSL (Windows Subsystem for Linux)
is_wsl() {
    if grep -qE "(Microsoft|WSL)" /proc/version; then
        echo "Running inside WSL."
        return 0
    else
        echo "Not running inside WSL."
        return 1
    fi
}

# Check for Linux environment and Ubuntu compatibility
is_linux_ubuntu() {
    if [[ "$(uname)" == "Linux" ]] && grep -q "Ubuntu" /etc/os-release; then
        echo "Linux with Ubuntu detected."
        return 0
    else
        echo "Not Ubuntu. This script supports Ubuntu-based systems."
        return 1
    fi
}

# Install essential utilities if not installed
install_essential_tools() {
    echo "Checking for essential tools..."

    # Update apt package index
    sudo apt update -y

    # Install necessary tools
    essential_tools=("curl" "tar" "unzip" "git")
    for tool in "${essential_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            echo "$tool is not installed. Installing..."
            sudo apt install -y $tool
        else
            echo "$tool is already installed."
        fi
    done
}

# Main precheck logic
precheck() {
    echo "Running precheck for the server..."

    # Ensure dos2unix is installed
    install_dos2unix

    # Check if running in WSL (skip Linux checks if in WSL)
    if is_wsl; then
        install_essential_tools
        return
    fi

    # Check if Ubuntu-based Linux system is running
    if is_linux_ubuntu; then
        install_essential_tools
        return
    else
        echo "This script only supports Ubuntu-based Linux systems."
        exit 1
    fi
}

# Execute precheck
precheck

