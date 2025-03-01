#!/usr/bin/env bash
########################################################################
# Provision NFSv4.2 server for clients on CIDR
#
# https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/deploying-an-nfs-server_deploying-different-types-of-servers
#
# ARGs: SERVER_HOST  CLIENT_CIDR
########################################################################
[[ "$2" ]] || exit 1
[[ "$1" =~ $(hostname) ]] || exit 2
[[ "$(id -un)" == 'root' ]] || exit 3

systemctl list-unit-files |grep 'nfs-server.service' ||
    dnf update &&
        dnf -y install nfs-utils

# Configure to serve NFSv3 and NFSv4.2 only (idempotent)
sedfile=/tmp/etc.nfs.conf.sed
cat <<EOH |tee $sedfile
/vers3=/c\vers3=y
/vers4=/c\# vers4=y
/vers4.0=/c\vers4.0=n
/vers4.1=/c\vers4.1=n
/vers4.2=/c\vers4.2=y
EOH
sed -i -f $sedfile /etc/nfs.conf
rm -f $sedfile

# Disable NFSv3 : May also disable NFSv4 at clients !!!
# systemctl mask --now rpc-statd.service rpcbind.service rpcbind.socket

# if NFSv4 *only*, then configure rpc.mountd (once) to not listen for NFSv3 mount requests.
# dir=/etc/systemd/system/nfs-mountd.service.d/
# [[ -f $dir/v4only.conf ]] || {
# 	mkdir -p $dir
# 	cat <<-EOH |tee $dir/v4only.conf
# 	[Service]
# 	ExecStart=
# 	ExecStart=/usr/sbin/rpc.mountd --no-tcp --no-udp
# 	EOH
# }

# Uncomment/Re-declare domain at /etc/idmapd.conf
sed -i '/^\(#\)\?Domain = /c\Domain = lime.lan' /etc/idmapd.conf

# Configure the share
share=/mnt/nfs_01
mkdir -p $share/
chgrp 'ad-linux-users' $share/

# Set ACLs and such so that owner:group of all current and new dirs/files 
# have same access, and are owned by whichever user created it.
# And deny any access to other.
# (directory mode 2770, and file mode 0660)
chmod -R 2770 $share/
setfacl -m d:u::rwx $share
setfacl -m d:g::rwx $share
setfacl -m d:o::--- $share

# Configure nfsanon (anonuid,anongid) as UID:GID of all orphaned dirs/files .
# NFSv3 supports this; NFSv4 does not, purportedly (untested)
id=50000
name=nfsanon
groupadd -g $id $name
useradd -u $id -g $name -s /sbin/nologin -d /dev/null $name

exports=/etc/exports
cidr1="$2"
cat <<EOH |tee $exports
# NFSv4
#$share    $cidr1(rw,sync,sec=krb5,root_squash)

# NFSv3
#$share    $cidr1(rw,sync,sec=krb5,root_squash,no_subtree_check,anonuid=$id,anongid=$id)
$share    $cidr1(rw,sync,root_squash,no_subtree_check,anonuid=$id,anongid=$id)
EOH

systemctl enable --now firewalld
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload

exportfs -ra
systemctl daemon-reload
systemctl restart nfs-mountd
systemctl enable --now nfs-server

vers="$(cat /proc/fs/nfsd/versions)"
[[ "$vers" =~ '+3 +4 -4.0 -4.1 +4.2' ]] &&
    echo ok ||
        echo "/proc/fs/nfsd/versions : $vers"

exportfs -v
#/mnt/nfs_01     192.168.11.0/24(sync,wdelay,hide,no_subtree_check,anonuid=50000,anongid=50000,sec=sys,rw,secure,root_squash,no_all_squash)