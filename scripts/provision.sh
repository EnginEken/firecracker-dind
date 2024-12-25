#! /bin/bash
set -ex

# Set Hostname
echo 'ubuntu-noble' > /etc/hostname

# Remove Root Password (Optional)
passwd -d root

# Configure Serial Console for Auto-login
mkdir /etc/systemd/system/serial-getty@ttyS0.service.d/
cat <<EOF > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -o '-p -- \\u' --keep-baud 115200,38400,9600 %I \$TERM
EOF

# Configure Networking with Netplan if needed
# cat <<EOF > /etc/netplan/99_config.yaml
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     eth0:
#       addresses:
#          - 172.16.0.6/24
#       gateway4: 172.16.0.5
# EOF
# netplan generate

echo "[Resolve]" > /etc/systemd/resolved.conf
echo "DNS=8.8.8.8" >> /etc/systemd/resolved.conf
echo "FallbackDNS=1.1.1.1" >> /etc/systemd/resolved.conf
systemctl enable systemd-resolved

# Ensure .ssh directory exists inside the chrooted environment's root home
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Copy the authorized_keys from the mounted directory (/mnt)
cp /mnt/root/.ssh/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys


# Add Docker’s Official GPG Key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set Up the Docker Repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update Package Lists Again
apt-get update

# Bash completion
echo "if [ -f /usr/share/bash-completion/bash_completion ]; then" >> /etc/bash.bashrc
echo "    . /usr/share/bash-completion/bash_completion" >> /etc/bash.bashrc
echo "fi" >> /etc/bash.bashrc

sed -i 's/^\(127\.0\.0\.1\s\+localhost\)$/\1 ubuntu-noble/' /etc/hosts

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf;

# Install Docker Engine
apt-get install -y docker-ce docker-ce-cli containerd.io

# Below needed for docker service to run inside the microvm. Couldn't find a way to run it with nf_tables
# even if I enabled all required options in kernel-config
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Improve the MOTD
echo "Welcome to your Ubuntu microVM!" > /etc/motd
echo "Try running 'sudo docker run --rm -it ubuntu:latest bash' to start a container." >> /etc/motd

# Enable ssh service
systemctl enable ssh

# Clean Up
apt-get clean
rm -rf /var/lib/apt/lists/*

# (Optional) Add Docker Group and User Permissions
# Uncomment the following lines if you want to add a non-root user with Docker privileges
# useradd -m dockeruser
# usermod -aG docker dockeruser
