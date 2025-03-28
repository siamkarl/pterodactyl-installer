#!/bin/bash

# Function to check if WSL is installed
is_wsl() {
    if grep -q "Microsoft" /proc/version; then
        return 0  # WSL is present
    else
        return 1  # Not WSL
    fi
}

# Function to install dos2unix if necessary
install_dos2unix() {
    if ! command -v dos2unix &> /dev/null; then
        echo "Installing dos2unix..."
        sudo apt update && sudo apt install -y dos2unix
    else
        echo "dos2unix is already installed."
    fi
}

# Check if dos2unix needs to be installed (for Linux)
if ! command -v dos2unix &> /dev/null; then
    install_dos2unix
fi

# Function to check for Linux system
is_linux() {
    if [[ "$(uname)" == "Linux" ]]; then
        return 0  # It's a Linux-based system
    else
        return 1  # Not Linux
    fi
}

# Function to check for Windows system (via WSL)
is_windows() {
    if is_wsl; then
        return 0  # It's Windows under WSL
    else
        return 1  # Not Windows
    fi
}

# Main function to decide which installation script to run
run_installation() {
    if is_linux; then
        echo "Linux detected. Running install_linux.sh..."
        ./install_linux.sh
    elif is_windows; then
        echo "Windows (WSL) detected. Running install_windows.sh..."
        ./install_windows.sh
    else
        echo "Unsupported operating system. Exiting."
        exit 1
    fi
}

# Run the installation script based on the OS detection
run_installation
