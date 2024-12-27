#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#  https://github.com/rancher/local-path-provisioner
# -----------------------------------------------------------------------------

ok(){
    v=v0.0.30
    base=https://raw.githubusercontent.com/rancher/local-path-provisioner
    manifest=local-path-storage.yaml
    [[ -r $manifest ]] || curl -sSLO $base/$v/deploy/$manifest 
    [[ -r $manifest ]] && kubectl apply -f $manifest 
    
    # Usage test : Pod/PVC dynamically create PV 
    # @ /opt/local-path-provisioner/<PVC> on node of pod
    kubectl create -f $base/master/examples/pvc/pvc.yaml
    kubectl create -f $base/master/examples/pod/pod.yaml
}

pushd ${BASH_SOURCE%/*} || exit 1
ok || code=$?
popd
[[ $code ]] && echo " ERR : $code" || echo
exit $code

####

☩ k get pod,pvc,pod
NAME                                          READY   STATUS    RESTARTS   AGE
pod/local-path-provisioner-65d5864f8d-wkngb   1/1     Running   0          11m
pod/volume-test                               1/1     Running   0          5m40s

NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/local-path-pvc   Bound    pvc-99878df1-b5e7-4b53-afcc-9c91e14dcce9   128Mi      RWO            local-path     <unset>                 5m51s

☩ ansibash ls -hal /opt/local-path-provisioner/pvc-99878df1-b5e7-4b53-afcc-9c91e14dcce9_local-path-storage_local-path-pvc
=== u1@a1
Connection to 192.168.11.101 closed.
total 0
drwxrwxrwx. 2 root root  6 Dec 27 18:01 .
drwxr-xr-x. 3 root root 88 Dec 27 18:01 ..
Connection to 192.168.11.101 closed.
=== u1@a2
Connection to 192.168.11.102 closed.
ls: cannot access '/opt/local-path-provisioner/pvc-99878df1-b5e7-4b53-afcc-9c91e14dcce9_local-path-storage_local-path-pvc': No such file or directory
Connection to 192.168.11.102 closed.
=== u1@a3
Connection to 192.168.11.100 closed.
ls: cannot access '/opt/local-path-provisioner/pvc-99878df1-b5e7-4b53-afcc-9c91e14dcce9_local-path-storage_local-path-pvc': No such file or directory
Connection to 192.168.11.100 closed.