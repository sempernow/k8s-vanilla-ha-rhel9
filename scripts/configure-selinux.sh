#!/usr/bin/env bash
###########################################################
# SELinux : Set to Permissive|Enforcing (now and persist)
# - Idempotent
# ARGs: [Enforcing|Permissive(Default)]
###########################################################
disabled=$(cat /etc/selinux/config |grep SELINUX=disabled)
permissive=$(cat /etc/selinux/config |grep SELINUX=permissive)
enforcing=$(cat /etc/selinux/config |grep SELINUX=enforcing)

p(){
    [[ $enforcing || $disabled ]] || return
    sudo setenforce 0 # set to Permissive : Unreliable and does NOT persist.
    sudo sed -i -e 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
    sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
}
e(){
    [[ $permisive || $disabled ]] || return
    sudo setenforce 1 # set to Enforcing : Unreliable and does NOT persist.
    sudo sed -i -e 's/^SELINUX=disabled/SELINUX=eforcing/' /etc/selinux/config
    sudo sed -i -e 's/^SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
}
export -f p
export -f e

have=$(getenforce)

[[ $1 && $(echo $1 |grep -i enforc) ]] && e || p

want=$(getenforce)

getenforce 

[[ $have == $want ]] &&
    echo '=== NO CHANGE to SELinux config' ||
        echo '=== REBOOT required for some SELinux CHANGEs to take effect.'
