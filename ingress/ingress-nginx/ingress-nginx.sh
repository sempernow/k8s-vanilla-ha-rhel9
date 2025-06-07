#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Idempotent:
# - Apply ingress-nginx Ingress Controller configured for kind cluster.
# - Apply E2E test of Ingress/App
#
# ARGs: FUNCTION  MANIFEST
# -----------------------------------------------------------------------------
v=4.12.3
chart=ingress-nginx # Folder name on chart archive extract
repo=https://kubernetes.github.io/$chart
release=$chart
ns=$release
values=values.yaml
manifest=helm.template.$chart.$v.yaml

http="${HALB_HTTP:-31080}"
https="${HALB_HTTPS:-31443}"

tls=default-tls-cert
cn=${K8S_FQDN:-example.local}
crt=../tls/$cn/$cn.crt
key=../tls/$cn/$cn.key

# Add/Update repo
repo(){
    helm repo add $chart $repo &&
    helm repo update $chart ||
        echo "⚠  ERR on helm repo add/update : $repo"

        --key=$key \
        --dry-run=client \
        -o yaml |tee secret.$tls.yaml
}
secret(){
    kubectl create ns $ns ||
        kubectl -n $ns delete secret tls $tls --ignore-not-found
    kubectl create secret tls $tls \
        --namespace=$ns \
        --cert=$crt \
        --key=$key # --dry-run=client -o yaml |tee secret.$tls.yaml
    kubectl -n $ns get secret $tls -o yaml |tee secret.$tls.yaml
}
parse(){
    yq '.data.["tls.crt"]' <(kubectl -n $ns get secret $tls -o yaml) |base64 -d \
        |openssl x509 -noout -subject -issuer -startdate -enddate -ext subjectAltName
}

helmAction(){
    ## template|upgrade|install
    [[ $1 ]] || return 1
    [[ $1 == 'upgrade' ]] && install='--install'
    helm $1 $release $chart \
        $install \
        --repo $repo \
        --version $v \
        --namespace $ns \
        --create-namespace \
        --set controller.kind=DaemonSet \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.service.type=NodePort \
        --set controller.service.ports.http=$http \
        --set controller.service.ports.https=$https \
        --set controller.extraArgs.default-ssl-certificate="$ns/$tls"
}
template(){
    helmAction template |tee $manifest
}
upChart(){
    helmAction upgrade # FAILing
}
upManifest(){
    template && kubectl apply -f $manifest
    # kubectl wait -n $ns \
    #     --for=condition=ready pod \
    #     --selector=app.kubernetes.io/component=controller \
    #     --timeout=90s
}
teardown(){
    kubectl get -n stack-test 2>/dev/null &&
        kubectl delete -f $usage

    helm uninstall -n $ns $release ||
        kubectl delete -f $manifest

    resources='deploy,ds,svc,ep,ClusterIP,ingress,cm,sa,secret,validatingwebhookconfigurations,clusterrole,clusterrolebinding'
    kubectl -n $ns get $resources |grep -- -nginx
}

pushd ${BASH_SOURCE%/*} 2>/dev/null || push . || exit 
"$@"
popd