#!/usr/bin/env bash
repo=grafana
chart=loki
release=$chart
v=6.29.0 # App Version: 3.4.2
 
upgrade(){
    values=values.on-prem-nfs-minimal.yaml
    helm repo add $repo https://grafana.github.io/helm-charts
    helm upgrade --install $release $repo/$chart --version $v --values $values
}

delete(){
    helm delete $release
}

pushd ${BASH_SOURCE%/*} || pushd . || exit 1
"$@" || echo ERR $?
popd
