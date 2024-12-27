#!/usr/bin/env bash

PATH=csi/rook

up(){
    # Install Rook
    v=v1.16.0
    # https://rook.github.io/docs/rook/latest-release/Getting-Started/quickstart/#prerequisites
    type -f git || exit 1
    #git clone --single-branch --branch $v https://github.com/rook/rook.git
    pushd $PATH
    kubectl create -f crds.yaml -f common.yaml -f operator.yaml --wait
    kubectl create -f cluster.yaml
    popd
}
# https://rook.io/docs/rook/latest-release/Getting-Started/ceph-teardown/#cleaning-up-a-cluster
down(){
    kubectl delete -n rook-ceph cephblockpool replicapool
    kubectl delete storageclass rook-ceph-block
    kubectl delete storageclass csi-cephfs
    pushd $PATH
    for manifest in cluster operator common crds;do
        [[ -r $manifest.yaml ]] &&
            kubectl delete -f $manifest.yaml
    done
    popd
}
ndb_delete(){
    # Working at target node, delete all NDBs (Network Block Device)s
    type -t qemu-nbd || dnf install -y qemu-nbd
    for nbd in /dev/nbd*; do
        qemu-nbd --disconnect $nbd
    done


}

"$@"
