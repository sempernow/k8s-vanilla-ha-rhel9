#!/usr/bin/env bash
ok(){
    manifests='
        ns
        elasticsearch
        kibana
        fluent-bit
    '
    [[ "$1" == 'delete' ]] &&
        printf "%s.yaml\n" $manifests |grep -v 'ns.yaml' \
            |xargs -n1 kubectl $1 -f &&
                kubectl $1 ns.yaml ||
                    return $?
    
    [[ "$1" == 'apply' ]] &&
        printf "%s.yaml\n" $manifests \
            |xargs -n1 kubectl $1 -f ||
                return $?
    
    kubectl -n kube-loging get ds,deploy,sts,pod -o wide -w
}

pushd ${BASH_SOURCE%/*} || pushd . || exit 1
ok $1 || code=$?
popd
[[ $code ]] && echo " ERR : $code" || echo
exit $code
