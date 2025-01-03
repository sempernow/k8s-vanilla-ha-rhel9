# [Cilium](https://github.com/cilium/cilium) | [eBPF Datapath](https://docs.cilium.io/en/stable/network/ebpf/intro/)


- [LB IPAM](https://docs.cilium.io/en/stable/network/lb-ipam/) : Allows Cilium to assign IP addresses to `Service`s of type `LoadBalancer`. This functionality is __usually left up to a cloud provider__, however, when deploying in a private cloud environment, these facilities are not always available. This feature is always enabled, yet dormant until controller is awoken when the first IP Pool (`CiliumLoadBalancerIPPool`) is added to the cluster. See "`kubectl get ippools`"
    - [BGP Control Plane](https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-v2/#bgp-cluster-configuration)
    - [L2 Announcements / L2 Aware LB](https://docs.cilium.io/en/stable/network/l2-announcements/#l2-announcements) (Beta)

Validate `KubeProxyReplacement`

```bash
kubectl -n kube-system exec ds/cilium -- cilium-dbg status \
    |grep KubeProxyReplacement
```
- `--verbose`

## TL;DR 

The driver for Cilium is eBPF AKA DirectPath mode, yet properly configuring that is a labyrinth of methods, protocols and parameters.

## Download 

```bash
ok(){
    # CLI : https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
    dir="cilium/cilium-cli"
    ./$dir/cilium version 2>&1 || {
        mkdir -p $dir
        pushd $dir 
        url=https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt
        ver=$(curl -s $url) # v0.16.20
        echo $ver |grep 'v' || return 1
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
    dir="cilium"
    pushd $dir 
    repo='cilium'
    chart='cilium'
    helm repo update $repo
    helm pull $repo/$chart --version $ver &&
        tar -xaf ${chart}-$ver.tgz &&
            cp -p $chart/values.yaml . &&
                type -t hdi >/dev/null 2>&1 &&
                    hdi $chart                
    rm -rf $chart
    popd
}
ok

```

## [Install](https://chatgpt.com/c/6749a5f4-ad00-8009-9166-ad815bc10bfc "ChatGPT")

Both install methods are of Helm chart

### Routing : VXLAN or Geneve  

Cilium defaults to not enabling eBPF Directpath mode. It's default routing mode is by __encapsulation__ (VXLAN or Geneve)

### Routing : eBPF (Native)

The native packet forwarding mode leverages the routing capabilities of the network Cilium runs on instead of performing encapsulation.

Configuration

- `routing-mode: native`

- `ipv4-native-routing-cidr: x.x.x.x/y`

If a BGP daemon is running and there is multiple native subnets to the cluster network, optionally give each node L2 connectivity in each zone without traffic always needing to be routed by the BGP routers:

- `direct-routing-skip-unreachable: true` 
- `auto-direct-node-routes` 

### [CLI method](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)

```bash 
☩ cilium install [flags]

☩ cilium install ... --dry-run-helm-values
```
- Generates YAML, but __not__ that of 
  the project's Helm chart `values.yaml`

```bash
cilium install  
```
- `--version 1.16.5`
- `--values cilium.values.yaml` 
    - Note [`cilium.values.yaml](cilium.values.yaml) 
      is __not__ `values.yaml` of Helm.
- `--context lime` 
    - Must be one of `kubeconfig`.
- `--kubeconfig ~/.kube/config`
- `--set bgpControlPlane.enabled=true`
- `--set ipam.mode=kubernetes` 
    - To abide `podCIDR` of `kubeadm init`
    - `--set k8s.requireIPv4PodCIDR=true`
    - `--set k8s.requireIPv6PodCIDR=true`
- `--set nodeIPAM.enabled=true`
- `--set kubeProxyReplacement=true`
    - `--set k8sServiceHost=${K8S_CONTROL_PLANE_IP}`
    - `--set k8sServicePort=${K8S_CONTROL_PLANE_PORT}`
    - [Replace `kube-proxy`](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#kubeproxy-free)
- Add Hubble
    - `--set hubble.ui.enabled=true`
    - `--set hubble.relay.enabled=true`

After install ...

```bash
☩ helm list
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
cilium  kube-system     4               2025-01-03 15:26:50.168436737 -0500 EST deployed        cilium-1.16.3   1.16.3
```
&nbsp;

Default install does not implement eBPF Datapath

```bash
cilium install --version 1.16.5
cilium status --wait
cilium connectivity test 
kubectl get cm cilium-config -o yaml |yq .data.tunnel-protocol #> vxlan
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status 

```

Add Hubble

```bash
cilium upgrade \
    --set hubble.ui.enabled=true \
    --set hubble.relay.enabled=true

cilium hubble ui
   #> Opening "http://localhost:12000" in your browser...

```

### [Helm method](https://docs.cilium.io/en/stable/installation/k8s-install-helm/ "docs.cilium.io") | [Helm params reference](https://docs.cilium.io/en/stable/helm-reference/#helm-reference)


```bash
app=cilium
ver=1.16.5 
ver=1.15.11 
values=values.yaml
tar -xaf ${app}-$ver.tgz &&
    helm upgrade --install -f $values $app $app/ &&
        rm -rf $app

```
- [`values.yaml`](values.yaml)

```bash
helm install cilium cilium/cilium --version 1.15.11 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set=kubeProxyReplacement=true \
    --set k8sServiceHost=${K8S_CONTROL_PLANE_IP} \
    --set k8sServicePort=${K8S_CONTROL_PLANE_PORT} \
    --set=securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set=securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set=cgroup.autoMount.enabled=false \
    --set=cgroup.hostRoot=/sys/fs/cgroup \
    --set=k8sServiceHost=localhost \
    --set=k8sServicePort=7445 \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true


helm install cilium cilium/cilium --version 1.15.11 \
    --namespace kube-system \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=${API_SERVER_IP} \
    --set k8sServicePort=${API_SERVER_PORT}

```

If we want Cilium to use the HA LB (vIP) 
when communicating with K8s API server:

```bash
vip_or_domain=10.0.10.11 # OR k8s.lime.lan
port=6444 # HALB frontend; upstreams to 6443 (kube-apiserver)
helm install cilium cilium/cilium --namespace kube-system \
    --set k8sServiceHost=$vip_or_domain \
    --set k8sServicePort=$port \
    --set kubeProxyReplacement=partial \
    --set externalIPs.enabled=true
```
- `kubeProxyReplacement` :
    - Enables partial or full replacement of kube-proxy functionality by Cilium.
    - In most cases, partial is sufficient to integrate with external load balancers.
- `externalIPs.enabled` :
    - Allows the use of external IPs for services. 
      This is necessary for external load balancers 
      to direct traffic correctly.
- `hostServices.enabled=true` :
    - Optional. Enables handling of host services by Cilium, 
      which can be helpful in environments with external load balancers.

### [Optimal per ChatGPT](https://chatgpt.com/c/675905de-37fc-8009-ba64-c0f2501df333) : [`values.yaml`](values.yaml)

Datapath : Direct (L3) v. Encapsulated (Overlay/VXLAN)

For the best performance on east-west traffic in a single-subnet cluster, 
the __Direct Datapath__ is usually the industry recommendation.

Query 

```bash
cilium config view |grep tunnel
```
- If `tunnel` is set to `vxlan` or `geneve`, it’s __Encapsulated__.
- If `tunnel` is set to `disabled`, it’s __Direct__.


## `cilium` (host) v. `cilium-dbg` (ctnr)

__`cilium-dbg`__

```bash
☩ kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    cilium-dbg
```
```plaintext
CLI for interacting with the local Cilium Agent

Usage:
  cilium-dbg [command]

Available Commands:
  bgp                    Access to BGP control plane
  bpf                    Direct access to local BPF maps
  build-config           Resolve all of the configuration sources that apply to this node
  cgroups                Cgroup metadata
  completion             Output shell completion code
  config                 Cilium configuration options
  debuginfo              Request available debugging information from agent
  encrypt                Manage transparent encryption
  endpoint               Manage endpoints
  envoy                  Manage Envoy Proxy
  fqdn                   Manage fqdn proxy
  help                   Help about any command
  identity               Manage security identities
  ip                     Manage IP addresses and associated information
  kvstore                Direct access to the kvstore
  loadinfo               Show load information
  lrp                    Manage local redirect policies
  map                    Access userspace cached content of BPF maps
  metrics                Access metric status
  monitor                Display BPF program events
  node                   Manage cluster nodes
  nodeid                 List node IDs and associated information
  policy                 Manage security policies
  post-uninstall-cleanup Remove system state installed by Cilium at runtime
  prefilter              Manage XDP CIDR filters
  preflight              Cilium upgrade helper
  recorder               Introspect or mangle pcap recorder
  service                Manage services & loadbalancers
  statedb                Inspect StateDB
  status                 Display status of daemon
  troubleshoot           Run troubleshooting utilities to check control-plane connectivity
  version                Print version information

Flags:
      --config string   Config file (default is $HOME/.cilium.yaml)
  -D, --debug           Enable debug messages
  -h, --help            help for cilium-dbg
  -H, --host string     URI to server-side API

Use "cilium-dbg [command] --help" for more information about a command.
```

__`cilium`__

```bash
☩ cilium
```
```plaintext
CLI to install, manage, & troubleshooting Cilium clusters running Kubernetes.

Cilium is a CNI for Kubernetes to provide secure network connectivity and
load-balancing with excellent visibility using eBPF

Examples:
# Install Cilium in current Kubernetes context
cilium install

# Check status of Cilium
cilium status

# Enable the Hubble observability layer
cilium hubble enable

# Perform a connectivity test
cilium connectivity test

Usage:
  cilium [flags]
  cilium [command]

Available Commands:
  bgp          Access to BGP control plane
  clustermesh  Multi Cluster Management
  completion   Generate the autocompletion script for the specified shell
  config       Manage Configuration
  connectivity Connectivity troubleshooting
  context      Display the configuration context
  encryption   Cilium encryption
  help         Help about any command
  hubble       Hubble observability
  install      Install Cilium in a Kubernetes cluster using Helm
  multicast    Manage multicast groups
  status       Display status
  sysdump      Collects information required to troubleshoot issues with Cilium and Hubble
  uninstall    Uninstall Cilium using Helm
  upgrade      Upgrade a Cilium installation a Kubernetes cluster using Helm
  version      Display detailed version information

Flags:
      --context string             Kubernetes configuration context
      --helm-release-name string   Helm release name (default "cilium")
  -h, --help                       help for cilium
      --kubeconfig string          Path to the kubeconfig file
  -n, --namespace string           Namespace Cilium is running in (default "kube-system")

Use "cilium [command] --help" for more information about a command.

```

## Add __Hubble__ 

```bash
☩ cilium upgrade \
    --set hubble.ui.enabled=true \
    --set hubble.relay.enabled=true

☩ cilium hubble ui
   Opening "http://localhost:12000" in your browser...

```

```bash
☩ cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

DaemonSet              cilium             Desired: 3, Ready: 3/3, Available: 3/3
DaemonSet              cilium-envoy       Desired: 3, Ready: 3/3, Available: 3/3
Deployment             cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
Deployment             hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium             Running: 3
                       cilium-envoy       Running: 3
                       cilium-operator    Running: 2
                       hubble-relay       Running: 1
                       hubble-ui          Running: 1
Cluster Pods:          5/5 managed by Cilium
Helm chart version:    1.16.3
Image versions         cilium             quay.io/cilium/cilium:v1.16.3@sha256:62d...f28: 3
                       cilium-envoy       quay.io/cilium/cilium-envoy:v1.29.9-17283...: 3
                       cilium-operator    quay.io/cilium/operator-generic:v1.16.3@sha256:...: 2
                       hubble-relay       quay.io/cilium/hubble-relay:v1.16.3@sha256:feb...089: 1
                       hubble-ui          quay.io/cilium/hubble-ui-backend:v0.13.1@sha256:0e0...95b: 1
                       hubble-ui          quay.io/cilium/hubble-ui:v0.13.1@sha256:e2e...6c6: 1
```