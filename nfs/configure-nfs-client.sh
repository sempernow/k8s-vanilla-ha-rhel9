#!/usr/bin/env bash
########################################################################
# Configure NFSv4.2 client 
#
# https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/deploying-an-nfs-server_deploying-different-types-of-servers
#
# ARGs: SERVER_FQDN_OR_IPv4 SERVER_MOUNT LOCAL_MOUNT
########################################################################
[[ "$3" ]] || exit 1
[[ "$(id -un)" == 'root' ]] || exit 3

systemctl list-unit-files |grep 'nfs-server.service' ||
    dnf update &&
        dnf -y install nfs-utils krb5-workstation

id=50000
name=nfsanon
getent group $name || groupadd -g $id $name
id $name || useradd -u $id -g $name -s /sbin/nologin -d /dev/null $name

# Mount
nfs_srv=$1
nfs_mnt=$2
local_mnt=$3
unset krb
#krb=',sec=krb5'
mkdir -p $local_mnt
# Temporarily
#mount -t nfs4 -o vers=4.2 $nfs_srv:$nfs_mnt/ $local_mnt/
# Persistently : Add to fstab (once)
# NFSv4 : Does *not* abide server's anonymous UID:GID settings (anonuid,anongid)
# grep "$nfs_srv:$nfs_mnt" /etc/fstab ||
#     echo "$nfs_srv:$nfs_mnt $local_mnt nfs4 defaults,vers=4.2,_netdev,auto$krb 0 0" |tee -a /etc/fstab
# NFSv3 : Does abide server's anonymous UID:GID settings (anonuid,anongid)
grep "$nfs_srv:$nfs_mnt" /etc/fstab ||
    echo "$nfs_srv:$nfs_mnt $local_mnt nfs defaults,vers=3,_netdev,auto$krb 0 0" |tee -a /etc/fstab

systemctl daemon-reload
mount -a

mount |grep nfs





