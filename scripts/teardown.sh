#!/usr/bin/env bash

[[ "$(whoami)" == 'root' ]] || exit 11

# Reset kubeadm installed state
kubeadm reset -f

# Stop kubelet and all Kubernetes related processes
systemctl stop kubelet || exit 22
[[ $(type -t docker) ]] && systemctl stop docker
systemctl stop containerd || exit 33

# Last resort to kill pods is to delete entirety of containerd state (images too)
[[ $(crictl pods -q 2>/dev/null) ]] && rm -rf /var/lib/containerd

# If using etcd in a dedicated directory (for external etcd)
rm -rf /var/lib/etcd

# Remove virtual network interfaces
dev='lxc cni flann cali cili kube tunl bpf'
rem(){
    unalias ip 2>/dev/null
    ip -brief link |grep $1 |cut -d' ' -f1 |cut -d'@' -f1 \
        |xargs -n1 /bin/bash -c '
            [[ $1 ]] || exit
            ip link set dev $1 down
            ip link delete $1
        ' _
}
export -f rem
printf "%s\n" $dev |xargs -n1 /bin/bash -c 'rem $1 2>/dev/null' _

# Flush iptables : filter, nat, and mangle
iptables --flush
iptables --delete-chain
iptables -t nat --flush
iptables -t nat --delete-chain
iptables -t mangle --flush
iptables -t mangle --delete-chain
#nft flush table ip nat
#nft flush table ip mangle

# Clear IPVS tables
[[ $(type -t ipvsadm) ]] && ipvsadm --clear

# Clear CNI configuration
rm -rf /etc/cni/net.d
rm -rf /var/lib/cni/
rm -rf /var/run/cni/

# Clear remaining kubelet files
rm -rf /var/lib/kubelet

# Optionally, remove all docker/containerd storage
# Warning: This will remove all containers, including their data volumes
# rm -rf /var/lib/docker
# rm -rf /var/lib/containerd

systemctl start containerd
[[ $(type -t docker) ]] && systemctl start docker
systemctl start kubelet

