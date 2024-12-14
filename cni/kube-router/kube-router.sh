#!/usr/bin/env bash
################################################
# Install kube-router Providing ...
# - Run as sudo
################################################
base=https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset
all=kubeadm-kuberouter-all-features.yaml
pod=kubeadm-kuberouter.yaml

[[ -f ~/.kube/config ]] ||
    export KUBECONFIG=/etc/kubernetes/admin.conf

_install(){
    type -t kubectl || exit 1
    replace_kube_proxy(){
        # Service Proxy (kube-proxy), Firewall, and Pod Network and Policy
        curl -sSLO $base/$all &&
            kubectl apply -f $all &&
                kubectl -n kube-system delete ds kube-proxy 
    }
    pod_ntwk_only(){
        # Pod Network and Policy
        curl -sSLO $base/$pod &&
            kubectl apply -f $pod
    }
    either(){
        replace_kube_proxy || pod_ntwk_only
    }

    pushd "${BASH_SOURCE%%/*}"
    "$@"
    code=$?
    popd
    return $code
}

_teardown(){
    echo FAILING 
    return 11
    # Teardown kube-router
    type -t ctr || return 2
    ctr images pull k8s.gcr.io/kube-proxy-amd64:v1.28.2 &&
        ctr run --rm --privileged --net-host \
            --mount type=bind,src=/lib/modules,dst=/lib/modules,options=rbind:ro \
            registry.k8s.io/kube-proxy-amd64:v1.28.2 kube-proxy-cleanup kube-proxy --cleanup
}

"$@"
