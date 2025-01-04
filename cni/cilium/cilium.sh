#!/usr/bin/env bash
APP=cilium
v=1.16.5

install_by_cli(){
    cilium install \
        --set k8sServiceHost="${K8S_CONTROL_PLANE_IP}" \
        --set k8sServicePort="${K8S_CONTROL_PLANE_PORT}" \
        --set cluster.name=${K8S_CLUSTER_NAME} \
        --set l2announcements.enabled='true' \
        --set l2announcements.interface="$K8S_NETWORK_DEVICE" \
        --set bgp.enabled='true' \
        --set bgp.announce.loadbalancerIP='true' \
        --set bgp.announce.podCIDR='true' \
        --set bgpControlPlane.enabled='true' \
        --set bpf.autoMount.enabled='true' \
        --set bpf.masquerade='true' \
        --set bpf.datapathMode='veth' \
        --set bpf.waitForKubeProxy='false' \
        --set bpf.cni.install='true' \
        --set identityAllocationMode='crd' \
        --set ipam.mode=kubernetes \
        --set ipam.operator.clusterPoolIPv4PodCIDRList[0]="$K8S_POD_CIDR" \
        --set ipam.operator.clusterPoolIPv4MaskSize="$K8S_NODE_CIDR_MASK" \
        --set nodeIPAM.enabled='true' \
        --set tunnelProtocol='' \
        --set routingMode=native \
        --set autoDirectNodeRoutes='true' \
        --set directRoutingSkipUnreachable='true' \
        --set ipv4NativeRoutingCIDR="$K8S_POD_CIDR" \
        --set ipv6NativeRoutingCIDR="$K8S_POD_CIDR6" \
        --set ipMasqAgent.enabled='false' \
        --set ipv4.enabled='true' \
        --set ipv6.enabled='false' \
        --set k8s.requireIPv4PodCIDR='true' \
        --set k8s.requireIPv6PodCIDR='false' \
        --set kubeProxyReplacement='true' \
        --set kubeProxyReplacementHealthzBindAddr='0.0.0.0:10256' \
        --set l2NeighDiscovery.enabled='true' \
        --set l7Proxy='true' \
        --set enableIPv4Masquerade='true' \
        --set enableIPv6Masquerade='true' \
        --set loadBalancer.algorithm=maglev \
        --set loadBalancer.mode=dsr \
        --set operator.enabled='true' \
        --set operator.rollOutPods='true' \
        --set nodeinit.enabled='true' \
        --set preflight.enabled='true' \
        --version="$v" #--chart-directory="$APP"
}
install_by_helm(){
    values=values-bpf.yaml
    
    pushd "${BASH_SOURCE%/*}" || pushd . || return 11
    
    [[ -r ${APP}-$v.tgz ]] || {
        helm repo add $APP https://helm.cilium.io/
        helm repo update $APP
        helm pull $APP/$APP
    }
    tar -xaf ${APP}-$v.tgz &&
        helm upgrade --install -f $values $APP $APP/ #&& rm -rf $APP

    # kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-cilium": "true"}}}}}'

    # tar -xaf ${APP}-$v.tgz &&
    #     helm upgrade --install $APP $APP/cilium \
    #         --namespace kube-system \
    #         --set image.pullPolicy=IfNotPresent \
    #         --set hubble.relay.enabled=true \
    #         --set hubble.ui.enabled=true \
    #         --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}" \
    #         --set kubeProxyReplacement=true \
    #         --set hostServices.enabled=true \
    #         --set externalIPs.enabled=true \
    #         --set nodePort.enabled=true \
    #         --set loadBalancer.mode=dsr \
    #         --set egressGateway.enabled=true \
    #         --set ingressController.enabled=true \
    #         --set cni.chainingMode=none \
    #         --set enableIPv4Masquerade=true \
    #         --set enableIPv6Masquerade=false \
    #         --set enableBPFMasquerade=true \
    #         --set ipMasqAgent.enabled=false \
    #         --set ipv4.enabled=true \
    #         --set ipv6.enabled=false \
    #         --set ipam.mode=kubernetes \
    #         --set bpf.masquerade=true \
    #         --set bpf.mount=/sys/fs/bpf \
    #         --set routingMode=native \
    #         --set ipv4-native-routing-cidr=10.244.0.0/16 \
    #         --set auto-direct-node-routes=true \
    #             && rm -rf $APP

    code=$?
    popd
    return $code
}


# --ipv4-native-routing-cidr
# --enable-ipv4=true 
# --enable-ipv4-masquerade=true 
# --enable-ip-masq-agent=false 
# --routing-mode=native 
# --ipam=kubernetes"

teardown(){
    helm -n kube-system uninstall $APP
    cilium uninstall || echo ERR : $APP $FUNCNAME : $?
}

"$@" || echo ERR : $?

exit
####

# Cilium app logs
kubectl -n kube-system logs -l k8s-app=cilium

# CM
kubectl -n kube-system get configmap cilium-config -o yaml

# Egress issues
cilium egress list

