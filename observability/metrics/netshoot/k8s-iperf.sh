#!/usr/bin/env bash
#################################################################
# Bandwidth (Throughput) test of your K8s Cluster (Pod) Network.
# 
# - Both same-node and cross-node cases are measured.
# - Often referred to as east-west or inter-pod traffic, 
#   these throughput measurements are expected to vary 
#   by host network, CNI provider, their configurations, 
#   and adjacent network-traffic conditions.
#################################################################
clear;echo '
=======================================================
🚀  Bandwidth test of K8s Pod Network using iperf3
'

img=nicolaka/netshoot # https://github.com/nicolaka/netshoot
p=5555

nonce="$(cat /dev/urandom |tr -dc 'a-z0-9' |fold -w 7 |head -n 1)" || 
    nonce="$(date '+%H.%M.%S%z')"
ns="test-iperf3-$nonce"

kubectl create ns $ns
kubectl get ns $ns || {
    echo "⚠  ERR : Namespace '$ns' NOT EXIST"
    exit $?
}
kubectl config set-context --current --namespace $ns

echo -e '\n🚧 === Creating the server …'

# Server
sPod=server
kubectl run $sPod --image=$img -- iperf3 -s -p $p
while [[ -z $sNode || -z $sIP ]]; do
    echo "Awaiting Node and IP status of Pod '$sPod' …" 
    export sNode=$(kubectl get pod $sPod -o jsonpath='{.spec.nodeName}')
    export sIP=$(kubectl get pod $sPod -o wide -o jsonpath='{.status.podIPs[].ip}')
    sleep 2
done

echo "✅ === Server pod '$sPod' running at node '$sNode'." 

# Clients : One case at a time
cPod=client
cNode=$sNode
echo "Next, run client pods '$cPod' sequentially (IntRA-node, IntER-node) …"

# - Same-node (IntRA-node) case
echo -e "\n📊 === Same-node ($sNode-$cNode) traffic between server '$sPod@$sNode' and client '$cPod@$cNode' [Pod@Node] …"
kubectl run $cPod -it --rm \
    --image=$img \
    --overrides='{"spec": {"nodeName": "'$sNode'"}}' \
    --restart=Never  -- \
    iperf3 -c $sIP -p $p
while kubectl get pod $cPod &> /dev/null; do
    echo "Awaiting deletion of Pod '$cPod' …"
    sleep 2
done

# - Cross-node (IntER-node) case
cNode=$(kubectl get node -oname -o yaml |yq '.[][].metadata |select (.name != "'$sNode'") |.name' |head -n1)
echo -e "\n📊 === Cross-node ($sNode-$cNode) traffic between server '$sPod@$sNode' and client '$cPod@$cNode' [Pod@Node] …"
kubectl run $cPod -it --rm \
    --image=$img \
    --overrides='{"spec": {"nodeName": "'$cNode'"}}' \
    --restart=Never  -- \
    iperf3 -c $sIP -p $p
# Teardown
echo -e '\n🚧 === Teardown'
kubectl config set-context --current --namespace default
kubectl delete ns ${ns:-___nonexistent_namespace___}
echo -e '\n======================[ DONE ]=========================\n'
