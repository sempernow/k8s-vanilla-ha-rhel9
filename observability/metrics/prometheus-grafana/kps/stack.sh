#!/usr/bin/env bash
#######################################################
# Install/Delete kube-prometheus-stack by Helm method
# GitHub : https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
#######################################################
set -euo pipefail

export RELEASE='prom'
export NAMESPACE='default'

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
    values=values.v0.0.0.yaml # v0.0.0 is the chart values.yaml (default).
    opts="--version $v -f $values" 
    helm repo add $repo https://$repo.github.io/helm-charts --force-update &&
        helm show values $repo/$chart --version $v |tee values.yaml &&
            helm template $RELEASE $repo/$chart $opts |tee helm.template.yaml &&
                helm upgrade $RELEASE $repo/$chart --install $opts
}

access(){
    port=3000
    helm status $RELEASE
    pass="$(
        kubectl -n $NAMESPACE get secrets $RELEASE-grafana -o jsonpath="{.data.admin-password}" \
        |base64 -d
    )"
    echo === Password: $pass
    #export POD_NAME=$(kubectl -n $NAMESPACE get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prom" -oname)
    #pgrep kubectl || {
    #    echo === Grafana Pod : port-forward : localhost:$port
    #    /bin/bash -c '
    #        kubectl -n $1 port-forward $2 $3
    #    ' _ $NAMESPACE $POD_NAME $port >/dev/null 2>&1 &
    #    sleep 1
    #}
    pgrep kubectl || {
        echo === Grafana Service : port-forward : localhost:$port
        /bin/bash -c '
            kubectl -n $1 port-forward svc/$2 $3:80
        ' _ $NAMESPACE $RELEASE-grafana $port >/dev/null 2>&1 &
        sleep 1
    }
    curl --max-time 3 -sfIX GET http://localhost:$port/login | grep HTTP &&
        echo === Grafana @ localhost:$port ||
            echo === FAIL @ localhost:$port 
}

delete(){
    helm uninstall $RELEASE
}

pushd ${BASH_SOURCE%/*} || pushd . || exit 1
"$@" || echo ERR $?
popd
