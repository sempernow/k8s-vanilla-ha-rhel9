#!/usr/bin/env bash
ok(){
    #########################################################
    ## Install etcd, etcdctl, etcutl onto this host
    ##
    ## WARNING:
    ##  If cluster runs its etcd as Static Pod, 
    ##  then do *not* run etcd.service on host,
    ##  else conflicts are likely to occur.
    ## 
    #########################################################
    ## Align ETCD_VERSION with that of target clusters' etcd:
    # ver=1.29.6
    # kubeadm config images list --kubernetes-version $ver
    # Or, at an existing target cluster
    # etcd_pod_name=etcd-a1
    # kubectl exec -it $etcd_pod_name -- etcd --version 
    ETCD_VERSION=v3.5.12
    dir=etcd-${ETCD_VERSION}-linux-amd64
    archive=$dir.tar.gz
    to=/usr/local/bin

    [[ ! -f $archive ]] &&
        wget -nv https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/$archive &&
            tar -xvf $archive

    [[ -d $dir ]] &&
        sudo install $dir/etc* $to
    
    etcdutl version || return 55
}
ok || exit $?
