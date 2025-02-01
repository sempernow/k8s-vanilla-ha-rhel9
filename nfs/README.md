# [RHEL NFS Server](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/deploying-an-nfs-server_deploying-different-types-of-servers)

## @ Server 

@ `a0` as `root`

```bash
sudo dnf -y install nfs-utils
```

Configure to serve NFSv4.2 only

```bash
sudo vi /etc/nfs.conf
```
```ini
[nfsd]
vers3=n
# vers4=y
vers4.0=n
vers4.1=n
vers4.2=y
```

Disable NFSv3

```bash
systemctl mask --now rpc-statd.service rpcbind.service rpcbind.socket
```

Configure `rpc.mountd` to not listen for NFSv3 mount requests.

```bash
dir=/etc/systemd/system/nfs-mountd.service.d/
sudo mkdir -p $dir
vi $dir/v4only.conf
```
```ini
[Service]
ExecStart=
ExecStart=/usr/sbin/rpc.mountd --no-tcp --no-udp
```

Configure the share 

```bash
share=/mnt/nfs_01
mkdir -p $share/
chmod 2770 $share/
chgrp 'domain users' $share/

exports=/etc/exports
cidr1='192.168.11.0/24'
#cidr2='2001:db8::/32'
cat <<EOH |tee $exports
$share    $cidr1(rw,sync,sec=krb5,root_squash)
EOH
```
- `<directory> <host_or_network_1>(<options_1>) <host_or_network_n>(<options_n>)...`

```bash
firewall-cmd --permanent --add-service nfs
firewall-cmd --reload
#systemctl enable --now nfs-server
exportfs -ra
systemctl daemon-reload
systemctl restart nfs-mountd
systemctl restart nfs-server
```

Verify 

```bash
cat /proc/fs/nfsd/versions # +4.2
```

## @ Client(s)

as `root`

```bash
dnf install -y nfs-utils

# Mount temporarily
nfs_server=a0.lime.lan
nfs_mount=/mnt/nfs_01
local_mnt=/mnt/nfs_01
mkdir -p $local_mnt
mount -t nfs4 -o vers=4.2 $nfs_server:$nfs_mount/ $local_mnt/
```
@ `/etc/fstab`

```ini
a0.lime.lan:/mnt/nfs_01 /mnt/nfs_01 nfs4 vers=4.2,_netdev,auto 0 0
```
