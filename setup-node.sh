#!/bin/bash

# Update package lists and upgrade existing packages
apt-get update
apt-get install -y curl socat git wget unzip

# Install Docker
curl -fsSL https://get.docker.com | sh

# Clone the Marzban-node repository
git clone https://github.com/Gozargah/Marzban-node

# Create directories
mkdir -p /var/lib/marzban-node
mkdir -p /var/lib/marzban/xray-core

# Navigate to the Marzban-node directory
cd ~/Marzban-node

# Remove existing docker-compose.yml
rm -f docker-compose.yml

# Create a new docker-compose.yml file
cat <<EOF >docker-compose.yml
services:
  marzban-node-1:
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

# Add placeholder certificate
echo "-----BEGIN CERTIFICATE-----
<YOUR_CERTIFICATE_CONTENT>
-----END CERTIFICATE-----" > /var/lib/marzban-node/me.pem

# Download and extract Xray core
cd /var/lib/marzban/xray-core
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.4/Xray-linux-64.zip
unzip Xray-linux-64.zip
rm Xray-linux-64.zip

# Start Marzban-node
cd ~/Marzban-node
docker compose down --remove-orphans
docker compose up -d

# Install HAProxy
apt-get install -y haproxy

# Configure HAProxy
cat <<EOF >> /etc/haproxy/haproxy.cfg

listen front
  mode tcp
  bind *:443
  tcp-request inspect-delay 5s
  tcp-request content accept if { req_ssl_hello_type 1 }
  use_backend reality if { req.ssl_sni -m end app.hubspot.com | www.sephora.com | cdn.discordapp.com | icloud.com }

backend reality
  mode tcp
  server sv1 127.0.0.1:6000 send-proxy

frontend http_front
  bind *:80
  mode http
  redirect location https://nextcloud.technologiewerk-qua.de code 301

backend http_back
  mode http
  balance roundrobin
EOF

# Restart HAProxy service
systemctl restart haproxy.service

# Print a success message
echo "Marzban-node, Xray core, and HAProxy setup completed!"
