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

# Configure to serve NFSv4.2 only (idempotent)
sedfile=/tmp/etc.nfs.conf.sed 
cat <<EOH |tee $sedfile
/vers3=/c\vers3=n
/vers4=/c\# vers4=y
/vers4.0=/c\vers4.0=n
/vers4.1=/c\vers4.1=n
/vers4.2=/c\vers4.2=y
EOH
sed -i -f $sedfile /etc/nfs.conf
rm -f $sedfile

# Disable NFSv3 : May also disable NFSv4 at clients !!!
# systemctl mask --now rpc-statd.service rpcbind.service rpcbind.socket

# Configure rpc.mountd (once) to not listen for NFSv3 mount requests.
dir=/etc/systemd/system/nfs-mountd.service.d/
[[ -f $dir/v4only.conf ]] || {
	mkdir -p $dir
	cat <<-EOH |tee $dir/v4only.conf
	[Service]
	ExecStart=
	ExecStart=/usr/sbin/rpc.mountd --no-tcp --no-udp
	EOH
}

# Configure the share
share=/mnt/nfs_01
mkdir -p $share/
chmod 2770 $share/
chgrp 'domain users' $share/

exports=/etc/exports
cidr1="$2"
cat <<EOH |tee $exports
$share    $cidr1(rw,sync,sec=krb5,root_squash)
EOH

firewall-cmd --permanent --add-service nfs
firewall-cmd --reload
exportfs -ra
systemctl daemon-reload
systemctl restart nfs-mountd
systemctl enable --now nfs-server

vers="$(cat /proc/fs/nfsd/versions)"
[[ "$vers" =~ '-3 +4 -4.0 -4.1 +4.2' ]] &&
    echo ok ||
        echo "/proc/fs/nfsd/versions : $vers"
