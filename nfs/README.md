# [RHEL NFS Server](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/deploying-an-nfs-server_deploying-different-types-of-servers)


## Kerberos

When a RHEL system is joined to an Active Directory (AD) domain using `realm join`, `sssd` is responsible for handling authentication, including Kerberos ticketing.


## TL:DR

We were able to generate Kerberos tickets for host, and even for NFS after a fantastic amount of configuration; however, the tickets are short lived and do not renew automatically, even after meticulously configuring it to do so.  

__Kerberos is simply not worth the bother.__
The scheme has more configuration permutation than there are atoms in the Universe.

Much, much more.

## @ Server : [`install-nfs-server.sh`](install-nfs-server.sh)

@ `a0` as `root`

Configure the share __only after host is joined into domain__.

### [Kerberos](https://chatgpt.com/share/67c47f8a-ca60-8009-bd32-99d0d10bebf7)

Do not add Kerberos option at NFS server unless host is configured for it.

If `sssd` is of host joined into AD by `realm join`, 
then it is configured __to allow for__ Kerberos.

See `/etc/sssd/sssd.conf`, `man sssd-krb5` and `man sssd.conf`

 However, creating, renewing, and otherwise maintaining __Kerberos tickets requires a labyrinth of configurations across many interrelated tools__. And such tickets are target specific. That is, tickets for use at a host differ from those for use at NFS on that host.

#### Verify

@ `u1@a0`

```bash
u1@a0 [08:05:27] [1] [#0] ~
☩ kinit admin@LIME.LAN
Password for admin@LIME.LAN:

u1@a0 [08:06:40] [1] [#0] ~
☩ klist
Ticket cache: KCM:1000
Default principal: admin@LIME.LAN

Valid starting     Expires            Service principal
03/02/25 08:06:36  03/02/25 18:06:36  krbtgt/LIME.LAN@LIME.LAN
        renew until 03/09/25 09:06:14
```

```bash
☩ kinit u1@LIME.LAN
Password for u1@LIME.LAN:

☩ klist
Ticket cache: KCM:1000:28381
Default principal: u1@LIME.LAN

Valid starting     Expires            Service principal
03/02/25 08:11:22  03/02/25 18:11:22  krbtgt/LIME.LAN@LIME.LAN
        renew until 03/09/25 09:11:17

☩ klist -l
Principal name                 Cache name
--------------                 ----------
u1@LIME.LAN                    KCM:1000:28381
admin@LIME.LAN                 KCM:1000
```
- So Kerberos ticket is good for __7 days__


Yet for NFS access, each user of each client needs a valid tiket

```bash
kinit -S nfs/a0.lime.lan@LIME.LAN $user

```

Get ticket 

```bash
☩ ansibash
...
  ANSIBASH_TARGET_LIST='a1 a2 a3'
  ANSIBASH_USER='u2'

☩ ansibash kinit -S nfs/a0.lime.lan@LIME.LAN u2
```

Validate

```bash
☩ ansibash ls -hal /mnt
=== u2@a1
drwxr-xr-x.  3 root root            20 Feb  1 18:38 .
dr-xr-xr-x. 18 root root           235 Dec 13 12:35 ..
drwxrws---+  3 root ad-linux-users  24 Mar  2 16:38 nfs_01
=== u2@a2
drwxr-xr-x.  3 root root            20 Mar  1 16:22 .
dr-xr-xr-x. 18 root root           235 Dec 13 12:41 ..
drwxrws---+  3 root ad-linux-users  24 Mar  2 16:38 nfs_01
=== u2@a3
drwxr-xr-x.  3 root root            20 Mar  1 16:22 .
dr-xr-xr-x. 18 root root           235 Dec 13 12:42 ..
drwxrws---+  3 root ad-linux-users  24 Mar  2 16:38 nfs_01
```

```bash
☩ ansibash ls -hal /mnt/nfs_01
=== u2@a1
...
drwxrws---+ 2 u2   ad-linux-users 15 Mar  1 17:19 a
-rw-rw----. 1 u1   ad-linux-users  0 Mar  2 16:38 b
=== u2@a2
...
drwxrws---+ 2 u2   ad-linux-users 15 Mar  1 17:19 a
-rw-rw----. 1 u1   ad-linux-users  0 Mar  2 16:38 b
=== u2@a3
...
drwxrws---+ 2 u2   ad-linux-users 15 Mar  1 17:19 a
-rw-rw----+ 1 u1   ad-linux-users  0 Mar  2 16:38 b
```

### Declare the domain

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

### Kerberos config 

Auto get ticket on user login and  auto renew

See `nfs/kerberos/`. Mod to configs:

- `/etc/sssd/sssd.conf`
- `/etc/pam.d/sshd`
- `/etc/krb5.conf`


Install all

```bash
tar -caf kerberos.tgz nfs/kerberos
ansibash -u kerberos.tgz
ansibash tar -xaf  kerberos.tgz
ansibash sudo cp nfs/kerberos/sssd.conf /etc/sssd/
ansibash sudo ls -hl /etc/sssd/
ansibash sudo cat /etc/sssd/sssd.conf |grep krb5
ansibash sudo cp nfs/kerberos/pam.d.sshd /etc/pam.d/sshd
ansibash sudo ls -hl /etc/pam.d/sshd
ansibash sudo cp nfs/kerberos/krb5.conf /etc/krb5.conf
ansibash sudo ls -hl /etc/krb5.conf
ansibash ls -hl nfs/kerberos/

# Restart services
sudo systemctl restart sssd
sudo systemctl restart rpc-gssd
sudo systemctl restart nfs-client.target
```


__Verify__

```bash
☩ ansibash klist
=== u2@a1
Ticket cache: KCM:322202610:62865
Default principal: u2@LIME.LAN

Valid starting     Expires            Service principal
03/02/25 17:54:58  03/03/25 03:54:58  nfs/a0.lime.lan@LIME.LAN
        renew until 03/09/25 18:54:52
=== u2@a2
Ticket cache: KCM:322202610:72575
Default principal: u2@LIME.LAN

Valid starting     Expires            Service principal
03/02/25 17:55:02  03/03/25 03:55:02  nfs/a0.lime.lan@LIME.LAN
        renew until 03/09/25 18:54:59
=== u2@a3
Ticket cache: KCM:322202610:85859
Default principal: u2@LIME.LAN

Valid starting     Expires            Service principal
03/02/25 17:55:07  03/03/25 03:55:07  nfs/a0.lime.lan@LIME.LAN
        renew until 03/09/25 18:55:03
```

