#!/usr/bin/env bash
APP=cilium

_install(){
    v=1.16.5
    values=values.yaml
    
    pushd "${BASH_SOURCE%/*}" || pushd . || return 11
    [[ -r ${APP}-$v.tgz ]] || {
        helm repo update $APP
        helm pull $APP/$APP
    }
    tar -xaf ${APP}-$v.tgz &&
        helm upgrade --install -f $values $APP $APP/ &&
            kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"not-kuberouter": "true"}}}}}' &&
                rm -rf $APP

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

_teardown(){
    helm -n kube-system uninstall $APP
    $APP uninstall || echo ERR : $APP $FUNCNAME : $?
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

# Remove patch : restore kube-proxy
kubectl patch ds -n kube-system kube-proxy --type=json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/not-kuberouter"}]'

#FAIL : kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{}}}}}'