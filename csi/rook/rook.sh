#!/usr/bin/env bash

up(){
    # Install Rook
    v=v1.16.0
    # https://rook.github.io/docs/rook/latest-release/Getting-Started/quickstart/#prerequisites
    [[ $(type -t git) ]] || exit 111
    #git clone --single-branch --branch $v https://github.com/rook/rook.git
    kubectl create -f crds.yaml -f common.yaml -f operator.yaml
    kubectl create -f cluster.yaml
    
    [[ -r toolbox.yaml ]] ||
        curl -sSLO https://raw.githubusercontent.com/rook/rook/master/deploy/examples/toolbox.yaml
    k apply -f toolbox.yaml
}
# https://rook.io/docs/rook/latest-release/Getting-Started/ceph-teardown/#cleaning-up-a-cluster
down(){
    kubectl delete -n rook-ceph cephblockpool replicapool
    kubectl delete storageclass rook-ceph-block
    kubectl delete storageclass csi-cephfs
    for manifest in cluster operator common crds;do
        [[ -r $manifest.yaml ]] &&
            kubectl delete -f $manifest.yaml
    done
    echo 
}
host_teardown(){
    # Working at target node, delete all NDBs (Network Block Device)s
    type -t qemu-nbd || dnf install -y qemu-nbd
    for nbd in /dev/nbd*; do
        qemu-nbd --disconnect $nbd
    done
    # Delete state
    rm -rf /var/lib/rook

    # Wipe block device 
    #rbd=sdb
    #sudo wipefs --all /dev/sdb && sudo dd if=/dev/zero of=/dev/${rbd} bs=1M count=10
}

pushd ${BASH_SOURCE%/*} || exit 1
"$@" || code=$?
popd
[[ $code ]] && echo " ERR : $code" || echo
exit $code
