#!/usr/bin/env bash
################################################
# Provision CRI for K8s (idempotent)
################################################
# >>>  ALIGN apps VERSIONs with K8s version  <<<
################################################

ARCH="$(uname -m)"
[[ "$ARCH" ]] || ARCH=amd64
[[ "$ARCH" == 'x86_64' ]] && ARCH=amd64

registry="http://${CNCF_REGISTRY_ENDPOINT:-k8s.registry.io}"

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
    # INSECURE (LOCAL) REGISTRY :
    #export registry='http://registry.local:5000'

    conf=/etc/containerd/config.toml
    [[ -f $conf ]] && return 0
    sudo mkdir -p /etc/containerd
    cat <<-EOH |sudo tee $conf
	## containerd configured for K8s : runc, systemd, and registry ($registry) 
    ## Default : containerd config default |sudo tee /etc/containerd/config.toml
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
    # Verify file else fail
    [[ $(cat $conf |grep $registry) ]] || return 30
}
ok || exit $?

ok(){
    # Configure containerd as a systemd service (containerd.service) else fail
    url='https://raw.githubusercontent.com/containerd/containerd/main/containerd.service'
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
    [[ $(containerd config dump |grep $registry) ]] || return 50
}
ok || exit $?


ok(){
    # Install CRI tools (cri-tools) alse fail
    ver="v1.29.0"
    arch=${ARCH:-amd64}
    base="https://github.com/kubernetes-sigs/cri-tools/releases/download/$ver"
    dst=/usr/local/sbin
    [[ $(crictl --version 2>&1 |grep $ver) ]] || \
        curl -sSL "$base/crictl-${ver}-linux-${arch}.tar.gz" \
            |sudo tar -C $dst -xz
    [[ $(critest --version 2>&1 |grep $ver) ]] || \
        curl -sSL "$base/critest-${ver}-linux-${arch}.tar.gz" \
            |sudo tar -C $dst -xz

    dst=/usr/local/bin
    [[ $(crictl --version 2>&1 |grep $ver) ]] \
        && sudo ln -sf /usr/local/sbin/crictl $dst \
        || return 60

    [[ $(critest --version 2>&1 |grep $ver) ]] \
        && sudo ln -sf /usr/local/sbin/critest $dst \
        || return 61
}
ok || exit $?

echo ok

exit 0
######

################
###  DEV/TEST 
################

☩ ssh a3 sudo /usr/local/bin/crictl --runtime-endpoint unix:///run/containerd/containerd.sock pull busybox
Image is up to date for sha256:65ad0d468eb1c558bf7f4e64e790f586e9eda649ee9f130cd0e835b292bbc5ac

x1@XPC [12:28:50] [1] [#0] /s/DEV/devops/infra/kubernetes/k8s-vanilla-ha/rhel9.4-hyperv
☩ ssh a3 sudo /usr/local/bin/crictl --runtime-endpoint unix:///run/containerd/containerd.sock images
IMAGE                       TAG                 IMAGE ID            SIZE
docker.io/library/busybox   latest              65ad0d468eb1c       2.16MB


echo "=== @ CRI : cri-tools"
ver="v1.29.0"
[[ $(crictl --version 2>&1 |grep $ver) ]] && return 0
arch=${ARCH:-amd64}
base="https://github.com/kubernetes-sigs/cri-tools/releases/download/$ver"
dst=/usr/local/sbin
curl -sSL "$base/crictl-${ver}-linux-${arch}.tar.gz" \
|sudo tar -C $dst -xz


[[ $(crictl --version 2>&1 |grep $ver) ]] || return 1





