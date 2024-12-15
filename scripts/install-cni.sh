#!/usr/bin/env bash
###################################
# Install K8s CNI (idempotent)
# ARGs: ['eBPF' (to mount bpffs)]
###################################
unset eBPF
[[ ${1,,} =~ 'bpf' ]] && eBPF=yes

ARCH=$(uname -m)
[[ $ARCH ]] || ARCH=amd64
[[ $ARCH = aarch64 ]] && ARCH=arm64
[[ $ARCH = x86_64  ]] && ARCH=amd64

export KUBECONFIG=/etc/kubernetes/admin.conf

ok(){
    [[ $eBPF ]] || return 
    ## BPF must be mounted 
    [[ $(mount |grep /sys/fs/bpf) ]] && return 
    
    # Mount it directly
    #sudo mount bpffs /sys/fs/bpf -t bpf
    
    # Mount it using /etc/fstab method  
    [[ $(cat /etc/fstab |grep bpffs) ]] || {
        # Append this mount if not exist 
        printf "%s\n" 'bpffs                      /sys/fs/bpf             bpf     defaults 0 0' \
            |sudo tee -a /etc/fstab
    }
}
ok || exit $?

ok(){
    # Install CNI Plugins else fail
    # https://github.com/containernetworking/plugins/releases
    #ver='v1.5.1' # 2024-06-30
    ver='v1.6.0'  # 2024-06-30 @ K8s v1.29.6, 2024-11-30 @ K8s v1.30.1
    arch=${ARCH:-amd64}
    to=/opt/cni/bin # /etc/cni/net.d content created by CNI (deletable on teardown)
    [[ -d $to && $($to/loopback 2>&1 |grep $ver) ]] &&
       return 0
    
    sudo mkdir -p $to
    base="https://github.com/containernetworking/plugins/releases/download/$ver"
    curl -sSL "$base/cni-plugins-linux-${arch}-${ver}.tgz" \
        |sudo tar -C $to -xz

    # Verify loopback else fail
    [[ -d $to && $($to/loopback 2>&1 |grep $ver) ]] || return 10
}
ok || exit $?

ok(){
    # calicoctl CLI : https://docs.tigera.io/calico/latest/operations/calicoctl/install
    ver='v3.29.1'
    url=https://github.com/projectcalico/calico/releases/download/$ver/calicoctl-linux-${ARCH:-amd64}
    dir=/usr/local/bin
    file=calicoctl
    [[ $(type -t $file) && $($file version |grep v$ver) ]] && return 
    sudo curl -f -sSL -o $dir/$file $url &&
        sudo chmod 0755 $dir/$file &&
            sudo KUBECONFIG=$KUBECONFIG $file version |grep $ver ||
                return 404
}
ok || exit $?

ok(){
    # cilium CLI : https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
    url=https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt
    ver=$(curl -s $url) 
    echo $ver |grep 'v' || return 1
    tarball="cilium-linux-${ARCH:-amd64}.tar.gz"
    url=https://github.com/cilium/cilium-cli/releases/download/${ver}/$tarball{,.sha256sum}
    dir=/usr/local/bin
    file=cilium
    [[ $(type -t $file) && $($file version |grep v$ver) ]] &&
        return 

    curl -f -sSL --remote-name-all $url &&
        sha256sum --check $tarball.sha256sum &&
            sudo tar xzvfC $tarball . &&
                rm $tarball{,.sha256sum} &&
                    sudo mv $file $dir/$file ||
                        return 404

    sudo KUBECONFIG=$KUBECONFIG $file version |grep $ver ||
        return 555
}
ok || exit $?
