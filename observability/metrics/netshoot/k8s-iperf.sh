#!/usr/bin/env bash
#################################################################
# Bandwidth (Throughput) test of your K8s Cluster (Pod) Network.
#
# - Performs two measurements:
#   - Same-node case
#   - Cross-node case
#
# - Throughput is expected to vary by host network,
#   CNI provider, their configurations,
#   and adjacent network-traffic conditions.
#
# ARGs: [PORT(else 5555)]
#################################################################
kubectl version >/dev/null || {
    echo REQUIREs kubectl
    exit 1
}
clear;echo '
=======================================================
🚀  Bandwidth test of K8s Pod Network using iperf3
'

img=nicolaka/netshoot       # https://github.com/nicolaka/netshoot
#img=gd9h/iperf:3.19-hard    # https://hub.docker.com/repository/docker/gd9h/iperf/general
port=${1:-5555} # Presumed okay

echo -e '\n🚧  === Create and set context to a per-run Namespace …'
nonce="$(cat /dev/urandom |tr -dc 'a-z0-9' |fold -w 7 |head -n 1)" || 
    nonce="$(date '+%H.%M.%S%z')"
ns="test-iperf3-$nonce"
kubectl create ns $ns
kubectl get ns $ns || {
    echo "⚠   === ERR : Namespace '$ns' NOT EXIST"
    exit 2
}
kubectl config set-context --current --namespace $ns

echo -e "\n🚧  === Traffic port: $port"

echo -e '\n🚧  === Creating the server …'

# Server
sPod=server
kubectl run $sPod --image=$img -- iperf3 -s -p $port
while [[ -z $sNode || -z $sIP ]]; do
    echo "Awaiting Node and IP status of Pod '$sPod' …" 
    export sNode=$(kubectl get pod $sPod -o jsonpath='{.spec.nodeName}')
    export sIP=$(kubectl get pod $sPod -o wide -o jsonpath='{.status.podIPs[].ip}')
    sleep 2
done

echo "✅  === Server pod '$sPod' running at node '$sNode'." 

# Clients : One case at a time
cPod=client
cNode=$sNode
echo "Next, run client pods '$cPod' sequentially (Same-node, Cross-node) …"

# - Same-node (IntRA-node) case
echo -e "\n📊  === Same-node ($sNode-$cNode) traffic between server '$sPod@$sNode' and client '$cPod@$cNode' [Pod@Node] …"
kubectl run $cPod -it --rm \
    --image=$img \
    --overrides='{"spec": {"nodeName": "'$sNode'"}}' \
    --restart=Never  -- \
    iperf3 -c $sIP -p $port
while kubectl get pod $cPod &> /dev/null; do
    echo "Awaiting deletion of Pod '$cPod' …"
    sleep 2
done

# - Cross-node (IntER-node) case
cNode=$(kubectl get node -o jsonpath='{range .items[*]}{@.metadata.name}{"\n"}{end}' |grep -v "^$sNode" |head -n1)
echo -e "\n📊  === Cross-node ($sNode-$cNode) traffic between server '$sPod@$sNode' and client '$cPod@$cNode' [Pod@Node] …"
kubectl run $cPod -it --rm \
    --image=$img \
    --overrides='{"spec": {"nodeName": "'$cNode'"}}' \
    --restart=Never  -- \
    iperf3 -c $sIP -p $port

# Teardown
echo -e '\n🚧  === Teardown'
kubectl config set-context --current --namespace default
kubectl delete ns ${ns:-___nonexistent_namespace___}
echo -e '🚧  === Done'
