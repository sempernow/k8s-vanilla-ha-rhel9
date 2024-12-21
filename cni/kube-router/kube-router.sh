#!/usr/bin/env bash
###################################################
# https://github.com/cloudnativelabs/kube-router/
# Install kube-router 
# ARGs: 
#   _install [pod_ntwk_only | replace_kube_proxy]
#   _teardown
# 
###################################################
export base=https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset
export all=kubeadm-kuberouter-all-features.yaml
export pod=kubeadm-kuberouter.yaml

[[ -f ~/.kube/config ]] ||
    export KUBECONFIG=/etc/kubernetes/admin.conf

_kubeproxy_cleanup(){
    # cleanup kube-proxy's iptables and such
    img=$(kubectl get ds kube-proxy -o jsonpath='{.spec.template.spec.containers[].image}')
    [[ $(echo $img |grep 'kube-proxy') ]] ||
        img=k8s.gcr.io/kube-proxy-amd64:v1.28.2
    type -t ctr || return 2
    sudo ctr images pull $image &&
        sudo ctr run --rm --privileged --net-host \
            --mount type=bind,src=/lib/modules,dst=/lib/modules,options=rbind:ro \
            $image kube-proxy-cleanup kube-proxy --cleanup
}
_install(){
    type -t kubectl || exit 1
    replace_kube_proxy(){
        # Service Proxy (kube-proxy), Firewall, and Pod Network and Policy
        curl -sSLO $base/$all &&
            kubectl apply -f $all &&
                kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"not-kuberouter": "true"}}}}}'
    }
    pod_ntwk_only(){
        # Pod Network and Policy
        curl -sSLO $base/$pod &&
            kubectl apply -f $pod
    }
    either(){
        replace_kube_proxy || pod_ntwk_only
    }

    pushd "${ADMIN_SRC_DIR}/cni/kube-router" || exit 22
    "${1:-either}" || code=$?
    popd
    [[ $code ]] && return $code 
    _kubeproxy_cleanup || return 999
    return
}

_teardown(){
    kubectl delete -f $all
    kubectl delete -f $pod
}



"$@" || code=$?
[[ $code ]] && echo ERR : $code
exit $code
