#!/bin/bash
set -e

# Check if VM ID is provided
if [ -z "$1" ]; then
    echo "Usage: launch_microvm.sh <vm_id>"
    exit 1
fi

VM_ID=$1
TAP_PREFIX="tap"
TAP_DEV="${TAP_PREFIX}${VM_ID}"
MICROVM_IP="172.16.0.$((VM_ID + 1))"
GATEWAY_IP="172.16.0.1"
BRIDGE="fc_bridge"
SSH_BASE_PORT=2200

# Configuration Variables
CONFIG_DIR="/opt/firecracker"
CONFIG_TEMPLATE="${CONFIG_DIR}/config.json"
CONFIG_FILE="${CONFIG_DIR}/config_${VM_ID}.json"
KERNEL="${CONFIG_DIR}/vmlinux"
ROOTFS="${CONFIG_DIR}/rootfs.ext4"
API_SOCK="/tmp/firecracker_${VM_ID}.sock"
LOG_FILE="/tmp/firecracker_${VM_ID}.log"
SSH_PORT=$((SSH_BASE_PORT + VM_ID))

# Convert VM_ID to two-digit hex
MAC_HEX=$(printf '%02X' "$VM_ID")

# Create TAP device
echo "Creating TAP device: $TAP_DEV with IP: $MICROVM_IP"
ip link del "$TAP_DEV" 2>/dev/null || true
ip tuntap add dev "$TAP_DEV" mode tap user root
# ip addr add "$MICROVM_IP/30" dev "$TAP_DEV"
ip link set dev "$TAP_DEV" up
ip link set "$TAP_DEV" master "$BRIDGE"

# Generate Firecracker config for this VM
echo "Generating Firecracker config for VM ID: $VM_ID"
sed "s|{{TAP_DEV}}|$TAP_DEV|g; \
     s|{{KERNEL}}|$KERNEL|g; \
     s|{{ROOTFS}}|$ROOTFS|g; \
     s|{{API_SOCK}}|$API_SOCK|g; \
     s|{{VM_IP}}|$MICROVM_IP|g; \
     s|{{GATEWAY_IP}}|$GATEWAY_IP|g; \
     s|{{MAC_SUFFIX}}|$MAC_HEX|g" \
    "$CONFIG_TEMPLATE" > "$CONFIG_FILE"

# Launch Firecracker
echo "Launching Firecracker microVM: $VM_ID"
touch "$LOG_FILE"
firecracker --api-sock "$API_SOCK" --config-file "$CONFIG_FILE" --log-path "$LOG_FILE" --level Debug --show-level --show-log-origin &

# Wait for Firecracker to start
sleep 2

# Setup port forwarding for SSH
echo "Setting up port forwarding: Host port $SSH_PORT -> MicroVM IP $MICROVM_IP:22"
iptables -t nat -A PREROUTING -p tcp --dport "$SSH_PORT" -j DNAT --to-destination "$MICROVM_IP":22
iptables -A FORWARD -p tcp -d "$MICROVM_IP" --dport 22 -j ACCEPT

# Wait for network to start working
sleep 10

echo "MicroVM $VM_ID is up and accessible via SSH on port $SSH_PORT."
