#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Idempotent:
# - Apply ingress-nginx Ingress Controller configured for kind cluster.
# - Apply E2E test of Ingress/App
# -----------------------------------------------------------------------------
manifest=ingress-nginx-baremetal.yaml
usage=ingress-nginx-usage.yaml

v=v1.11.3
url=https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$v/deploy/static/provider/baremetal/deploy.yaml
[[ -r $manifest ]] || curl -sSL $url -o $manifest

[[ $(kubectl -n ingress-nginx get pod 2>/dev/null |grep ingress-nginx-controller) ]] ||
    kubectl apply -f $manifest ||
        kubectl apply -f $url &&
            kubectl wait -n ingress-nginx \
                --for=condition=ready pod \
                --selector=app.kubernetes.io/component=controller \
                --timeout=90s

# See ingress-nginx-kind-usage.yaml
e2e(){
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
    # Ingress NGINX on baremetal : each service (http/https) port is wired to a nodePort. 
    p=$(kubectl get -n ingress-nginx svc ingress-nginx-controller \
            -o jsonpath='{.spec.ports[?(@.name=="'http'")].nodePort}'
    )

    curl -s http://$ip:$p/foo/hostname &&
        curl -s http://$ip:$p/bar/hostname #> foobar
}
export -f get 

echo '=== E2E connectivity test : Ingress/Service/Pod/container'
e2e 
echo "  Want: foobar"
seq 10 |xargs -n1 /bin/bash -c ' 
    echo "  Got : $1"
    [[ $1 != foobar ]] && sleep 5 
' _ $(get) 

[[ $1 && $1 != 'teardown' ]] && kubectl -n stack-test get pod -o wide
[[ $1 == teardown ]] && kubectl delete -f $usage

exit 0
######
