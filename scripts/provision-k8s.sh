#!/usr/bin/env bash
###############################################################################
# Provision tools for a production K8s cluster built of kubeadm
# https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#
# ARGs: [K8S_VERSION [K8S_REGISTRY]
###############################################################################
################################################
# >>>  ALIGN apps VERSIONs with K8s version  <<<
################################################
ARCH=$(uname -m)
[[ $ARCH ]] || ARCH=amd64
[[ $ARCH = aarch64 ]] && ARCH=arm64
[[ $ARCH = x86_64  ]] && ARCH=amd64

ok(){
    # Verify containerd is installed else fail
    [[ $(type -t containerd) ]] || return 1 
}
ok || exit $?

# An undocumented dependency
sudo dnf install -y conntrack

ok(){
    # Install CNI Plugins else fail
    # https://github.com/containernetworking/plugins/releases
    #ver="v1.5.1" # 2024-06-30
    ver="v1.6.0"  # 2024-06-30 @ K8s v1.29.6, 2024-11-30 @ K8s v1.30.1
    arch=${ARCH:-amd64}
    dst=/opt/cni/bin # /etc/cni/net.d content created by CNI (deletable on teardown)
    [[ -d $dst && $($dst/loopback 2>&1 |grep $ver) ]] && return 0
    sudo mkdir -p $dst
    base="https://github.com/containernetworking/plugins/releases/download/$ver"
    curl -sSL "$base/cni-plugins-linux-${arch}-${ver}.tgz" \
        |sudo tar -C $dst -xz

    # Verify loopback else fail
    [[ -d $dst && $($dst/loopback 2>&1 |grep $ver) ]] || return 10
}
ok || exit $?

ok(){
    # Install Kubernetes else fail.
    # The server download has full set of binaries,
    # but do not install the Static Pod equivalents.
    # https://github.com/kubernetes/kubernetes/releases
    # https://kubernetes.io/releases/
    # https://www.downloadkubernetes.com/
    # https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    arch=${ARCH:-amd64}
    ver=$1
    [[ $ver ]] || ver="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
    [[ $ver ]] || return 20
    [[ $(type -t kubelet) && $(kubeadm version |grep v$ver) ]] &&
        return 0
    base="https://dl.k8s.io/v${ver}" 
    tarball=kubernetes-server-linux-${arch}.tar.gz
    curl -sSL $base/$tarball |tar -xz ||
        return 22
    src=kubernetes/server/bin 
    dst=/usr/local/bin # Abide LFS conventions for binary (non-pkg) installs
    subset='
        kubelet
        kubeadm
        kubectl
        kubectl-convert
        kube-aggregator
        kube-log-runner
        mounter
        apiextensions-apiserver
    '
    printf "%s\n" $subset |xargs -I{} sudo cp $src/{} $dst/
    kubelet --version || return 24
    kubectl version --client=true || return 26
    kubeadm version || return 28
}
ok $1 || exit $?

ok(){
    # List all container images required by kubelet (K8s Static Pods)
    ver=$1
    [[ $ver ]] ||
        ver="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
    reg="${2:-registry.k8s.io}"
    conf=kubeadm-config-images.yaml
    [[ -f ${conf/.yaml/.log} ]] && return 0
	cat <<-EOH |tee $conf
	apiVersion: kubeadm.k8s.io/v1beta3
	kind: ClusterConfiguration
	kubernetesVersion: $ver
	imageRepository: $reg
	EOH
    kubeadm config images list --config $conf |tee ${conf/.yaml/.log}
}
ok $1 $2 || exit $?

ok(){
    # Configure kubelet as systemd service (kubelet.service) else fail
    # https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    ver='0.16.2' # Has no releases page!
    base="https://raw.githubusercontent.com/kubernetes/release/v${ver}/cmd/krel/templates/latest"
    bin=/usr/local/bin # Abide LFS conventions for binary (non-pkg) installs
    sys=/usr/lib/systemd/system
    [[ -d $sys/kubelet.service.d ]] && return 0
    sudo mkdir -p $sys/kubelet.service.d
    
    url="$base/kubelet/kubelet.service"
    wget --spider -q $url || return 44
    wget -O - $url \
        |sed "s:/usr/bin:$bin:g" \
        |sudo tee $sys/kubelet.service ||
            return 45
    
    url="$base/kubeadm/10-kubeadm.conf"
    wget --spider -q $url || return 46
    wget -O - $url \
        |sed "s:/usr/bin:$bin:g" \
        |sudo tee $sys/kubelet.service.d/10-kubeadm.conf ||
            return 47

    [[ $(type -t kubelet) && $(kubeadm version |grep v$ver) ]] ||
        return 48
    
    sudo systemctl enable --now kubelet ||
        return 49
}
ok || exit $?
