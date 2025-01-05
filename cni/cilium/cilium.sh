#!/usr/bin/env bash
APP=cilium
v=1.16.5

download(){
    # CLI : https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
    dir="cilium-cli"
    ./$dir/cilium version 2>&1 || {
        mkdir -p $dir
        pushd $dir || return 11
        url=https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt
        ver=$(curl -s $url) # v0.16.22
        echo $ver |grep 'v' || return 12
        arch=${ARCH:-amd64}
        [[ "$(uname -m)" = "aarch64" ]] && arch=arm64
        tarball="cilium-linux-${arch}.tar.gz"
        url=https://github.com/cilium/cilium-cli/releases/download/${ver}/$tarball{,.sha256sum}
        curl -L --fail --remote-name-all $url &&
            sha256sum --check $tarball.sha256sum &&
                sudo tar xzvfC $tarball . &&
                    rm $tarball{,.sha256sum}
        popd
    }

    # Chart : https://artifacthub.io/packages/helm/cilium/cilium/
    # Images : https://github.com/cilium/cilium/releases
    ver='1.16.4' 
    repo='cilium'
    chart='cilium'
    helm repo update $repo
    helm pull $repo/$chart --version $ver &&
        tar -xaf ${chart}-$ver.tgz &&
            cp -p $chart/values.yaml . &&
                type -t hdi >/dev/null 2>&1 &&
                    hdi $chart                
    rm -rf $chart
}

install_by_cli(){
    cilium install \
        --set debug.enabled='true' \
        --set k8sServiceHost="${K8S_CONTROL_PLANE_IP}" \
        --set k8sServicePort="${K8S_CONTROL_PLANE_PORT}" \
        --set cluster.name=${K8S_CLUSTER_NAME} \
        --set rollOutCiliumPods='true' \
        --set l2announcements.enabled='true' \
        --set l2podAnnouncements.enabled='true' \
        --set l2podAnnouncements.interface="$K8S_NETWORK_DEVICE" \
        --set bgp.enabled='false' \
        --set bgp.announce.loadbalancerIP='true' \
        --set bgp.announce.podCIDR='true' \
        --set bgpControlPlane.enabled='true' \
        --set bpf.autoMount.enabled='true' \
        --set bpf.masquerade='true' \
        --set bpf.datapathMode='veth' \
        --set waitForKubeProxy='false' \
        --set cni.install='true' \
        --set envoyConfig.enabled='true' \
        --set identityAllocationMode='crd' \
        --set ipam.mode=kubernetes \
        --set ipam.operator.clusterPoolIPv4PodCIDRList[0]="$K8S_POD_CIDR" \
        --set ipam.operator.clusterPoolIPv4MaskSize="$K8S_NODE_CIDR_MASK" \
        --set ipam.operator.clusterPoolIPv6PodCIDRList[0]="$K8S_POD_CIDR6" \
        --set ipam.operator.clusterPoolIPv6MaskSize="$K8S_NODE_CIDR6_MASK" \
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
        --set logSystemLoad='true' \
        --set enableIPv4Masquerade='true' \
        --set enableIPv6Masquerade='true' \
        --set loadBalancer.algorithm=maglev \
        --set loadBalancer.mode=dsr \
        --set envoy.enabled='true' \
        --set operator.enabled='true' \
        --set operator.rollOutPods='true' \
        --set nodeinit.enabled='true' \
        --set preflight.enabled='true' \
        --version="$v" #--dry-run-helm-values

        #--chart-directory="$APP"
        
}
install_by_helm(){
    values=values-bpf.yaml
    
    [[ -r ${APP}-$v.tgz ]] || {
        helm repo add $APP https://helm.cilium.io/
        helm repo update $APP
        helm pull $APP/$APP
    }
    tar -xaf ${APP}-$v.tgz &&
        helm upgrade --install -f $values $APP $APP/ #&& rm -rf $APP

    # kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-cilium": "true"}}}}}'
}

teardown(){
    helm -n kube-system uninstall $APP
    cilium uninstall || echo ERR : $APP $FUNCNAME : $?
}

pushd "${BASH_SOURCE%/*}" || pushd . || return 1
"$@" || code=$?
popd 
[[ $code ]] && echo ERR : ${BASH_SOURCE##*/} : $? || echo


exit
####

# Cilium app logs
kubectl -n kube-system logs -l k8s-app=cilium

# CM
kubectl -n kube-system get configmap cilium-config -o yaml

# Egress issues
cilium egress list

