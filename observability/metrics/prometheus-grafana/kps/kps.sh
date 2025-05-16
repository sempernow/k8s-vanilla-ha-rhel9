#!/usr/bin/env bash
#######################################################
# Install/Delete kube-prometheus-stack by Helm method
# GitHub : https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
#######################################################
set -euxo pipefail

RELEASE=prom
NS=default

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
    values=values.yaml
    helm repo add $repo https://$repo.github.io/helm-charts --force-update
    helm show chart $repo/$chart --version $v
    # Pull chart and/or only values
    helm pull $repo/$chart --version $v
    helm show values $repo/$chart --version $v |tee $values
    # Customized the planned release
    #vi $values
    # Upgrade/Install the release
    helm upgrade $RELEASE $repo/$chart --install -f $values
}

access(){
    port=3000
    helm status $RELEASE
    echo '  Password:'
    kubectl -n $NS get secrets $RELEASE-grafana -o jsonpath="{.data.admin-password}" \
        |base64 -d ; echo
    export POD_NAME=$(kubectl --namespace default get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prom" -oname)
    ps -aux |command grep port-forward |command grep $port ||
        kubectl -s $NS port-forward $POD_NAME $port &
    sleep 3
    curl -IX GET http://localhost:$port/login
}

delete(){
    helm uninstall $RELEASE
}

"$@"
