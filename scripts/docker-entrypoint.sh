#!/bin/bash
set -e

TAP_DEV="tap0"
TAP_IP="172.16.0.1"
MASK_SHORT="/30"

# Setup network interface
ip link del "$TAP_DEV" 2> /dev/null || true
ip tuntap add dev "$TAP_DEV" mode tap
ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
ip link set dev "$TAP_DEV" up

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -P FORWARD ACCEPT
# Identify the host's default network interface
HOST_IFACE=$(ip -j route list default | jq -r '.[0].dev')

# Add the MASQUERADE rule for NAT
iptables -t nat -A POSTROUTING -o "$HOST_IFACE" -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Start systemd
exec /lib/systemd/systemd
