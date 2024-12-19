# firecracker-dind

The host VM needs to support hardware virtualisation. If the VM is created in vCenter, you need to enable hardware virtualization checkbox which you can see in `Customise Hardware` step when you expand the `CPU` line.
You can run `egrep -c '(vmx|svm)' /proc/cpuinfo` command to verify if it's enabled after running the VM. If this command gives output bigger than 0, then it's enabled for that number of CPU.
Create ssh key pair with `ssh-keygen -f id_rsa -N "" -f ./id_rsa`
Kernel compile steps:
```sh
mkdir firecracker
git clone git@github.com:firecracker-microvm/firecracker.git
cd firecracker
cp kernel-config ./resources/guest_configs/microvm-kernel-ci-x86_64-5.10.config
./tools/devtool build_ci_artifacts kernels 5.10
cp ./resources/$(uname -m)/vmlinux-5.10.225 ../firecracker/vmlinux-5.10.225
```
Above will take a while.
Build rootfs image with `docker build -f Dockerfile.rootfs -t ubuntu-rootfs .`
Run the image with `docker run --privileged -it --rm -v $(pwd)/output:/output ubuntu-rootfs`
This will create output folder and put the image rootfs file named `image.ext4` under it.
Build with `docker build -f Dockerfile.firecracker -t ubuntu-systemd .`
If you want to use different network than the default docker network, create the bridge with `docker network create --driver=bridge --subnet=172.31.0.0/30 --gateway=172.31.0.1 br-test` and run the container with `docker run -d --privileged --name ubuntu-systemd-test --network br-test ubuntu-systemd`. If not, use below command.
Run with `docker run -d --privileged --name ubuntu-systemd-test ubuntu-systemd`

Now you have an Ubuntu 24.04 container which has firecracker binary, kernel compiled with necessary config for running docker containers and debootstrapped ubuntu 24.04 rootfs with well-known packages.
You can now run a container inside an ubuntu 24.04 microVM which runs inside an ubuntu 24.04 container which runs inside a VM with the OS choice of yours(mine was ubuntu 24.04). With this, you have the below setup:

![Setup](images/setup.png)

## **IMPORTANT**:

After you created your tap device, you need to be sure that below rule exist:
```sh
# -t nat: Specifies the nat table.
# -A POSTROUTING: Appends the rule to the POSTROUTING chain. This chain is used for altering packets as they leave the network interface.
# -o eth0: Specifies that this rule applies to packets going out through the eth0 interface.
# -j MASQUERADE: Tells iptables to perform source NAT, replacing the source IP address with the IP of the outgoing interface (eth0)

iptables -t nat -A POSTROUTING -o "$HOST_IFACE" -j MASQUERADE

# List existing rules with below:
iptables -t nat -L POSTROUTING -n -v --line-numbers
# Example output:
# Chain POSTROUTING (policy ACCEPT 42 packets, 2712 bytes)
# num   pkts bytes target              prot opt in     out     source               destination
# 1        2   152 DOCKER_POSTROUTING  0    --  *      *       0.0.0.0/0            127.0.0.11
# 2        0     0 MASQUERADE          0    --  *      eth0    0.0.0.0/0            0.0.0.0/0
```
