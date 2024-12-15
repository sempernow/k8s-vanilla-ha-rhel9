#!/usr/bin/env bash
###############################################################################
# Install and configure K8s for production cluster by kubeadm (idempotent)
# https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#
# ARGs: [K8S_VERSION [OCI_REGISTRY]
###############################################################################
K8S_VERSION=$1
[[ $K8S_VERSION ]] || K8S_VERSION="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
[[ $K8S_VERSION ]] || K8S_VERSION=1.29.6
OCI_REGISTRY=${2:-registry.k8s.io}
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
sudo dnf install -y conntrack || return 2

ok(){
    # Install Kubernetes else fail.
    # The server download has full set of binaries,
    # but do not install the Static Pod equivalents.
    # https://github.com/kubernetes/kubernetes/releases
    # https://kubernetes.io/releases/
    # https://www.downloadkubernetes.com/
    # https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    arch="${ARCH:-amd64}"
    ver="$K8S_VERSION"
    [[ $ver ]] || return 20
    [[ $(type -t kubelet) && $(kubeadm version |grep v$ver) ]] &&
        return 0
    # Client, server and node, where client and node are subsets of server
    base="https://dl.k8s.io/v${ver}" 
    tarball="kubernetes-server-linux-${arch}.tar.gz"
    curl -sSL $base/$tarball |tar -xz ||
        return 22
    src=kubernetes/server/bin 
    to=/usr/local/bin # Abide LFS conventions for binary (non-pkg) installs
    # If binary of static pod is installed on host, 
    # then kubelet launches it too regardless.
    # So, install this subset only, else dueling processes at host v. container.
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
    printf "%s\n" $subset |xargs -I{} sudo cp $src/{} $to/
    kubelet --version || return 24
    kubectl version --client=true || return 26
    kubeadm version || return 28
}
ok || exit $?

ok(){
    # List all container images required by kubelet (K8s Static Pods)
    ver="$K8S_VERSION"
    [[ $ver ]] || return 20
    reg="${OCI_REGISTRY:-registry.k8s.io}"
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
ok || exit $?

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

