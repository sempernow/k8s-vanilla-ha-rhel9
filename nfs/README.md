# NFS 

## [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner )

This K8s CSI-compliant External Provisioners handles storage directly via the existing NFS server. 
This is, no host-level NFS client mount is required at any K8s node. However, we can test for server accessibility at the host:

### Client @ `[u2@a2 ~]`

```bash
sudo mkdir /mnt/test
sudo mount -t nfs a0.lime.lan:/srv/nfs/k8s /mnt/test
```

```bash
$ mkdir -p /mnt/test/bb
$ touch /mnt/test/b
$ touch /mnt/test/bb/a
$ ls -Rhl /mnt/
/mnt/:
total 0
drwxr-xr-x. 2 root root  6 Mar  1 16:22 nfs_01
drwxrwxrwx. 3 root root 34 Apr  6 10:34 test

/mnt/nfs_01:
total 0

/mnt/test:
total 0
-rw-r--r--. 1 u1 u1              0 Apr  6 08:36 a
-rw-r--r--. 1 u2 ad-linux-users  0 Apr  6 10:34 b
drwxr-xr-x. 2 u2 ad-linux-users 15 Apr  6 10:41 bb

/mnt/test/bb:
total 0
-rw-r--r--. 1 u2 ad-linux-users 0 Apr  6 10:41 a
```
- Note the NFS-client mount, `/mnt/test`, 
  adopts the server-exported FS configurations;  
  `OWNER:GROUP` (`root:root`) and `MODE` (`777`).

### Server @ `a0`

Note NFS export declarations and systemd service at the server:

```bash
☩ ssh a0 cat /etc/exports
#/mnt/nfs_01    192.168.11.0/24(rw,sync,sec=krb5p:krb5i:krb5:sys,root_squash,no_subtree_check)
/srv/nfs/k8s    192.168.11.0/24(rw,sync,no_root_squash,no_subtree_check)
```
```bash
☩ ssh a0 ls -hl /srv
total 0
drwxr-xr-x. 3 root root 17 Apr  6 08:17 nfs
```
```bash
☩ ssh a0 systemctl status nfs-server.service
```
```plaintext
● nfs-server.service - NFS server and services
     Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; preset: disabled)
    Drop-In: /run/systemd/generator/nfs-server.service.d
             └─order-with-mounts.conf
     Active: active (exited) since Sun 2025-04-06 08:33:18 EDT; 2h 12min ago
       Docs: man:rpc.nfsd(8)
             man:exportfs(8)
    Process: 22236 ExecStartPre=/usr/sbin/exportfs -r (code=exited, status=0/SUCCESS)
    Process: 22237 ExecStart=/usr/sbin/rpc.nfsd (code=exited, status=0/SUCCESS)
    Process: 22247 ExecStart=/bin/sh -c if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi (code=exited, status=0/SUCCESS)
   Main PID: 22247 (code=exited, status=0/SUCCESS)
        CPU: 20ms

Apr 06 08:33:18 a0 systemd[1]: Starting NFS server and services...
Apr 06 08:33:18 a0 systemd[1]: Finished NFS server and services.
```

```bash
☩ ls -Rhl /srv
/srv:
total 0
drwxr-xr-x. 3 root root 17 Apr  6 08:17 nfs

/srv/nfs:
total 0
drwxrwxrwx. 3 root root 34 Apr  6 10:34 k8s

/srv/nfs/k8s:
total 0
drwxr-xr-x. 2 u2 ad-linux-users 15 Apr  6 10:41 bb
-rw-r--r--. 1 u1 u1              0 Apr  6 08:36 a
-rw-r--r--. 1 u2 ad-linux-users  0 Apr  6 10:34 b

/srv/nfs/k8s/bb:
total 0
-rw-r--r--. 1 u2 ad-linux-users 0 Apr  6 10:41 a
```
- Note export, `/srv/nfs/k8s`, has file mode `777`
