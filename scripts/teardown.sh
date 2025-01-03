#!/usr/bin/env bash

[[ "$(whoami)" == 'root' ]] || exit 11

[[ -f ~/.kube/config ]] ||
    export KUBECONFIG=/etc/kubernetes/admin.conf

helm list -A 2>&1 \
    |grep -ve WARN -ve NAME \
    |xargs -IX /bin/bash -c 'helm uninstall -n $2 $1' _ X

kubectl get no |grep -v NAME |cut -d' ' -f1 \
    |xargs -I{} kubectl drain --ignore-daemonsets=true {}

kubectl get no |grep -v NAME |cut -d' ' -f1 \
    |xargs -I{} kubectl cordon {}

manifests=/etc/kubernetes/manifests
rm $manifests/kube-apiserver.yaml &&
    find $manifests -type f -exec rm {} \; &&
        sleep 10

# Delete residual Pods
[[ $(systemctl is-active containerd) == 'active' ]] ||
    systemctl start containerd
obj="$(sudo crictl pods -q)"
echo "$obj" |xargs -I{} crictl stopp {}
echo "$obj" |xargs -I{} crictl rmp {}
[[ $obj ]] && echo 'RESIDUAL Pods' && sleep 3

# Delete residual containers
obj="$(sudo crictl ps -q)"
echo "$obj" |xargs -I{} crictl stop {}
echo "$obj" |xargs -I{} crictl rm {}
[[ $obj ]] && echo 'RESIDUAL containers' && sleep 3

# Delete CRDs
kubectl get crds |grep -v NAME |cut -d' ' -f1 \
    |xargs -I{} kubectl delete crds {}

# Reset kubeadm installed state
kubeadm reset -f 2>/dev/null

# Stop kubelet and all Kubernetes related processes
systemctl stop kubelet #|| exit 22
[[ $(type -t docker) ]] && systemctl stop docker
systemctl stop containerd #|| exit 33
rm -rf /run/containerd

## Delete rook-ceph Network Block Devices 
# type -t qemu-nbd || dnf install -y qemu-nbd
# for nbd in /dev/nbd*; do
#     qemu-nbd --disconnect $nbd
# done
## Delete rook-ceph state
rm -rf /var/lib/rook
## Wipe rook-ceph block device 
#rbd=sdb
#sudo wipefs --all /dev/$rdb && sudo dd if=/dev/zero of=/dev/$rbd bs=1M count=10

# If using etcd in a dedicated directory (for external etcd)
rm -rf /var/lib/etcd

# Remove virtual network interfaces
dev='lxc cni flann cali cili kube tunl bpf'
rem(){
    command ip -brief link |grep $1 |cut -d' ' -f1 |cut -d'@' -f1 \
        |xargs -n1 /bin/bash -c '
            [[ $1 ]] || exit
            ip link set dev $1 down
            ip link delete $1
        ' _
}
export -f rem
printf "%s\n" $dev \
    |xargs -n1 /bin/bash -c 'rem $1 2>/dev/null' _

systemctl disable --now firewalld
#systemctl stop iptables
systemctl disable --now nftables

# Flush iptables : filter, nat, and mangle
# iptables --flush
# iptables --delete-chain
# iptables -t nat --flush
# iptables -t nat --delete-chain
# iptables -t mangle --flush
# iptables -t mangle --delete-chain

# Cleanup nftables
#nft flush ruleset
cni='cni cali cilium kube'
tables='raw nat filter'
for table in $tables; do
    for name in $cni; do
        nft list table ip $table \
            |grep -io "chain $name-[^ ]*" \
            |awk '{print $2}' \
            |xargs -I{} nft delete chain ip $table "{}"
    done
done
# Persist 
#nft list ruleset > /etc/nftables.conf
#systemctl enable --now firewalld
#systemctl stop iptables
systemctl enable --now nftables

# Clear IPVS tables
[[ $(type -t ipvsadm) ]] && ipvsadm --clear

# Clear CNI configuration
rm -rf /etc/cni/net.d
rm -rf /var/{lib,run}/{cni,calico,cilium,kube-router}

# Clear remaining kubelet files
rm -rf /var/lib/kubelet

systemctl start containerd
# Last resort to delete all pods : delete entire containerd store.
# (This deletes all pulled/cached images too.)
[[ "$(crictl pods |grep -v NAME)" ]] && {
    systemctl stop containerd
    sleep 3
    rm -rf /var/lib/containerd
    systemctl start containerd
}
# rm -rf /var/lib/docker
# rm -rf /var/lib/containerd
[[ $(type -t docker) ]] && systemctl start docker
systemctl start kubelet
