#!/usr/bin/env bash
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises

VER='v3.29.1'
BASE=https://raw.githubusercontent.com/projectcalico/calico/$VER/manifests
operator=tigera-operator.yaml
manifest=custom-resources-bpf-bgp.yaml

kubeproxy_cleanup(){
    # Per-node cleanup of kube-proxy's iptables and such
    img=$(kubectl get -n kube-system ds kube-proxy -o jsonpath='{.spec.template.spec.containers[].image}')
    [[ $(echo $img |grep 'kube-proxy') ]] ||
        img=k8s.gcr.io/kube-proxy-amd64:v1.29.6
    type -t ctr || return $?
    sudo ctr images pull $img &&
        sudo ctr run --rm --privileged --net-host \
            --mount type=bind,src=/lib/modules,dst=/lib/modules,options=rbind:ro \
            $img kube-proxy-cleanup kube-proxy --cleanup || return $?
}

# Operator Method
apply(){
    # Operator
    [[ -f $operator ]] || curl -fsSLO $BASE/$operator || return 11

    # CRDs and app
    [[ -f $manifest ]] || {
        curl -fsSL $BASE/custom-resources -o $manifest || return 12
        echo "=== EDIT $manifest to fit environment, and then install."
        return 13
    }
    [[ $(kubectl get ns |grep 'tigera-op') ]] ||
        kubectl create -f $operator

    kubectl apply -f $manifest

    #kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'
    
    kubectl get pod -o wide -A -w
}
teardown(){
    kubectl delete -f $manifest
    kubectl delete -f $operator 
}

pushd "${BASH_SOURCE%/*}" || pushd . || return 1
"$@" || code=$?
popd 
[[ $code ]] && echo ERR : ${BASH_SOURCE##*/} : $? || echo
