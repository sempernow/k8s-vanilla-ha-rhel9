#!/usr/bin/env bash

## Any to force hard teardown regardless
hard=$1

[[ "$(whoami)" == 'root' ]] || exit 11

export PATH="/usr/local/bin:$PATH"
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl --kubeconfig=$KUBECONFIG get --raw /healthz && {
    helm list -A --no-headers 2>&1 |grep -ve WARN -ve Error \
        |xargs -IX /bin/bash -c 'helm uninstall --timeout 15s --wait -n $2 $1' _ X

    kubectl get node --no-headers 2>&1 |grep -v refused |cut -d' ' -f1 \
        |xargs -I{} kubectl drain --force --grace-period=1 --timeout=15s --wait -ignore-daemonsets=true --delete-emptydir-data=true {}

    kubectl get crds --no-headers 2>&1 |grep -v refused |cut -d' ' -f1 \
        |xargs -I{} kubectl delete crds --grace-period=1 --timeout=15s --wait {}
    
    sleep 10
}

## Delete static-pod manifests of K8s control plane, and allow kubelet to terminate their pods
[[ $(find /etc/kubernetes/manifests -type f -exec rm -f {} \+) ]] && sleep 20

[[ $(systemctl is-active containerd) == 'active' ]] ||
    (systemctl start containerd && sleep 5)

## Delete residual containers
obj="$(crictl ps -q 2>&1 |grep -v Error)"
echo "$obj" |xargs -I{} /bin/bash -c 'crictl stop $1 && crictl rm $1' _ {}
[[ "$obj" ]] && sleep 5

## Delete residual Pods if able
test="$(crictl pods -q 2>&1 |grep -v Error |tail -n1)"
crictl stopp $test && crictl rmp $test &&
    echo "$(crictl pods -q 2>&1 |grep -v Error)" \
        |xargs -I{} /bin/bash -c 'crictl stopp $1 && crictl rmp $1' _ {}

## If pods remain, then hard teardown is required (regardless of $1) to prepare host for kubeadm init 
[[ $(crictl pods -q) ]] && hard=yes 

echo "🛠️  Performing kubeadm reset"
kubeadm reset -f 2>/dev/null
## Clear all configuration
rm -rf /etc/cni/net.d /etc/kubernetes
rm -rf /var/{lib,run}/{cni,calico,cilium,kube-router}
rm -rf /var/lib/{kubelet,kube-scheduler,kube-controller-manager,etcd,containerd,docker}
## Done unless hard
[[ "$hard" ]] || exit 0

echo "⚠️  Performing HARD teardown!"

## Stop kubelet and all Kubernetes related processes
systemctl stop kubelet #|| exit 22
[[ $(type -t docker) ]] && systemctl stop docker
systemctl stop containerd #|| exit 33
rm -rf /run/containerd

## Delete rook-ceph Network Block Devices 
# [[ -d /dev/ndb ]] && {
#     type -t qemu-nbd || dnf install -y qemu-nbd
#     for nbd in /dev/nbd*; do
#         qemu-nbd --disconnect $nbd
#     done
# }
## Delete rook-ceph state
# rm -rf /var/lib/rook
# ## Wipe rook-ceph block device 
# rbd=sdb # VERIFY THIS FIRST
# sudo wipefs --all /dev/$rdb && sudo dd if=/dev/zero of=/dev/$rbd bs=1M count=10

## If using etcd in a dedicated directory (for external etcd)
# rm -rf /var/lib/etcd

## Remove virtual network interfaces
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
# systemctl stop iptables
systemctl disable --now nftables

## Flush iptables : filter, nat, and mangle
# iptables --flush
# iptables --delete-chain
# iptables -t nat --flush
# iptables -t nat --delete-chain
# iptables -t mangle --flush
# iptables -t mangle --delete-chain

## Cleanup nftables
# nft flush ruleset # Dangerous to others
cni='cni cali cilium kube'
tables='raw nat filter'
for table in $tables; do
    ## Check if the table exists
    if nft list table ip "$table" >/dev/null 2>&1; then
        for name in $cni; do
            nft list table ip "$table" \
                | grep -io "chain $name-[^ ]*" \
                | awk '{print $2}' \
                | while read -r chain; do
                    ## Double-check before deleting
                    if [ -n "$chain" ]; then
                        nft delete chain ip "$table" "$chain"
                    fi
                done
        done
    fi
done

## Persist 
# nft list ruleset > /etc/nftables.conf

systemctl enable --now nftables
# systemctl start iptables
systemctl enable --now firewalld

## Clear IPVS tables
[[ $(type -t ipvsadm) ]] && ipvsadm --clear

## Prepare for kubeadm init
systemctl start containerd
[[ $(type -t docker) ]] && systemctl start docker
systemctl start kubelet
