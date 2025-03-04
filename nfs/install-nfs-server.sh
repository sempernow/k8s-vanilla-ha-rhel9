#!/usr/bin/env bash
########################################################################
# Provision NFSv4.2 server for clients on CIDR
#
# https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/deploying-an-nfs-server_deploying-different-types-of-servers
#
# ARGs: SERVER_MOUNT  CLIENT_CIDR
########################################################################
[[ "$2" ]] || exit 1
[[ "$(id -un)" == 'root' ]] || exit 3
share=$1
cidr="$2"
systemctl is-active nfs-server.service || {
    dnf update &&
        dnf -y install nfs-utils rpcbind krb5-workstation
}

# Configure to serve only NFSv3 and NFSv4.2 (idempotent)
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

# Disable NFSv3 : May also disable NFSv4 at clients 
#systemctl mask --now rpc-statd.service rpcbind.service rpcbind.socket
# Undo the mask
#systemctl unmask rpc-statd.service rpcbind.service rpcbind.socket
#systemctl enable --now rpc-statd.service rpcbind.service rpcbind.socket

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

# Configuring idmap is not necessary if joined to domain using realm and sssd
# @ /etc/idmapd.conf : Uncomment/Re-declare Domain
#sed -i '/^\(#\)\?Domain = /c\Domain = '$(hostname -d) /etc/idmapd.conf

# Configure the share
mkdir -p $share/ 
[[ -d $share ]] || exit 11
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
# NFSv3 supports this. NFSv4 does not. Untested.
id=50000
name=nfsanon
getent group $name || groupadd -g $id $name
id $name || useradd -u $id -g $name -s /sbin/nologin -d /dev/null $name

# NFSv4 does not support anonuid/anongid, and Kerberos does not allow anonymous user
#$share    $cidr(rw,sync,sec=krb5p:krb5i:krb5:sys,root_squash,no_subtree_check,anonuid=$id,anongid=$id)
sed -i "\,$cidr,d" /etc/exports
cat <<EOH |tee /etc/exports
$share    $cidr(rw,sync,sec=krb5p:krb5i:krb5:sys,root_squash,no_subtree_check)
EOH

# Allow through Linux firewall
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload

# Apply the NFS configuration
exportfs -ra
systemctl daemon-reload
systemctl restart nfs-mountd
systemctl enable --now nfs-server

# Verify (have v. want)
vers="$(cat /proc/fs/nfsd/versions)"
[[ "$vers" =~ '+3 +4 -4.0 -4.1 +4.2' ]] &&
    echo ok ||
        echo "/proc/fs/nfsd/versions : $vers"

# Inspect the running configuration
exportfs -v
#=> /mnt/nfs_01  192.168.11.0/24(sync,wdelay,hide,no_subtree_check,anonuid=50000,anongid=50000,sec=sys,rw,secure,root_squash,no_all_squash)