#!/usr/bin/env bash
###########################################################
# SELinux : Set to Permissive|Enforcing (now and forever)
# - Idempotent
# ARGs: [Enforcing|Permissive(default)]
###########################################################
e(){
    [[ $(cat /etc/selinux/config |grep -e '^SELINUX=permissive' -e '^SELINUX=disabled') ]] \
        || return 0 

    echo '=== SELinux : Set to Enforcing'
    sudo setenforce 1 # Unreliable and does NOT persist.
    sudo sed -i -e 's/^SELINUX=disabled/SELINUX=eforcing/' /etc/selinux/config
    sudo sed -i -e 's/^SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

    return $?
}
p(){
    [[ $(cat /etc/selinux/config |grep -e '^SELINUX=enforcing' -e '^SELINUX=disabled') ]] \
        || return 0

    echo '=== SELinux : Set to Permissive'
    sudo setenforce 0 # Unreliable and does NOT persist.
    sudo sed -i -e 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
    sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

    return $?
}
export -f e
export -f p

if [[ $(echo "$1" |grep -i enforc) ]]
    then e
    else p
fi 
code=$?
(( $code )) || echo ok

exit $code

#sestatus |grep 'SELinux status' # service status
#getenforce

#echo '=== REBOOT may be REQUIRED for SELinux changes to take effect.'


