#!/usr/bin/env bash
######################################
# Install RPMs : K8s deps and tools
######################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠️  ERR : MUST run as root" >&2

    exit 11
}

ok(){
    # K8s dependency
    dnf -y --color=never install conntrack || return 22

    # Tools
    all='
    dnf-plugins-core
    selinux-policy-targeted 
    libselinux-utils
    policycoreutils
    setroubleshoot-server
    policycoreutils-python-utils
    gcc 
    make 
    ansible 
    ansible-core 
    iproute-tc 
    bash-completion 
    bind-utils 
    tar 
    nc 
    socat 
    rsync 
    lsof 
    wget 
    curl 
    net-tools 
    tcpdump 
    traceroute 
    nmap 
    arp-scan 
    git 
    httpd 
    httpd-tools 
    jq 
    vim 
    tree 
    htop 
    sysstat 
    fio 
    pciutils
    '
    dnf -y --color=never install $all || return 44
}
ok || exit $?