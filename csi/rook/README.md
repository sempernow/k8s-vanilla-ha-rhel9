# [ROOK](https://rook.github.io/docs/rook/latest-release/Getting-Started/intro/) 


## TL;DR

A simple Rook cluster is created for Kubernetes 
with the following `kubectl` commands and [example manifests](https://github.com/rook/rook/tree/release-1.16/deploy/examples):

```bash
$ git clone --single-branch --branch v1.16.0 https://github.com/rook/rook.git
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

`v1.16`

## [Storage Architecture](https://rook.github.io/docs/rook/latest-release/Getting-Started/storage-architecture/#design)

[Ceph Monitors](https://rook.github.io/docs/rook/latest-release/Storage-Configuration/Advanced/ceph-mon-health/) (__mons__) are __the brains of the distributed cluster__. They control all of the metadata that is necessary to store and retrieve your data as well as keep it safe. If the monitors are not in a healthy state you will risk losing all the data in your system.

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

### &nbsp;
