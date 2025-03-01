# [RHEL NFS Server](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/deploying-an-nfs-server_deploying-different-types-of-servers)

## @ Server : [`install-nfs-server.sh`](install-nfs-server.sh)

__This only after host is joined into domain__.

@ `a0` as `root`

```bash
sudo dnf -y install nfs-utils
```

~~Configure to serve NFSv4.2 only~~

UPDATE: Want both NFSv3 and NFSv4.2

NFSv4 does not allow for granular Linux file permissions, 
e.g., declaring the anonymous UID:GID.

```bash
sudo vi /etc/nfs.conf
```
```ini
[nfsd]
vers3=y
# vers4=y
vers4.0=n
vers4.1=n
vers4.2=y
```


~~Disable NFSv3~~

```bash
#systemctl mask --now rpc-statd.service rpcbind.service rpcbind.socket
systemctl unmask rpc-statd.service rpcbind.service rpcbind.socket
systemctl enable --now rpc-statd.service rpcbind.service rpcbind.socket

```

~~Configure `rpc.mountd` to not listen for NFSv3 mount requests.~~

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
- No. Don't disable NFSv3

Configure the share 

- Do not add Kerberos option unless configured for it.
  `sssd` on this NFS server (host `a0`) is configured for AD, but not Kerberos.  
  See `/etc/sssd/sssd.conf`, `man sssd-krb5` and `man sssd.conf`


Declare the domain

```bash
sudo vi /etc/idmapd.conf
```

```plaintext
[General]
Domain = lime.lan
```
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

__This only after host is joined into domain__ 
and __AD user (`u1`) is created and added to AD group `linux-users`__.

@ `a1` as `root`

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

Fail

```bash
root@a1 [07:54:29] [1] [#0] /home/u1
# nfs_server=a0.lime.lan
nfs_mount=/mnt/nfs_01
local_mnt=/mnt/nfs_01
mkdir -p $local_mnt
mount -t nfs4 -o vers=4.2 $nfs_server:$nfs_mount/ $local_mnt/
mount.nfs4: access denied by server while mounting a0.lime.lan:/mnt/nfs_01/
```