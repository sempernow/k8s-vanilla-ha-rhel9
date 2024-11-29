#!/usr/bin/env bash
################################################
# Provision CRI for K8s (idempotent)
################################################
# >>>  ALIGN apps VERSIONs with K8s version  <<<
################################################
ARCH=$(uname -m)
[[ $ARCH ]] || ARCH=amd64
[[ $ARCH = aarch64 ]] && ARCH=arm64
[[ $ARCH = x86_64  ]] && ARCH=amd64

REGISTRY="http://${CNCF_REGISTRY_ENDPOINT:-k8s.registry.io}"

ok(){
    # Install runc (containerd dependency) else fail
    # https://github.com/opencontainers/runc/releases
    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    ver='1.1.13'
    [[ $(runc -v 2>&1 |grep $ver) ]] && return 0 
    arch=${ARCH:-amd64}
    url="https://github.com/opencontainers/runc/releases/download/v${ver}/runc.$arch"
    dst=/usr/local/sbin
    sudo curl -o $dst/runc -sSL $url && sudo chmod 0755 $dst/runc
    [[ $(runc -v 2>&1 |grep $ver) ]] || return 10
}
ok || exit $?

ok(){
    # Install containerd binaries else fail
    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    # https://github.com/containerd/containerd/releases
    ver='1.7.19'
    arch=${ARCH:-amd64}
    tarball="containerd-${ver}-linux-${arch}.tar.gz"
    [[ $(containerd --version 2>&1 |grep v$ver) ]] && return 0
    base=https://github.com/containerd/containerd/releases/download/v$ver
    curl -sSL $base/$tarball |sudo tar -C /usr/local -xz
    [[ $(containerd --version 2>&1 |grep v$ver) ]] || return 20
}
ok || exit $?

ok(){
    # containerd config (TOML)
    # https://github.com/containerd/containerd/blob/main/docs/cri/config.md
    # https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.8.md
    # https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd
    # PRINT DEFAULT : 
        # containerd config default |sudo tee /etc/containerd/config.toml
    # MODS @ K8s :
        # https://v1-29.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
        # [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        #   [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        #     SystemdCgroup = true
        # [plugins."io.containerd.grpc.v1.cri"]
        #   sandbox_image = "registry.k8s.io/pause:3.2"
    # LOCAL (INSECURE) REGISTRY :
    registry=${REGISTRY:-k8s.registry.io}

    conf=/etc/containerd/config.toml
    [[ -f $conf ]] && return 0
    sudo mkdir -p /etc/containerd
    cat <<-EOH |sudo tee $conf
	## Configured for K8s : runc, systemd, and registry ($registry) 
	version = 2
	[plugins]
	[plugins."io.containerd.grpc.v1.cri"]
	  sandbox_image = "$registry/pause:3.9"
	  [plugins."io.containerd.grpc.v1.cri".containerd]
	    discard_unpacked_layers = true
	    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
	      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
	        runtime_type = "io.containerd.runc.v2"
	        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
	          SystemdCgroup = true
	  [plugins."io.containerd.grpc.v1.cri".registry]
	    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
	      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$registry"]
	        endpoint = ["http://$registry"]
	    [plugins."io.containerd.grpc.v1.cri".registry.configs]
	      [plugins."io.containerd.grpc.v1.cri".registry.configs."$registry".tls]
	        insecure_skip_verify = true
	EOH
    [[ $(cat $conf |grep $registry) ]] || return 30
}
ok || exit $?

ok(){
    # Configure containerd as a systemd service else fail
    url=https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    sys=/usr/lib/systemd/system
    [[ -f $sys/containerd.service ]] && return 0
    sudo mkdir -p $sys
    sudo curl -o $sys/containerd.service -sSL $url || return 40
}
ok || exit $?

ok(){
    # Enable/start the service
    sudo systemctl daemon-reload
    sudo systemctl enable --now containerd.service

    # Validate config else fail
    registry=${REGISTRY:-k8s.registry.io}
    [[ $(containerd config dump |grep $registry) ]] || return 50
}
ok || exit $?

ok(){
    # Install CRI tools (cri-tools) alse fail
    ver="v1.29.0"
    arch=${ARCH:-amd64}
    base="https://github.com/kubernetes-sigs/cri-tools/releases/download/$ver"
    suffix="${ver}-linux-${arch}.tar.gz"
    sbin=/usr/local/sbin
    [[ $(crictl --version 2>&1 |grep $ver) ]] ||
        curl -sSL "$base/crictl-$suffix" |sudo tar -C $sbin -xz
    [[ $(critest --version 2>&1 |grep $ver) ]] ||
        curl -sSL "$base/critest-$suffix" |sudo tar -C $sbin -xz

    bin=/usr/local/bin
    [[ $(crictl --version 2>&1 |grep $ver) ]] &&
        sudo ln -sf $sbin/crictl $bin ||
            return 60

    [[ $(critest --version 2>&1 |grep $ver) ]] &&
        sudo ln -sf $sbin/critest $bin ||
            return 61
}
ok || exit $?
