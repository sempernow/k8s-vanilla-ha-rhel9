#!/usr/bin/env bash
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises

VER='v3.29.1'
BASE=https://raw.githubusercontent.com/projectcalico/calico/$VER/manifests

# Operator Method
ok(){
    operator=tigera-operator.yaml
    manifest=custom-resources-bpf-bgp.yaml

    # Operator
    [[ -f $operator ]] || curl -fsSLO $BASE/$operator || return 11

    # CRDs and app
    [[ -f $manifest ]] || {
        curl -fsSL $BASE/custom-resources -o $manifest || return 12
        echo "=== EDIT $manifest to fit environment, and then install."
        return 13
    }

    kubectl create -f $operator
    kubectl apply -f $manifest &&
        kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"not-calico": "true"}}}}}' 

}

pushd "${BASH_SOURCE%/*}" || pushd . || return 1
ok || code=$?
popd 
[[ $code ]] && echo ERR : ${BASH_SOURCE##*/} : $?
