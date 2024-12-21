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

# Delete residual Pods
obj="$(sudo crictl pods -q)"
echo "$obj" |xargs -I{} crictl stopp {}
echo "$obj" |xargs -I{} crictl rmp {}
[[ $obj ]] && echo 'RESIDUAL Pods' && sleep 22

# Delete residual containers
obj="$(sudo crictl ps -q)"
echo "$obj" |xargs -I{} crictl stop {}
echo "$obj" |xargs -I{} crictl rm {}
[[ $obj ]] && echo 'RESIDUAL containers' && sleep 22

# Delete CRDs
kubectl get crds |grep -v NAME |cut -d' ' -f1 \
    |xargs -I{} kubectl delete crds {}

# Reset kubeadm installed state
kubeadm reset -f 2>/dev/null

# Stop kubelet and all Kubernetes related processes
systemctl stop kubelet #|| exit 22
[[ $(type -t docker) ]] && systemctl stop docker
systemctl stop containerd #|| exit 33

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
printf "%s\n" $dev |xargs -n1 /bin/bash -c 'rem $1 2>/dev/null' _

# Flush iptables : filter, nat, and mangle
iptables --flush
iptables --delete-chain
iptables -t nat --flush
iptables -t nat --delete-chain
iptables -t mangle --flush
iptables -t mangle --delete-chain

# Cleanup nftables
cni='cali cilium kube'
for name in $cni;do
    nft list table ip raw \
        |grep -io "chain $name-[^ ]*" \
        |awk '{print $2}' \
        |xargs -I{} nft delete chain ip raw "{}"
done 
# Persist 
#nft list ruleset > /etc/nftables.conf
#systemctl restart nftables

# Clear IPVS tables
[[ $(type -t ipvsadm) ]] && ipvsadm --clear

# Clear CNI configuration
rm -rf /etc/cni/net.d
rm -rf /var/{lib,run}/{cni,calico,cilium,kube-router}

# Clear remaining kubelet files
rm -rf /var/lib/kubelet

# Last resort to delete all pods : delete entire containerd store.
# (This deletes all pulled/cached images too.)
[[ $(crictl pods |grep -v NAME) ]] && rm -rf /var/lib/containerd
# rm -rf /var/lib/docker
# rm -rf /var/lib/containerd

systemctl start containerd
[[ $(type -t docker) ]] && systemctl start docker
systemctl start kubelet
