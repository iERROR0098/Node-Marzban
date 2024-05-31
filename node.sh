#!/bin/bash

function error_exit {
    echo "$1" >&2
    exit 1
}

function command_exists {
    command -v "$1" >/dev/null 2>&1
}

if [ "$EUID" -ne 0 ]; then
    error_exit "Please run as root."
fi

if ! command_exists docker; then
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com | sh || error_exit "Failed to install Docker."
fi

echo "Updating package lists and installing dependencies..."
apt-get update || error_exit "Failed to update package lists."
apt-get install -y curl socat git wget unzip || error_exit "Failed to install required packages."

echo "Cloning Marzban-node repository..."
git clone https://github.com/Gozargah/Marzban-node || error_exit "Failed to clone the Marzban-node repository."

echo "Creating /var/lib/marzban-node directory..."
mkdir -p /var/lib/marzban-node || error_exit "Failed to create /var/lib/marzban-node directory."

cd Marzban-node || error_exit "Failed to navigate to the Marzban-node directory."

echo "Removing existing docker-compose.yml file..."
rm -f docker-compose.yml || error_exit "Failed to remove existing docker-compose.yml file."

echo "Please paste your certificate content (end with an empty line):"
CERT_CONTENT=""
while IFS= read -r line; do
    [[ $line ]] || break
    CERT_CONTENT+="$line"$'\n'
done

echo "Saving the certificate to /var/lib/marzban-node/me.pem..."
echo "$CERT_CONTENT" > /var/lib/marzban-node/me.pem || error_exit "Failed to save the certificate."

echo "Creating docker-compose.yml file..."
cat <<EOF >docker-compose.yml
services:
  marzban-node:
    image: gozargah/marzban-node:latest
    restart: always
    environment:
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/me.pem"
      XRAY_EXECUTABLE_PATH: "/var/lib/marzban/xray-core/xray"
    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
      - /var/lib/marzban:/var/lib/marzban

    ports:
      - 1710:62050
      - 1711:62051
      - 6000:443
EOF

echo "Creating and navigating to /var/lib/marzban/xray-core..."
mkdir -p /var/lib/marzban/xray-core && cd /var/lib/marzban/xray-core || error_exit "Failed to create or navigate to /var/lib/marzban/xray-core."

echo "Downloading Xray core..."
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip || error_exit "Failed to download Xray core."

echo "Extracting Xray core..."
unzip Xray-linux-64.zip || error_exit "Failed to extract Xray core."

echo "Removing the downloaded archive..."
rm Xray-linux-64.zip || error_exit "Failed to remove the downloaded archive."

echo "Starting Marzban-node..."
cd ~/Marzban-node || error_exit "Failed to navigate to ~/Marzban-node."
docker compose down --remove-orphans || error_exit "Failed to bring down Docker Compose services."
docker compose up -d || error_exit "Failed to start Docker Compose services."

echo "Marzban-node and Xray core setup completed successfully!"
