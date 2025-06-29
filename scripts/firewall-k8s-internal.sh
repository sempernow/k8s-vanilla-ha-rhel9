#!/usr/bin/env bash
###############################################################################
# firewalld (Linux host firewall) regarding K8s-internal traffic :
#
# A "default" firewalld zone binds to all *new* adapters of K8s-CNI plugin.
# These are isolated, virtual, ephemeral interfaces created, destroyed, 
# and otherwise managed per Pod by the CNI plugin (Calico, Cilium, ...).
# All Pod and Service (CIDRs) traffic traverses these adapters.
# 
# This script creates an apropos zone for all K8s-internal traffic, 
# and persists that as the "default" zone of firewalld.
# 
# - Idempotent.
#
# This scheme presumes another zone *explicitly* binds to the host's 
# *external* (domain-facing) adapter, and has apropos rules regarding 
# K8s-external inbound host traffic (from external clients and such).
#
# REQUIREMENTS:
# - These virtual adapters are "unmanaged" by NetworkManager (nmcli).
#     - This occurs without intervention at RHEL8+. 
#     - Verify by unprivileged execution of "nmcli dev status".
# 
# ARGs: ZONE  POD_CIDR  SERVICE_CIDR  [ANY(to teardown)]
#
# https://docs.oracle.com/en/operating-systems/olcne/1.1/start/ports.html
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/
###############################################################################

[[ "$(id -u)" -ne 0 ]] && {
    echo "❌  ERR : MUST run as root" >&2

    exit 11
}
[[ -n $1 ]] || {
    echo "❌  ERR : Missing args : Environment is UNCONFIGURED" >&2

    exit 22
}
export zone=$1
export podCIDR="$2"
export svcCIDR="$3"
[[ -n $4 ]] &&
    export do='remove' ||
        export do='add'

## Assure firewalld.service is running; persist otherwise.
systemctl is-active --quiet firewalld ||
    systemctl enable --now firewalld

export at="--permanent --zone=$zone"

[[ $do == 'add' ]] && {

    ## Add zone that binds to all *new* interfaces
    firewall-cmd --get-zones |grep -q "\b$zone\b" || {
        firewall-cmd --new-zone=$zone --permanent &&
            firewall-cmd --reload
    }

    firewall-cmd $at --set-target=DROP  # Drop all packets not explicitly allowed (Whitelisted)
    firewall-cmd --set-log-denied=all   # Logging applies to all zones

    ## Allow outbound traffic via NAT (e.g., IP-in-IP tunneling) and all internal Pod-Service routing.
    firewall-cmd $at --$do-forward
    firewall-cmd $at --$do-masquerade

    ## Set to default zone; will bind to all (internal, virtual, ephemeral) 
    ## interfaces created by the K8s CNI plugin (Calico, Cilium, ...).
    firewall-cmd --set-default-zone=$zone
}

## Allow all Pod and Service (CIDRs) traffic
## If rich-rule has no declared port, then all are allowed on that address.
firewall-cmd $at --$do-rich-rule='rule family=ipv4 source address='$podCIDR' accept'
#firewall-cmd $at --$do-rich-rule='rule family=ipv6 source address='$K8S_POD_CIDR6' accept'
firewall-cmd $at --$do-rich-rule='rule family=ipv4 destination address='$svcCIDR' accept'
#firewall-cmd $at --$do-rich-rule='rule family=ipv6 destination address='$K8S_SERVICE_CIDR6' accept'

## Allow ICMP for ping request/reply 
firewall-cmd $at --$do-icmp-block-inversion    # Remove if inverted
firewall-cmd $at --$do-icmp-block=echo-request # Allow request 
firewall-cmd $at --$do-icmp-block=echo-reply   # Allow reply

firewall-cmd --reload

firewall-cmd --get-default-zone |grep -q "\b$zone\b" || {
    echo "❌️  ERR : The default zone is NOT '$zone'"

    exit 99
}
