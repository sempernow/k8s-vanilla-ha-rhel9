#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# E2E Ingress Test : Ingress <=> Service <=> Pod <=> container
# -----------------------------------------------------------------------------
export ns_app=test-ingress
export ns_ingress=ingress-nginx
export host=e2e.$K8S_FQDN
export ca_cert=${DOMAIN_CA_CERT}

teardown(){
    echo '🚧 === Teardown'
    kubectl delete -f $ns_app.yaml
    kubectl config set-context --current --namespace default
    kubectl delete ns $ns_app
}
export -f teardown

e2e(){
    up(){
        [[ $(kubectl -n $ns_app pod -l app=foo 2>/dev/null) ]] || {
            kubectl create ns $ns_app
        }
        kubectl config set-context --current --namespace $ns_app
        kubectl apply -f $ns_app.yaml
        for pod in foo bar;do 
            kubectl wait \
                --for=condition=ready pod \
                --selector=app=$pod \
                --timeout=90s 
        done 
        for pod in foo bar;do 
            [[ $(kubectl get pod -l app=$pod 2>/dev/null) ]] || {
                echo "Pod $pod not ready. Waiting ..."
                sleep 2
            }
        done
    }
    port(){
        # Each service (http|https) port is wired to a nodePort (@ baremetal settings)
        # GET NodePort of Service per scheme (http|https) :
        kubectl -n $ns_ingress get svc ingress-nginx-controller \
                -o jsonpath='{.spec.ports[?(@.name=="'$1'")].nodePort}'
    }
    export -f port
    ipv4(){
        kubectl get node -o jsonpath='{.items[0].status.addresses[*].address}' |cut -d' ' -f1
    }
    export -f ipv4
    get(){
        scheme="${1,,}" # http|https
        
        # FQDN or IP : If IP, then find that of first control node; each is a cluster entrypoint
        [[ $scheme == 'http' ]] &&
            host=$(ipv4)

        # Concat response bodies else return error code : agnhost GET /hostname returns hostname.
        curl -fs --cacert $ca_cert $scheme://$host:$(port $scheme)/{foo,bar}/hostname
    }
    export -f get
    scheme(){
        echo "  Want: foobar"
        seq 3 |xargs -n1 /bin/bash -c ' 
            got="$(get $1 || echo ERR:$?)"
            [[ $got == foobar ]] && x=✅ || x=❌
            echo "  Got : $got  $x"
            [[ $got == foobar ]] && exit 0 || sleep 5 
        ' _ $1 || return 404
    }
    export -f scheme

    echo '🧪 === E2E connectivi1ty test : Ingress <=> Service <=> Pod <=> container'
    up || return 503
    type get
    echo $* |xargs -n1 /bin/bash -c '
        [[ $1 == "https" ]] && host=$0 || host=$(ipv4)
        echo "🛠️ @ ${1^^}://$host:$(port $1)"
        scheme $1
    ' $host
    [[ $1 == 'teardown' ]] && teardown
}

pushd ${BASH_SOURCE%/*} 2>/dev/null || push . || exit 
"$@"
popd