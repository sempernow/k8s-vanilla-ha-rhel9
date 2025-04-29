#!/usr/bin/env bash
## EFK Stack : https://chatgpt.com/share/680e77c5-7d68-8009-b6a4-f66d608c8714
apply(){
    kubectl apply -f 01-ns.yaml
    #kubectl apply -f 02-elasticsearch.yaml
    kubectl apply -f 02-es-cluster.yaml
    kubectl apply -f 03-kibana.yaml
    #kubectl apply -f 04-fluentd.yaml
    kubectl apply -f 04-fluentbit.yaml
}
delete(){
    #kubectl delete -f 04-fluentd.yaml
    kubectl delete -f 04-fluentbit.yaml
    kubectl delete -f 03-kibana.yaml
    #kubectl delete -f 02-elasticsearch.yaml
    kubectl delete -f 02-es-cluster.yaml
    kubectl delete -f 01-ns.yaml
}
ports(){
    kubectl port-forward $(kubectl get pod -l app=kibana --no-headers |cut -d' ' -f1) 5601:5601 &
    kubectl port-forward svc/elasticsearch 9200:9200 &
    ps -aux |command grep kubectl |grep forward
}
verify(){
    # Kibana
    ip=$(k get node -o yaml |yq -Mr '.[][].status.addresses[] |select(.type == "InternalIP").address' |head -n 1)
    p=$(k get svc kibana -o yaml |yq .spec.ports[].nodePort)
    path=app/home
    curl -sIX GET http://$ip:$p/$path |grep HTTP
}

pushd ${BASH_SOURCE%/*} || pushd . || exit 1
"$@" || echo ERR $?
popd


