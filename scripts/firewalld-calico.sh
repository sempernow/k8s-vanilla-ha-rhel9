#!/usr/bin/env bash
#!/bin/bash
###############################################################################
# firewalld : Calico
# - Idempotent
#
# ARGs: NETWORK_INTERFACE ZONE_OF_INTERFACE
#
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
# https://docs.tigera.io/calico/latest/reference/typha/overview
###############################################################################
set -uo pipefail

[[ "$(id -u)" -ne 0 ]] && {
    echo "  ERR : MUST run as root" >&2

    exit 11
}
[[ $2 ]] || exit 22
ifc=$1
zone=$2

[[ $(systemctl is-active firewalld.service) == 'active' ]] ||
    systemctl enable --now firewalld.service

svc=calico
at="--permanent --zone=$zone"
firewall-cmd --get-services |grep $svc ||
    firewall-cmd $at --new-service=$svc
set -e
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
