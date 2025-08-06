#!/usr/bin/env bash
#######################################################
# Install/Delete kube-prometheus-stack by Helm method
# GitHub : https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
#######################################################
#set -euo pipefail

export RELEASE='kps'
export NAMESPACE='kube-metrics'

install(){

    # Helm binary if not already
    v=v3.17.3
    what=linux-amd64
    url=https://get.helm.sh/helm-$v-$what.tar.gz
    type -t helm > /dev/null 2>&1 &&
        helm version |grep $v > /dev/null 2>&1 || {
            echo '  INSTALLing helm'
            curl -sSfL $url |tar -xzf - &&
                sudo install $what/helm /usr/local/bin/ &&
                    rm -rf $what &&
                        echo ok || echo ERR : $?
        }

    # Chart
    v=72.4.0
    repo=prometheus-community
    chart=kube-prometheus-stack
    values=values.v0.0.0.yaml  # Chart default values.yaml
    values=values.minimal.yaml # Minimal diff for core functionality.
    opts="-n $NAMESPACE --create-namespace --version $v -f $values" 
    helm repo add $repo https://$repo.github.io/helm-charts --force-update &&
        helm show values $repo/$chart --version $v |tee values.yaml &&
            helm template $RELEASE $repo/$chart $opts |tee helm.template.yaml &&
                helm upgrade $RELEASE $repo/$chart --install $opts

    grep image: helm.template.yaml |sort -u |sed 's/^[[:space:]]*//g' |cut -d' ' -f2 |sed 's/"//g' >kps.images.log
}

access(){
    helm status $RELEASE -n $NAMESPACE
    echo === Grafana 
    port=3000 # Host port
    labels="app.kubernetes.io/name=grafana,app.kubernetes.io/instance=$RELEASE"
    export pod=$(kubectl -n $NAMESPACE get pod -l "$labels" -o name)
    pgrep kubectl || {
       echo Expose : localhost:$port
       /bin/bash -c '
           kubectl -n $1 port-forward $2 $3
       ' _ $NAMESPACE $pod $port >/dev/null 2>&1 &
       sleep 1
    }
    curl --max-time 3 -sfIX GET http://localhost:$port/login | grep HTTP &&
        echo Origin : http://localhost:$port &&
            pass="$(
                kubectl -n $NAMESPACE get secrets $RELEASE-grafana -o jsonpath="{.data.admin-password}" \
                |base64 -d
            )" &&
                echo Login  : admin:$pass ||
                    echo FAILed at GET http://localhost:$port
}

delete(){
    helm delete $RELEASE -n $NAMESPACE
}

pushd ${BASH_SOURCE%/*} || pushd . || exit 1
"$@" || echo ERR $?
popd
