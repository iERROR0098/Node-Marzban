#!/bin/bash

# Function to display an error message and exit
function error_exit {
    echo "$1" 1>&2
    exit 1
}

# Update package lists and install dependencies
apt-get update
apt-get upgrade -y
apt-get install -y curl socat git wget unzip || error_exit "Failed to install required packages."

# Install Docker
curl -fsSL https://get.docker.com | sh || error_exit "Failed to install Docker."

# Clone the Marzban-node repository
git clone https://github.com/Gozargah/Marzban-node || error_exit "Failed to clone the Marzban-node repository."

# Create the /var/lib/marzban-node directory if it doesn't exist
mkdir -p /var/lib/marzban-node || error_exit "Failed to create /var/lib/marzban-node directory."

# Navigate to the Marzban-node directory
cd Marzban-node || error_exit "Failed to navigate to the Marzban-node directory."

# Remove existing docker-compose.yml (if present)
rm -f docker-compose.yml || error_exit "Failed to remove existing docker-compose.yml file."

# Get ports from the user
PORTS=()
while true; do
    read -p "Enter the port mapping (format: host_port:container_port) or 'done' to finish: " PORT
    if [[ $PORT == "done" ]]; then
        break
    fi
    PORTS+=("$PORT")
done

# Get the certificate from the user
echo "Please paste your certificate content (end with an empty line):"
CERT_CONTENT=""
while IFS= read -r line; do
    [[ $line ]] || break  # Exit the loop on an empty line
    CERT_CONTENT+="$line"$'\n'
done

# Save the certificate to /var/lib/marzban-node/me.pem
echo "$CERT_CONTENT" > /var/lib/marzban-node/me.pem

# Create a new docker-compose.yml file with secure environment variables
cat <<EOF >docker-compose.yml
services:
  marzban-node-1:
    image: gozargah/marzban-node:latest
    restart: always

    environment:
      # Use the provided certificate path
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/me.pem"
      # Consider using a secret management tool for XRAY_EXECUTABLE_PATH
      XRAY_EXECUTABLE_PATH: "/var/lib/marzban/xray-core/xray"

    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
      - /var/lib/marzban:/var/lib/marzban

    ports:
EOF

# Add the ports to the docker-compose.yml file
for PORT in "${PORTS[@]}"; do
    echo "      - $PORT" >> docker-compose.yml
done

# Security Note: Do not hardcode sensitive information like certificates or paths in the script. Store them securely (e.g., encrypted) and reference them dynamically. Consider using a secret management tool for these values.

# Create a placeholder for the me.pem certificate (replace with your actual certificate)
# The certificate is already saved above from the user input.

mkdir -p /var/lib/marzban/xray-core && cd /var/lib/marzban/xray-core || error_exit "Failed to create or navigate to /var/lib/marzban/xray-core."

# Download Xray core (replace with the desired version URL if necessary)
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip || error_exit "Failed to download Xray core."

# Extract the Xray core archive
unzip Xray-linux-64.zip || error_exit "Failed to extract Xray core."

# Remove the downloaded archive
rm Xray-linux-64.zip || error_exit "Failed to remove the downloaded archive."

# Start Marzban-node in detached mode (background)
cd ~/Marzban-node || error_exit "Failed to navigate to ~/Marzban-node."
docker compose down --remove-orphans || error_exit "Failed to bring down Docker Compose services."
docker compose up -d || error_exit "Failed to start Docker Compose services."

# Print a success message
echo "Marzban-node and Xray core setup completed!"

# Change DNS server to 8.8.8.8 and 1.1.1.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Make the resolv.conf file immutable to prevent changes
chattr +i /etc/resolv.conf

# Print a success message for DNS update
echo "DNS server has been updated and the file has been locked."