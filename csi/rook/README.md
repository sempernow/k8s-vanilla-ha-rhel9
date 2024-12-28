# [ROOK](https://rook.github.io/docs/rook/latest-release/Getting-Started/intro/) 

`v1.16`

## TL;DR

A simple Rook cluster is created for Kubernetes 
with the following `kubectl` commands and [example manifests](https://github.com/rook/rook/tree/release-1.16/deploy/examples):

```bash
git clone --single-branch --branch v1.16.0 https://github.com/rook/rook.git
cd rook/deploy/examples
kubectl create -f crds.yaml -f common.yaml -f operator.yaml
kubectl create -f cluster.yaml
```
- [`crds.yaml`](crds.yaml)
- [`common.yaml`](common.yaml)
- [`operator.yaml`](operator.yaml)
- [`cluster.yaml`](cluster.yaml)

After the cluster is running, applications can consume __block__, __object__, or __file__ storage.

## Rook is Ceph on K8s

- Rook enables Ceph storage to run on Kubernetes using Kubernetes primitives.
    - [Rook Ceph Operator](https://rook.io/docs/rook/latest-release/Helm-Charts/helm-charts/) is a simple container that has all that is needed to bootstrap and monitor the storage cluster.
- Ceph is a highly scalable distributed storage solution for __block storage__, __object storage__, and __shared filesystems__ with years of production deployments.
    - Failure in a distributed system is to be expected. Ceph was designed from the ground up to deal with the failures of a distributed system.

>With Ceph running in the Kubernetes cluster, Kubernetes applications can mount block devices and filesystems managed by Rook, or can use the S3/Swift API for object storage.

## [Storage Architecture](https://rook.github.io/docs/rook/latest-release/Getting-Started/storage-architecture/#design)

[Ceph Monitors](https://rook.github.io/docs/rook/latest-release/Storage-Configuration/Advanced/ceph-mon-health/) (__mons__) are __the brains of the distributed cluster__. They control all of the metadata that is necessary to store and retrieve your data as well as keep it safe. If the monitors are not in a healthy state you will risk losing all the data in your system.

## Install 

@ Hypervisor

Add raw block device, i.e., a 2nd HDD/SSD disk, for Rook to use for its block, file and object stores; `/dev/sdb`

@ Admin host : `Ubuntu (master) .../s/DEV/devops/infra/kubernetes/k8s-vanilla-ha-rhel9/csi/rook`

```bash
make csi-rook-up
```

I.e., 

```bash
bash ./rook.sh up
```

Verify. Note `ceph_bluestore` @ `sdb`

```bash
☩ kw
=== a1 : 10/17
csi-cephfsplugin-f9gk2                          3/3     Running     0          4m59s   192.168.11.101   a1     <none>           <none>
csi-cephfsplugin-provisioner-784d9966c6-v8jrc   6/6     Running     0          4m59s   10.22.0.30       a1     <none>           <none>
csi-rbdplugin-hrtqj                             3/3     Running     0          4m59s   192.168.11.101   a1     <none>           <none>
rook-ceph-crashcollector-a1-7c54587697-spx4z    1/1     Running     0          3m35s   10.22.0.37       a1     <none>           <none>
rook-ceph-exporter-a1-69c78b9795-2hd75          1/1     Running     0          3m32s   10.22.0.39       a1     <none>           <none>
rook-ceph-mgr-a-78cc55dd4c-mfqjb                3/3     Running     0          4m6s    10.22.0.33       a1     <none>           <none>
rook-ceph-mon-a-6b5cc747fb-s8jq2                2/2     Running     0          4m49s   10.22.0.32       a1     <none>           <none>
rook-ceph-osd-0-5d48d97c4-7xzvz                 2/2     Running     0          3m35s   10.22.0.38       a1     <none>           <none>
rook-ceph-osd-prepare-a1-x6hcm                  0/1     Completed   0          3m43s   10.22.0.36       a1     <none>           <none>
rook-ceph-tools-56fbc74755-5q9hj                1/1     Running     0          26s     10.22.0.40       a1     <none>           <none>
=== a2 : 10/16
csi-cephfsplugin-cm7sp                          3/3     Running     0          4m59s   192.168.11.102   a2     <none>           <none>
csi-cephfsplugin-provisioner-784d9966c6-rttbv   6/6     Running     0          4m59s   10.22.1.20       a2     <none>           <none>
csi-rbdplugin-n4b88                             3/3     Running     0          4m59s   192.168.11.102   a2     <none>           <none>
csi-rbdplugin-provisioner-75cfd96674-k8sg4      6/6     Running     0          4m59s   10.22.1.19       a2     <none>           <none>
rook-ceph-crashcollector-a2-546b88b7fb-tcgnd    1/1     Running     0          3m34s   10.22.1.28       a2     <none>           <none>
rook-ceph-exporter-a2-f6867cc86-5pcbl           1/1     Running     0          3m31s   10.22.1.29       a2     <none>           <none>
rook-ceph-mgr-b-86c6bf4594-6hncb                3/3     Running     0          4m5s    10.22.1.23       a2     <none>           <none>
rook-ceph-mon-c-5f4c664bd5-68ljl                2/2     Running     0          4m16s   10.22.1.22       a2     <none>           <none>
rook-ceph-osd-1-56db874b49-4xkj4                2/2     Running     0          3m34s   10.22.1.27       a2     <none>           <none>
rook-ceph-osd-prepare-a2-m5c7s                  0/1     Completed   0          3m43s   10.22.1.26       a2     <none>           <none>
=== a3 : 9/15
csi-cephfsplugin-xp594                          3/3     Running     0          5m      192.168.11.100   a3     <none>           <none>
csi-rbdplugin-kh78s                             3/3     Running     0          5m      192.168.11.100   a3     <none>           <none>
csi-rbdplugin-provisioner-75cfd96674-xr2ll      6/6     Running     0          5m      10.22.2.18       a3     <none>           <none>
rook-ceph-crashcollector-a3-5f986bbc79-nz4hx    1/1     Running     0          3m57s   10.22.2.21       a3     <none>           <none>
rook-ceph-exporter-a3-859f45cf85-xf5ht          1/1     Running     0          3m57s   10.22.2.20       a3     <none>           <none>
rook-ceph-mon-b-56bbb4969f-zbsf7                2/2     Running     0          4m27s   10.22.2.19       a3     <none>           <none>
rook-ceph-operator-659f7d85-tzhq8               1/1     Running     0          5m2s    10.22.2.17       a3     <none>           <none>
rook-ceph-osd-2-846d4cfc67-kh28c                2/2     Running     0          3m36s   10.22.2.23       a3     <none>           <none>
rook-ceph-osd-prepare-a3-7bkv6                  0/1     Completed   0          3m43s   10.22.2.22       a3     <none>           <none>

29/48 @ rook-ceph

☩ kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd status
ID  HOST   USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE
 0  a1    26.7M  9.97G      0        0       0        0   exists,up
 1  a2    26.7M  9.97G      0        0       0        0   exists,up
 2  a3    26.7M  9.97G      0        0       0        0   exists,up

☩ ansibash lsblk -f
=== u1@a1
Connection to 192.168.11.101 closed.
NAME          FSTYPE         FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sda
├─sda1        vfat           FAT32          08AE-EF02                               591.8M     1% /boot/efi
├─sda2        xfs                           4bff8019-1cf5-4271-874b-92033cac589d    515.9M    46% /boot
└─sda3        LVM2_member    LVM2 001       yf6yIs-Lssu-cJtn-W4ju-LhXf-0sPB-9TvB0P
  ├─rhel-root xfs                           30fe4af7-3837-44bc-812e-90fe4f1a65c2      5.6G    66% /
  └─rhel-swap swap           1              2a49f9f5-16ef-457e-87d8-47ab6f4e05e9
sdb           ceph_bluestore
nbd0
...
nbd15
Connection to 192.168.11.101 closed.
=== u1@a2
Connection to 192.168.11.102 closed.
NAME          FSTYPE         FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sda
├─sda1        vfat           FAT32          08AE-EF02                               591.8M     1% /boot/efi
├─sda2        xfs                           4bff8019-1cf5-4271-874b-92033cac589d    515.9M    46% /boot
└─sda3        LVM2_member    LVM2 001       yf6yIs-Lssu-cJtn-W4ju-LhXf-0sPB-9TvB0P
  ├─rhel-root xfs                           30fe4af7-3837-44bc-812e-90fe4f1a65c2      6.1G    63% /
  └─rhel-swap swap           1              2a49f9f5-16ef-457e-87d8-47ab6f4e05e9
sdb           ceph_bluestore
nbd0
...
nbd15
Connection to 192.168.11.102 closed.
=== u1@a3
Connection to 192.168.11.100 closed.
NAME          FSTYPE         FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sda
├─sda1        vfat           FAT32          08AE-EF02                               591.8M     1% /boot/efi
├─sda2        xfs                           4bff8019-1cf5-4271-874b-92033cac589d    515.9M    46% /boot
└─sda3        LVM2_member    LVM2 001       yf6yIs-Lssu-cJtn-W4ju-LhXf-0sPB-9TvB0P
  ├─rhel-root xfs                           30fe4af7-3837-44bc-812e-90fe4f1a65c2      6.1G    63% /
  └─rhel-swap swap           1              2a49f9f5-16ef-457e-87d8-47ab6f4e05e9
sdb           ceph_bluestore
nbd0
...
nbd15
Connection to 192.168.11.100 closed.
```

### [Ceph Dashboard](https://rook.github.io/docs/rook/latest-release/Storage-Configuration/Monitoring/ceph-dashboard/)

@ Dashboard-server terminal 

Forward service port (`8443`, `https-dashboard`) to host

```bash
☩ k port-forward svc/rook-ceph-mgr-dashboard 5555:https-dashboard
Forwarding from 127.0.0.1:5555 -> 8443
Forwarding from [::1]:5555 -> 8443
Handling connection for 5555
Handling connection for 5555
...
```

@ Another (client) terminal

```bash
☩ curl -kI https://127.0.0.1:5555/
HTTP/1.1 200 OK
Content-Type: text/html;charset=utf-8
Server: Ceph-Dashboard
...
```

@ Browser : __[`https://127.0.0.1:5555`](https://127.0.0.1:5555)__ 

Snapshot: [`rook-ceph-mgr-dashboard.01.webp`](rook-ceph-mgr-dashboard.01.webp)

__Credentials__

```bash
☩ k get secret rook-ceph-dashboard-password -o jsonpath='{.data.password}' |base64 -d
]B>k&W@>Lm*GP]2#q:?V
```
- __user__: `admin`
- __pass__: `]B>k&W@>Lm*GP]2#q:?V`

## [Example Configurations](https://rook.github.io/docs/rook/latest-release/Getting-Started/example-configurations/#operator)

### Operator : [`operator.yaml`](operator.yaml)

The most common settings for production deployments. Self documented.

```bash
kubectl create -f operator.yaml
```

### [Cluster CRD](https://rook.github.io/docs/rook/latest-release/CRDs/Cluster/ceph-cluster-crd/) : [`cluster.yaml`](cluster.yaml)

Common settings for a production storage cluster. __Install after Operator__. Requires at least three worker nodes. Creates the Ceph storage cluster with the CephCluster CR. This CR contains the most critical settings that will influence how the operator configures the storage. 

### [Setting up consumable storage](https://rook.github.io/docs/rook/latest-release/Getting-Started/example-configurations/#setting-up-consumable-storage)

- Shared Filesystem : `kind: CephFilesystem`
    - [`filesystem.yaml`](https://github.com/rook/rook/blob/release-1.16/deploy/examples/filesystem.yaml)
    - [CephFilesystem CRD](https://rook.github.io/docs/rook/latest-release/CRDs/Shared-Filesystem/ceph-filesystem-crd/)
- Object Storage : `kind: CephObjectStore`
    - [`object.yaml`](https://github.com/rook/rook/blob/release-1.16/deploy/examples/object.yaml)

## [Storage Configuration](https://rook.github.io/docs/rook/latest-release/Storage-Configuration/Block-Storage-RBD/block-storage/)

