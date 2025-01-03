#!/usr/bin/env bash
###############################################################################
# Install and configure K8s for production cluster by kubeadm (idempotent)
# https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#
# ARGs: [K8S_VERSION [K8S_REGISTRY]] 
###############################################################################
K8S_VERSION=$1
[[ $K8S_VERSION ]] || K8S_VERSION="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
[[ $K8S_VERSION ]] || K8S_VERSION=1.29.6
K8S_REGISTRY=${2:-registry.k8s.io}
ARCH=$(uname -m)
[[ $ARCH ]] || ARCH=amd64
[[ $ARCH = aarch64 ]] && ARCH=arm64
[[ $ARCH = x86_64  ]] && ARCH=amd64

# Verify containerd else fail
[[ $(type -t containerd) ]] || return 1 

# Undocumented dependency that is usually installed already
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
    printf "%s\n" $subset |xargs -I{} sudo install $src/{} $to
    kubelet --version || return 24
    kubectl version --client=true || return 26
    kubeadm version || return 28
}
ok || exit $?

ok(){
    # List all container images required by kubelet (K8s Static Pods)
    ver="$K8S_VERSION"
    [[ $ver ]] || return 30
    reg="${K8S_REGISTRY:-registry.k8s.io}"
    conf=kubeadm-config-images.yaml
    [[ -f ${conf/.yaml/.log} ]] && return 0
	cat <<-EOH |tee $conf
	---
	# Generated by ${BASH_SOURCE##*/}
	apiVersion: kubeadm.k8s.io/v1beta3
	kind: ClusterConfiguration
	kubernetesVersion: $ver
	imageRepository: $reg
	EOH
    kubeadm version || return 33
    echo '# Generated by '${BASH_SOURCE##*/} |tee ${conf/.yaml/.log}
    kubeadm config images list --config $conf |tee -a ${conf/.yaml/.log}
}
ok || exit $?

ok(){
    # Configure kubelet as systemd service (kubelet.service) else fail
    # https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
    kubelet --version || return 40
    ver='0.16.2' # Has no releases page!
    base="https://raw.githubusercontent.com/kubernetes/release/v${ver}/cmd/krel/templates/latest"
    bin=/usr/local/bin # Abide LFS conventions for binary (non-pkg) installs
    sys=/usr/lib/systemd/system
    [[ -d $sys/kubelet.service.d ]] && return 0
    sudo mkdir -p $sys/kubelet.service.d
    
    # Pull and save kubelet.service configs, 
    # both modified to match kubeadm location (binary v. RPM install method).

    url="$base/kubelet/kubelet.service"
    wget --spider -q $url || return 44
    wget -nvO - $url \
        |sed "s:/usr/bin:$bin:g" \
        |sudo tee $sys/kubelet.service ||
            return 45
    
    url="$base/kubeadm/10-kubeadm.conf"
    wget --spider -q $url || return 46
    wget -nvO - $url \
        |sed "s:/usr/bin:$bin:g" \
        |sudo tee $sys/kubelet.service.d/10-kubeadm.conf ||
            return 47
    
    sudo systemctl enable --now kubelet ||
        return 49
}
ok || exit $?

ok(){
    #########################################################
    ## Install etcd, etcdctl, etcutl onto this host
    ##
    ## WARNING:
    ##  If cluster runs its etcd as Static Pod, 
    ##  then do *not* run etcd.service on host,
    ##  else conflicts are likely to occur.
    ## 
    ######################################################### 
    ## Align ETCD_VERSION with that of target clusters' etcd:
    # ver=1.29.6 
    # kubeadm config images list --kubernetes-version $ver
    # Or, at an existing target cluster
    # etcd_pod_name=etcd-a1 
    # kubectl exec -it $etcd_pod_name -- etcd --version 
    ETCD_VERSION=v3.5.12
    dir=etcd-${ETCD_VERSION}-linux-amd64
    archive=$dir.tar.gz
    to=/usr/local/bin

    [[ ! -f $archive ]] &&
        wget -nv https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/$archive &&
            tar -xvf $archive

    [[ -d $dir ]] &&
        sudo install $dir/etc* $to
    
    etcdutl version || return 55
}
ok || exit $?
