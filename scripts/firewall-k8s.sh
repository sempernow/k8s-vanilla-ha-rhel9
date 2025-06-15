#!/bin/bash
###############################################################################
# firewalld : Kubernetes 
# - Idempotent
#
# ARGs: NETWORK_INTERFACE ZONE_OF_INTERFACE
#
# https://docs.oracle.com/en/operating-systems/olcne/1.1/start/ports.html
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/
###############################################################################

[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠  ERR : MUST run as root" >&2

    exit 11
}
[[ $2 ]] || {
    echo "⚠  ERR : Missing args : Environment is UNCONFIGURED" >&2

    exit 22
}
ifc=$1
zone=$2


#[[ -f /etc/sysconfig/network-scripts/ifcfg-$ifc ]]

## Assure firewalld.service is running
systemctl is-active --quiet firewalld ||
    systemctl enable --now firewalld

## Set zone of (CNI) virtual interfaces 
firewall-cmd --set-default-zone=trusted

## Add and configure zone of a bound interface ($2)
firewall-cmd --get-zones |grep -q "\b$zone\b" || {
    firewall-cmd --new-zone=$zone --permanent
}

at="--permanent --zone=$zone"

#firewall-cmd --zone=public --list-icmp-blocks          # Show any ICMP that are blocked
firewall-cmd --zone=$zone --query-icmp-block=echo-request &&
    firewall-cmd $at --remove-icmp-block=echo-request   # Allow incoming ping if not already
firewall-cmd $at --add-forward                          # Allow pod-pod traffic, esp. cross-node IP-in-IP
firewall-cmd $at --add-masquerade                       # Allow NAT
firewall-cmd $at --set-target=DROP                      # Drop all packets lest declared allowed (Whitelist)
firewall-cmd --set-log-denied=all                       # Logging applies to all zones

## @ Host-required services
printf "%s\n" dhcpv6-client dns kerberos ldap ldaps mountd nfs ntp rpc-bind samba ssh \
    |xargs -I{} firewall-cmd $at --add-service={}

## @ Ingress (HTTP/HTTPS)
firewall-cmd $at --add-service=http
firewall-cmd $at --add-service=https

## @ Common (control/worker)
svc=k8s-common
firewall-cmd --get-services |grep $svc ||
    firewall-cmd $at --new-service=$svc
at="--permanent --zone=$zone --service=$svc"
firewall-cmd $at --set-description="K8s every node"
firewall-cmd $at --add-port=443/tcp         # kube-apiserver inbound
firewall-cmd $at --add-port=10250/tcp       # kubelet API inbound
firewall-cmd $at --add-port=10255/tcp       # kubelet Node/Pod CIDRs (v1.23.6+)
firewall-cmd $at --add-port=10256/tcp       # GKE LB Health checks
firewall-cmd $at --add-port=30000-32767/tcp # NodePort Services inbound

## @ "sudo journalctl --since='5 minute ago' |grep DROP" at all nodes report these two (DPT) ports 
firewall-cmd $at --add-port=10249/tcp       # kubelet read-only port
firewall-cmd $at --add-port=2381/tcp        # etcd non-default

## @ Kubernetes v1.17-
#firewall-cmd $at --add-port=10251/tcp      # kube-scheduler (moved to 10259)
#firewall-cmd $at --add-port=10252/tcp      # kube-controller-manager (moved to 10257)

## @ Metrics
firewall-cmd $at --add-port=9100/tcp        # Node exporter
firewall-cmd $at --add-port=9153/tcp        # CoreDNS metrics

firewall-cmd --permanent --zone=$zone --add-service=$svc

## @ Control nodes
svc=k8s-control
at="--permanent --zone=$zone"
firewall-cmd --get-services |grep $svc ||
    firewall-cmd $at --new-service=$svc
at="--permanent --zone=$zone --service=$svc"
firewall-cmd $at --set-description="K8s Control node"
firewall-cmd $at --add-port=2379-2380/tcp   # etcd, kube-apiserver inbound
firewall-cmd $at --add-port=6443/tcp        # kube-apiserver inbound
firewall-cmd $at --add-port=10257/tcp       # kube-controller-manager inbound
firewall-cmd $at --add-port=10259/tcp       # kube-scheduler inbound
## @ Kubernetes v1.17-
#firewall-cmd $at --add-port=10252/tcp      # kube-controller-manager (moved to 10257)
#firewall-cmd $at --add-port=10251/tcp      # kube-scheduler (moved to 10259)

firewall-cmd --permanent --zone=$zone --add-service=$svc

## Bind interface to zone at NetworkManager.service if not already; apply firewalld mods regardless 
nmcli con show "$ifc" |grep connection.zone |grep -q "\b$zone\b" && firewall-cmd --reload || {
nmcli con modify "$ifc" connection.zone $zone &&
    nmcli con down "$ifc" &&
        nmcli con up "$ifc" &&
            firewall-cmd --reload
}

#firewall-cmd $at --change-interface=$ifc
z="$(firewall-cmd --get-zone-of-interface=$ifc)"
[[  "$z" == "$zone" ]] || {
    echo "⚠  ERR : Zone of interface '$ifc' is '$z' NOT '$zone'"

    exit 99
}
