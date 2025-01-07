#!/usr/bin/env bash
######################################
# Install RPMs : K8s deps and tools
######################################
ok(){
    # K8s dependency
    sudo dnf -y install conntrack
    # Tools
    all='yum-utils dnf-plugins-core gcc make ansible ansible-core iproute-tc bash-completion bind-utils tar nc socat rsync lsof wget curl net-tools tcpdump traceroute nmap traceroute nc arp-scan git httpd httpd-tools jq vim tree htop sysstat fio pciutils'
    sudo dnf -y install $all

}
ok || exit $?