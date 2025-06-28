#!/bin/bash
###############################################################################
# firewalld : Kubernetes 
# - Idempotent
#
# ARGs: NETWORK_INTERFACE ZONE_OF_INTERFACE [ANY(to teardown)]
#
# https://docs.oracle.com/en/operating-systems/olcne/1.1/start/ports.html
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/
###############################################################################

[[ "$(id -u)" -ne 0 ]] && {
    echo "❌  ERR : MUST run as root" >&2

    exit 11
}
[[ $2 ]] || {
    echo "❌  ERR : Missing args : Environment is UNCONFIGURED" >&2

    exit 22
}

action(){
    echo "$1" |grep -q -e '\badd\b' -e '\bremove\b' || return 33
    printf $1
}
export -f action

ifc=$1
zone=$2
[[ $3 ]] && teardown=remove
do="$(action ${teardown:-add})"

## Assure firewalld.service is running
systemctl is-active --quiet firewalld ||
    systemctl enable --now firewalld

## Set the default zone that will bind to all internal (ephemeral/CNI) virtual interfaces 
firewall-cmd --set-default-zone=trusted 

## Add zone that binds to the external (domain-facing) interface ($2) of this host
firewall-cmd --get-zones |grep -q "\b$zone\b" ||
    firewall-cmd --new-zone=$zone --permanent

at="--permanent --zone=$zone"

firewall-cmd $at --set-target=DROP  # Drop all packets not explicitly allowed (Whitelisted)
firewall-cmd --set-log-denied=all   # Logging applies to all zones

## @ Host-required services : Add regardless
printf "%s\n" dhcpv6-client dns kerberos ldap ldaps mountd nfs ntp rpc-bind samba ssh \
    |xargs -I{} firewall-cmd $at --add-service={}

## @ Ingress (HTTP/HTTPS)
firewall-cmd $at --$do-service=http
firewall-cmd $at --$do-service=https

## @ ping : Allow ICMP echo-request/reply : Inversion is *required* if zone target is DROP 
firewall-cmd $at --$do-icmp-block-inversion    # Invert so block allows
firewall-cmd $at --$do-icmp-block=echo-request # block (allow) request 
firewall-cmd $at --$do-icmp-block=echo-reply   # block (allow) reply

# @ Pod-Pod and Pod-Service traffic
firewall-cmd $at --$do-forward      # Allow pod-pod traffic, esp. cross-node IP-in-IP
firewall-cmd $at --$do-masquerade   # Allow NAT 

ip_based(){
    
    ## Hardened version : Allow K8s ports only if source is K8s peer
    
    svc_based remove # Remove permissive, service-based rules

    do="$(action $1)" || return 33
    common_tcp='10249 10250 10255 10256 30000-32767'
    control_tcp='2379-2381 6443 10257 10259'
    for ipv4 in $K8S_PEERS; do
        for port in $common_tcp $control_tcp; do
            firewall-cmd $at --$do-rich-rule="rule family=ipv4 source address=$ipv4 port port=$port protocol=tcp accept"
        done
        firewall-cmd $at --$do-rich-rule="rule family=ipv4 source address=$ipv4 port port=30000-32767 protocol=udp accept"
    done
}
svc_based(){

    ## Permissive version : Allow K8s ports regardless of source
    
    ip_based remove # Remove rich-rules of hardened version

    ## Service : K8s common (control and worker)

    do="$(action $1)" || return 33
    svc=k8s-common
    firewall-cmd --get-services |grep $svc ||
        firewall-cmd $at --new-service=$svc

    at="--permanent --zone=$zone --service=$svc"

    firewall-cmd $at --set-description="K8s every node"
    firewall-cmd $at --$do-port=10249/tcp       # kubelet read-only
    firewall-cmd $at --$do-port=10250/tcp       # kubelet API inbound
    firewall-cmd $at --$do-port=10255/tcp       # kubelet Node/Pod CIDRs (v1.23.6+)
    firewall-cmd $at --$do-port=10256/tcp       # GKE LB Health checks
    firewall-cmd $at --$do-port=30000-32767/tcp # NodePort Services inbound 
    firewall-cmd $at --$do-port=30000-32767/udp # NodePort Services inbound
    ##... Our K8s NodePort range (default) is *outside* of IANA-registered ranges and 
    ##    just *below* that of Linux/RHEL (default) Ephemeral ports (32768–60999) AKA Local ports, 
    ##    which is for host's (short-lived) network connections, e.g., UDP/TCP/HTTP(S) traffic:
    ##        $ cat /proc/sys/net/ipv4/ip_local_port_range # Print the ephemeral-ports range
    ##        $ sysctl net.ipv4.ip_local_port_range        # Print the ephemeral-ports range

    ## @ Metrics
    firewall-cmd $at --$do-port=9100/tcp        # Node exporter
    firewall-cmd $at --$do-port=9153/tcp        # CoreDNS metrics

    firewall-cmd --permanent --zone=$zone --$do-service=$svc

    ## Service : K8s Control nodes

    svc=k8s-control
    at="--permanent --zone=$zone"
    firewall-cmd --get-services |grep $svc ||
        firewall-cmd $at --new-service=$svc

    at="--permanent --zone=$zone --service=$svc"

    firewall-cmd $at --set-description="K8s Control node"
    firewall-cmd $at --$do-port=2379-2380/tcp   # etcd, kube-apiserver inbound
    firewall-cmd $at --$do-port=2381/tcp        # etcd non-default
    firewall-cmd $at --$do-port=6443/tcp        # kube-apiserver inbound
    firewall-cmd $at --$do-port=10257/tcp       # kube-controller-manager inbound   (10252/tcp @ v1.17-)
    firewall-cmd $at --$do-port=10259/tcp       # kube-scheduler inbound            (10259/tcp @ v1.17-)

    firewall-cmd --permanent --zone=$zone --$do-service=$svc
}
export -f ip_based
export -f svc_based

svc_based $do || {
    echo "❌  ERR : $? : '$do'" >&2

    exit 44
}

## Bind interface to zone so rules of such *active* zone apply to that interface.
## - Do so at NetworkManager.service (by nmcli) rather than at firewalld.service 
##   (by "firewall-cmd $at --change-interface=$ifc"), else the affect will not persist 
##   unless consistent with the pre-existing NetworkManager cfg, which *overrules* firewalld. 
##   This method precludes that (silent, delayed) fail mode.
## - Apply all firewalld rules if desired ifc-zone binding either already existed or succeeds here.
nmcli con show "$ifc" |grep connection.zone |grep -q "\b$zone\b" && firewall-cmd --reload || {
nmcli con modify "$ifc" connection.zone $zone &&
    nmcli con down "$ifc" &&
        nmcli con up "$ifc" &&
            firewall-cmd --reload
}

## Verify our zone is active by our interface being bound to it.
z="$(firewall-cmd --get-zone-of-interface=$ifc)"
[[  "$z" == "$zone" ]] || {
    echo "❌️  ERR : Zone of interface '$ifc' is '$z' NOT '$zone'"

    exit 99
}
