#!/bin/bash
set -e

# Set Configuration Variables
BRIDGE="fc_bridge"
BRIDGE_IP="172.16.0.1/24"
SUBNET="172.16.0.0/24"
TAP_PREFIX="tap"
SSH_BASE_PORT=2200

# Function to create a bridge
create_bridge() {
    if ! ip link show "$BRIDGE" &> /dev/null; then
        echo "Creating bridge: $BRIDGE"
        ip link add name "$BRIDGE" type bridge
        ip addr add "$BRIDGE_IP" dev "$BRIDGE"
        ip link set dev "$BRIDGE" up
    else
        echo "Bridge $BRIDGE already exists."
    fi
}

# Function to enable IP forwarding and set iptables rules
setup_network() {
    echo "Enabling IP forwarding."
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Identify the host's default network interface (assuming container uses host network)
    HOST_IFACE=$(ip -j route list default | jq -r '.[0].dev')

    echo "Setting up iptables for NAT."
    iptables -t nat -A POSTROUTING -s "$SUBNET" -o "$HOST_IFACE" -j MASQUERADE
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -s "$SUBNET" -j ACCEPT
}

# Initialize networking
create_bridge
setup_network

# # Start SSH service
# echo "Starting SSH service."
# service ssh start

# Keep the container running
echo "Container setup complete. Running in foreground."
tail -f /dev/null
