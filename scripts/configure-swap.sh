#!/usr/bin/env bash
#####################################################
# Configure swap volumes : disable all (idempotent)
#
# >>>  DO NOT disable swap.target (static)  <<<
#####################################################

ok(){
    # Disable swap now and forever (idempotent)
    ## Disable all swaps of /proc/swaps
    sudo swapoff -a || return 10  
    #sudo swapon --show
    [[ -r /etc/fstab ]] || return 11
    isOn(){ 
        echo "$(cat /etc/fstab |grep ' swap' |grep -v '^ *#' |awk '{print $1}')"
    }
    swap="$(isOn)";unset device
    [[ $swap ]] && device="$(echo $swap |awk '{print $1}')"
    [[ $device ]] && sudo sed -i "s,$swap,#$swap," /etc/fstab
    [[ $(isOn) ]] && return 1 || return 0
}
ok || exit $?

echo ok

exit 0
######

cat /etc/fstab |grep swap
## To find a particular swap, use lsblk 
lsblk

## @ /etc/fstab (Unconfigured example)
    /dev/mapper/almalinux-root  /          xfs     defaults                   0 0
    UUID=0ef0e28d-a54d-4cd6     /boot      xfs     defaults                   0 0
    UUID=B872-847F              /boot/efi  vfat    umask=0077,shortname=winnt 0 2
    /dev/mapper/almalinux-swap  none       swap    defaults                   0 0
