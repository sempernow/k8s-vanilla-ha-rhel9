#!/usr/bin/env bash
########################################
# Configure kernel for K8s CRI and CNI
# - Idempotent
########################################

# Install kernel headers 
rpm -q kernel-headers || sudo dnf -y install kernel-headers-$(uname -r) || exit 10
rpm -q kernel-devel   || sudo dnf -y install kernel-devel-$(uname -r)   || exit 11

unset _flag_config_kernel

ok(){
    # Load kernel modules now (okay if already loaded) else fail
    sudo modprobe br_netfilter  
    [[ $(lsmod |grep br_netfilter) ]] || return 21

    sudo modprobe overlay  
    [[ $(lsmod |grep overlay) ]] || return 22

    sudo modprobe ip_vs  
    [[ $(lsmod |grep ip_vs) ]] || return 23

    sudo modprobe ip_vs_rr  
    [[ $(lsmod |grep ip_vs_rr) ]] || return 24

    sudo modprobe ip_vs_wrr  
    [[ $(lsmod |grep ip_vs_wrr) ]] || return 25
    
    sudo modprobe ip_vs_sh  
    [[ $(lsmod |grep ip_vs_sh) ]] || return 26

    # Load kernel modules on boot
    conf=/etc/modules-load.d/kubernetes.conf
    [[ $(cat $conf 2>/dev/null |grep overlay) ]] && return 0
    ## br_netfilter enables transparent masquerading 
    ## and facilitates VxLAN traffic between Pods.
	cat <<-EOH |sudo tee $conf
	br_netfilter
	ip_vs
	ip_vs_rr
	ip_vs_wrr
	ip_vs_sh
	overlay
	EOH
    [[ $(cat $conf 2>/dev/null |grep overlay) ]] || return 33
    _flag_config_kernel=1
}
ok || exit $?

ok(){
    # Set kernel runtime params (sysctl) for K8s networking
    conf='/etc/sysctl.d/kubernetes.conf'
    [[ $(cat $conf 2>/dev/null |grep 'net.bridge.bridge-nf-call-iptables  = 1') ]] && return 0
	cat <<-EOH |sudo tee $conf
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-iptables  = 1
	net.ipv4.ip_forward                 = 1
	EOH
    # |Kernel Parameter	                    | Description                      |
    # |-------------------------------------|----------------------------------|
    # |`net.bridge.bridge-nf-call-iptables` |Bridged IPv4 traffic via iptables.|
    # |`net.bridge.bridge-nf-call-ip6tables`|Bridged IPv6 traffic via iptables.|
    # |`net.ipv4.ip_forward`                |IPv4 packet forwarding.           |

    [[ $(cat $conf 2>/dev/null |grep 'net.bridge.bridge-nf-call-iptables  = 1') ]] || return 44

    _flag_config_kernel=1
}
ok || exit $?
    
# If configuration changed, then apply settings else fail
[[ $_flag_config_kernel ]] && {
    sudo sysctl --system |grep Applying || exit 99
}

[[ $(sysctl net.ipv4.ip_forward |cut -d' ' -f3- |grep '1') ]] || exit 999
