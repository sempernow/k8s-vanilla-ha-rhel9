#!/bin/bash
###############################################################################
# firewalld : Kubernetes 
# - Idempotent
#
# https://docs.oracle.com/en/operating-systems/olcne/1.1/start/ports.html
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/
###############################################################################

[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠️  ERR : MUST run as root" >&2

    exit 11
}
zone=k8s-pod

## Assure firewalld.service is running
systemctl is-active --quiet firewalld ||
    systemctl enable --now firewalld

## Add zone that binds to all interfaces not explicitly bound to another
firewall-cmd --get-zones |grep -q "\b$zone\b" || {
    firewall-cmd --new-zone=$zone --permanent
}

## Set the default zone that will bind to all internal (ephemeral/CNI) virtual interfaces 
firewall-cmd --set-default-zone=$zone

at="--permanent --zone=$zone"

## Allow all Pod and Service (CIDRs) traffic
## As long as no port is declared in a rich rule, then all are allowed.
firewall-cmd $at --add-rich-rule='rule family=ipv4 source address='$K8S_POD_CIDR' accept'
firewall-cmd $at --add-rich-rule='rule family=ipv6 source address='$K8S_POD_CIDR6' accept'
firewall-cmd $at --add-rich-rule='rule family=ipv4 destination address='$K8S_SERVICE_CIDR' accept'


## Allow outbound traffic via NAT (e.g., IP-in-IP tunneling) and all internal Pod-Service routing.
firewall-cmd $at --add-forward
firewall-cmd $at --add-masquerade

## Allow ICMP for ping request/reply 
firewall-cmd $at --add-icmp-block-inversion    # Remove if inverted
firewall-cmd $at --add-icmp-block=echo-request # Allow request 
firewall-cmd $at --add-icmp-block=echo-reply   # Allow reply

## Permissive on these declared CIDRs
firewall-cmd $at --set-target=DROP

firewall-cmd --reload
