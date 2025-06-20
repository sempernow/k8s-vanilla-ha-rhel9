#!/usr/bin/env bash
#!/bin/bash
###############################################################################
# firewalld : Calico
# - Idempotent
#
# ARGs: NETWORK_INTERFACE ZONE_OF_INTERFACE LIST_OF_PEERS_IPV4
#
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
# https://docs.tigera.io/calico/latest/reference/typha/overview
###############################################################################
set -uo pipefail

[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠  ERR : MUST run as root" >&2

    exit 11
}
[[ $3 ]] || {
    echo "⚠  ERR : Missing args : Environment is UNCONFIGURED" >&2

    exit 22
}
ifc=$1
zone=$2
peers="$3"

[[ $(systemctl is-active firewalld.service) == 'active' ]] ||
    systemctl enable --now firewalld.service

p4LockDown(){
    ## Protocol 4 is required by Calico IPIP mode (encapsulation), 
    ## yet it can be used to bypass normal (tcp/udp) rules,
    ## so lock it down using Rich Rules; allow it only between K8s peers on this interface (zone).
    at="--permanent --zone=$zone"
    # For each peer (k8s) node 
    printf "%s\n" $peers \
        |xargs -I{} firewall-cmd $at --add-rich-rule='rule protocol value="4" source address="'{}'" accept'
    # Drop all other protocol 4 traffic
    firewall-cmd $at --add-rich-rule='rule protocol value="4" drop'
}
at="--permanent --zone=$zone"
firewall-cmd $at --add-protocol=4       # Allow IP-in-IP : WARNING : can bypass normal (tcp/udp) rules
#p4LockDown                             # Allow IP-in-IP only betwen K8s peers

svc=calico
firewall-cmd --get-services |grep $svc ||
    firewall-cmd $at --new-service=$svc
at="--permanent --zone=$zone --service=$svc"
firewall-cmd $at --set-description="Calico : BGP, VXLAN, Typha agent hosts, Wireguard"
firewall-cmd $at --add-port=179/tcp     # BGP (Calico)
firewall-cmd $at --add-port=4789/udp    # VXLAN (Calico/Flannel)
firewall-cmd $at --add-port=5473/tcp    # Calico Typha agent hosts
firewall-cmd $at --add-port=51820/udp   # Wireguard (Calico)
firewall-cmd $at --add-port=51821/udp   # Wireguard (Calico)
firewall-cmd $at --add-port=9099/tcp    # Health check

firewall-cmd --permanent --zone=$zone --add-service=$svc

firewall-cmd --reload
