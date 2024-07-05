#!/usr/bin/env bash
###############################################################################
# Provision tools for a production K8s cluster built of kubeadm
# https://v1-29.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
###############################################################################
################################################
# >>>  ALIGN apps VERSIONs with K8s version  <<<
################################################

ARCH="$(uname -m)"
[[ "$ARCH" ]] || ARCH=amd64
[[ "$ARCH" == 'x86_64' ]] && ARCH=amd64

ok(){
    # Verify containerd is installed else fail
    [[ $(type -t containerd) ]] || return 1 
}
ok || exit $?

ok(){
    # Install CNI Plugins else fail
    # https://github.com/containernetworking/plugins/releases
    #ver="v1.5.1" # 2024-06-30
    ver="v1.3.0"  # 2024-06-30 K8s v1.29.6
    arch=${ARCH:-amd64}
    dst=/opt/cni/bin
    [[ -d $dst && $($dst/loopback 2>&1 |grep $ver) ]] && return 0
    sudo mkdir -p "$dst"
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
    #ver="$(curl -sSL https://dl.k8s.io/release/stable.txt)" # @ v1.30.2
    ver='1.29.6'
    [[ $(type -t kubelet) && $(kubeadm version |grep v$ver) ]] && return 0
    #base="https://dl.k8s.io/release/v${ver}/bin/linux/${arch}" ## Prior scheme
    ## Current scheme: client, server and node archives, where client and node have subsets of server
    base="https://dl.k8s.io/v${ver}" 
    tarball=kubernetes-server-linux-${arch}.tar.gz
    #wget -nv $base/$tarball && tar -xaf $tarball || return 20
    curl -sSL $base/$tarball |tar -xz || return 20

    src=kubernetes/server/bin 
    dst=/usr/local/bin
    ###############################################
    # If binary of static pod installed on host, 
    # then kubelet launches it too regardless.
    ###############################################
    # find $src -maxdepth 1 -type f -perm -0755 -printf "%P\n" \
    #     |xargs -IX /bin/bash -c '
    #         sudo cp $0/$2 $1/$2 && sudo chmod 0755 $1/$2
    #     ' $src $dst X \;
    list='
        kubelet
        kubeadm
        kubectl
        kubectl-convert
        kube-aggregator
        kube-log-runner
        mounter
        apiextensions-apiserver
    '
    printf "%s\n" $list |xargs -I{} sudo cp $src/{} $dst/

    kubelet --version || return 21
    kubeadm version || return 22
    kubectl version --client=true || return 23
}
ok || exit $?

ok(){
    # List all container images required by kubelet (K8s Static Pods)
    ver='1.29.6'
    #reg=registry.local:5000
    reg='registry.k8s.io'
    conf="kubeadm-${ver}-config-images.yaml"
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
    bin=/usr/local/bin
    sys=/usr/lib/systemd/system
    [[ -d $sys/kubelet.service.d ]] && return 0
    sudo mkdir -p $sys/kubelet.service.d
    curl -sSL "$base/kubelet/kubelet.service" \
        |sed "s:/usr/bin:$bin:g" \
        |sudo tee $sys/kubelet.service
    curl -sSL "$base/kubeadm/10-kubeadm.conf" \
        |sed "s:/usr/bin:$bin:g" \
        |sudo tee $sys/kubelet.service.d/10-kubeadm.conf

    [[ $(type -t kubelet) && $(kubeadm version |grep v$ver) ]] || return 1
    
    sudo systemctl enable --now kubelet || return 1

    return 0
}
ok || exit $?

echo ok

exit 0
######

