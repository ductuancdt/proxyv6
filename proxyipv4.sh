#!/bin/bash

check_firewall() {
    # Check if firewalld is installed
    if ! rpm -q firewalld &>/dev/null; then
        echo "Firewalld is not installed. Installing firewalld..."
        sudo yum install -y firewalld
    fi

    # Check the status of firewalld
    firewalld_status=$(systemctl is-active firewalld)

    if [ "$firewalld_status" != "active" ]; then
        echo "Firewalld is not running. Starting firewalld..."
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        echo "Firewalld has been started and enabled."
    else
        echo "Firewalld is already running."
    fi
}

# Ensure the script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with root or sudo privileges."
    exit 1
fi

echo "Updating the system and installing Squid..."
sudo yum update -y
sudo yum -y install squid || { echo "Squid installation failed"; exit 1; }

echo "Enabling and starting Squid service..."
sudo systemctl enable squid || { echo "Enabling Squid service failed"; exit 1; }
sudo systemctl start squid || { echo "Starting Squid service failed"; exit 1; }

echo "Enter the port you want Squid to use:"
read port

# Validate that the input is a number
if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "Port must be a number."
    exit 1
fi

echo "Configuring Squid to use port $port..."
sudo sed -i "s/^http_port .*/http_port $port/" /etc/squid/squid.conf || { echo "Editing squid.conf failed"; exit 1; }
sudo sed -i 's/http_access deny all/http_access allow all/' /etc/squid/squid.conf || { echo "Editing squid.conf failed"; exit 1; }

echo "Restarting Squid service..."
sudo systemctl restart squid || { echo "Restarting Squid service failed"; exit 1; }

check_firewall

echo "Opening port $port in the firewall..."
sudo firewall-cmd --permanent --add-port=${port}/tcp || { echo "Opening port in the firewall failed"; exit 1; }
sudo firewall-cmd --reload || { echo "Reloading firewall failed"; exit 1; }

echo "Configuration complete. Squid is running on port $port and the firewall has been configured."
