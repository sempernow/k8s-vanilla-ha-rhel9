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
cn=kube.lime.lan
crt=tls/$cn/$cn.crt
key=tls/$cn/$cn.key

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
e2e(){
    _e2e(){
        usage=ingress-nginx-usage.yaml
        # See ingress-nginx-kind-usage.yaml
        [[ $(kubectl -n stack-test get pod -l app=foo 2>/dev/null) ]] ||
            kubectl config set-context --current --namespace stack-test
        kubectl apply -f $usage
        for pod in foo bar;do 
            kubectl wait -n stack-test \
                --for=condition=ready pod \
                --selector=app=$pod \
                --timeout=90s 
        done 
        for pod in foo bar;do 
            [[ $(kubectl -n stack-test get pod -l app=$pod 2>/dev/null) ]] || {
                echo "Pod $pod not ready. Wait a bit and try again."
                return 1
            }
        done

    }
    get(){
        # Each control node is a cluster endpoint, so find first:
        ip=$(kubectl get node -o jsonpath='{.items[0].status.addresses[*].address}' \
                |cut -d' ' -f1
        )
        # Each service (http/https) port is wired to a nodePort (@ baremetal settings): 
        # GET NodePort of HTTP svc:
        p=$(kubectl get -n ingress-nginx svc ingress-nginx-controller \
                -o jsonpath='{.spec.ports[?(@.name=="'http'")].nodePort}'
        )
        # Concat response bodies:
        curl -fs http://$ip:$p/{foo,bar}/hostname
    }
    export -f get 
    echo '🧪 === E2E connectivi1ty test : Ingress <=> Service <=> Pod <=> container'
    _e2e || return 503
    echo "  Want: foobar"
    seq 10 |xargs -n1 /bin/bash -c ' 
        got="$(get || echo ERR:$?)"
        [[ $got == foobar ]] && x=✅ || x=❌
        echo "  Got : $got  $x"
        [[ $got == foobar ]] && exit 0 || sleep 5 
    ' _ || return 404
    echo '🚧 === Teardown'
    kubectl delete -f $usage
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