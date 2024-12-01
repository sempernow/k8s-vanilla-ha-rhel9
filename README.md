# [`k8s-vanilla-ha-rhel9`](https://github.com/sempernow/k8s-vanilla-ha-rhel9 "GitHub : sempernow/k8s-vanilla-ha-rhel9") | [Kubernetes.io](https://kubernetes.io/docs/) | [Releases](https://github.com/kubernetes/kubernetes/releases)

Install an on-prem vanilla K8s cluster.
Optionally configured behind an HA load balancer  
built of HAProxy and Keepalived.

- The HA topology requires at least two load-balancer nodes, 
  which may also be Kubernetes control nodes.
- Tested on 4 Hyper-V VMs running AlmaLinux 8
    - CPU: 2
    - Memory: 2GB
    - Storage: 20GB
    - Network: Eternal (Host)

## Usage

Menu of recipes:

```bash
make
```

## Prepare the target hosts

```bash
# Configure the host/kernel for K8s
make conf

# Provision hosts with K8s and dependencies
make provision
```

## Cluster Initialization

### Init programmatically

```bash
make init-now
```

#### Details

The cluster is managed as a systemd service by [`kubelet.service`](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/). The `kubelet` is configured dynamically by `kubeadm init` and `kubeadm join` at runtime. The command options of `kubelet` can be modified afterward. See `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf` for more detail.

- On 1st control node:
    - `sudo kubeadm init ...`
- On all other nodes:
    - `sudo kubeadm join ...`
        - With differring command options for 
          workers versus control nodes.


#### [`kubeadm init`](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)

```bash
kubeadm init -v 5 --control-plane-endpoint $LOAD_BALANCER_IP:$LOAD_BALANCER_PORT --upload-certs --ignore-preflight-errors=Mem
```
- Certificate Upload: The `--upload-certs` option uploads the certificates and keys generated during the initialization to the `kubeadm-certs` Secret in the `kube-system` namespace. This allows other control-plane nodes to retrieve these certificates and join the cluster as control-plane members. In a high-availability setup, each control-plane node needs access to these certificates to securely communicate with other control-plane nodes. Absent this option, certificates would have to be manually copied to other control-plane nodes. (Those uploaded certs are deleted after 2 hours.)


In our case, on the 1st control-plane node:

```bash
# Pull images
## Delcare registry and K8s version
ver='1.28.5'
reg=registry.k8s.io
conf=kubeadm-config-images.yaml
cat <<EOH |tee $conf
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $ver
imageRepository: $reg
EOH

export ANSIBASH_TARGET_LIST='a1 a3'

## Pull
ansibash sudo kubeadm config images pull -v5 --config $conf \
    |& tee kubeadm.config.images.pull.log

# Preflight phase only
ansibash sudo kubeadm init phase preflight -v5 \
    --ignore-preflight-errors=Mem \
    |& tee kubeadm.init.phase.preflight.log

# Initialize an HA cluster imperatively : Delete `--dry-run` line when ready.
## All CIDRs are in the Private Address Space (RFC-1918)
ver='1.28.5'
ep='192.168.0.100:8443' # Or by FQDN : k8s.lime.lan
pnet='10.10.0.0/16'
snet='10.55.0.0/16'
tkn=$(kubeadm token generate)
key=$(kubeadm certs certificate-key)

sudo kubeadm init -v5 --kubernetes-version $ver \
    --token $tkn \
    --certificate-key=$key \
    --upload-certs \
    --ignore-preflight-errors=Mem \
    --control-plane-endpoint "$ep" \
    --pod-network-cidr "$pnet" \
    --service-cidr "$snet" \
    |& tee kubeadm.init.$(hostname).log

# Configure the client (kubectl)
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
## Status of kubelet.service (systemd unit)
systemctl status kubelet.service

## Make request to kube-apiserver  
## Expect node "NotReady" due to lack of CNI addon 
kubectl get node
# NAME       STATUS     ROLES           AGE   VERSION
# a0.local   NotReady   control-plane   16h   v1.28.3

```
- Running `sudo kubeadm init phase preflight` reveals preflight error(s) by name that must be overridden, each error `NAME` having with its own `--ignore-preflight-errors=NAME`, else error must be fixed out-of-band, else `kubeadm init` fails. 
    - In our case, using Hyper-V machines for cluster nodes, its dynamic-memory allocation interfered with `kubeadm init` memory-requirements check, causing initialization failure due to a bogus insufficient-memory finding, reporting error name: "`Mem`".
    ```text
    [preflight] Some fatal errors occurred:
        [ERROR Mem]: the system RAM (844 MB) is less than the minimum 1700 MB
    ```
- All K8s-core pods are Static Pods. Each is assigned the IP address of their node, 
  unlike all other Pods that are created during or after the Pod Network (CIDR) 
  is installed by whatever CNI-compliant network plugin is applied. (Ours is Calico).
  Each Static Pod is managed directly by the `kubelet` running on its node; 
  they are not of the control plane; not stored in etcd.  
    - Location of Static Pod manifests (YAML):  
      `/etc/kubernetes/manifests/`
- Certs upload is good for 2hrs. After that, the certs are deleted, 
  and must be regenerated at an existing control node.
    ```bash
    sudo kubeadm init phase upload-certs --upload-certs
    ```
    - Requires a new join command
    ```bash
    sudo kubeadm token create --print-join-command
    ```
- Status of node(s) remains `NotReady` until the "Pod Nework" 
  is configured by installing a CNI-compliant addon such as Calico. 
  Perform such installs at any Master node. See "Install Pod Network" section.
- `--apiserver-advertise-address $ip_of_this_control_node` : Useful if __this control node__ has more than one interface; bind to stable IP. 
    - Default is `0.0.0.0`, whereof K8s API listens on all interfaces, 
      which is less secure and less stable.
- `--control-plane-endpoint` : Useful to set single (shared) endpoint __for all nodes of the control plane__. This is typically the entrypoint to an external (HA) load balancer, making that the K8s-cluster entrypoint in effect for both control and data planes. 
    - Set this to either an IPv4 address or FQDN (`k8s.lime.lan`).


### Join programmatically

>`Makefile` recipe `join-workers` REQUIREs `K8S_CA_CERT_HASH` captured after `init` recipe, and then `conf-gen` and `conf-push` recipes

```bash
export K8S_CA_CERT_HASH="sha256:$(ssh a1 openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"

make conf-gen
make conf-push
make join-workers

```

Configure client on all nodes

```bash
make conf-kubectl
```

#### Details

Get the join command:

```bash
kubeadm token create --print-join-command [--config kubeadm.config.yaml]
```

If after reload (subsequent upload) of certificates

```bash
# Generate a NEW join COMMAND for control node (@ certs reload)
## 1. Re upload certificates in the already working master node:
kubeadm init phase upload-certs --upload-certs # Generate a new certificate key.
## 2. Print join command in the already working master node:
kubeadm token create --print-join-command
## 3. Join a new control plane node:
$join_command_from_step_2 --control-plane --certificate-key $key_from_step_1
```

FYI: Can get `--discovery-token-ca-cert-hash` from CA certificate:

```bash
hash="$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"

ca_cert_hash="sha256:$hash"

```

@ `a1` (2nd Control node)

```bash
ver='1.28.5'
vipp='192.168.0.100:8443'
pnet='10.10.0.0/16'
snet='10.55.0.0/16'

control_plane_endpoint="$vipp"
bootstrap_token='s7d8yn.lwwhp6jykh6lgll2'
ca_cert_hash='sha256:9de24e925b76e823e6ce5a00068a1c1099417f305065f69a690edc1e578022fb'
certificate_key='c6832d904fa22b7ed75808b04058f539882933287aff002e1ffdafa0e1dd99e2'
vm=a1

## Join control plane
sudo kubeadm join "$control_plane_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $ca_cert_hash \
    --control-plane \
    --certificate-key $certificate_key \
    |& tee kubeadm.join.$(hostname).log

sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

```

@ `a3` (Worker)

```bash
# Join worker
sudo kubeadm join "$control_plane_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $ca_cert_hash \
    |& tee kubeadm.join.$(hostname).log
```

Configure client at worker node(s) 
using the `kubeconfig` (`~/.kube/config`) of a control node.

```bash
scp a0:/home/u1/.kube/config config
scp config a3:/home/u1/.kube/config
```

FYI, it's okay to mix configuration file with most other flags

```bash
conf=kubeadm-config.yaml
sudo kubeadm join "$control_plane_endpoint" \
    --config $conf \
    --ignore-preflight-errors=Mem \
    --certificate-key $certificate_key
    |& tee kubeadm.join.$(hostname).log
 
```



#### Join @ Control versus Worker node(s)

Install Pod Network addon after cluster initialization (1st control node), 
before adding more nodes.

Join commands in full often require more command flags;
environment-dependent configuration:

```bash
# @ HA-LB configuration
## If set properly during kubeadm init,
## then this endpoint is shown at its join command.
vip_endpoint='192.168.0.100:8443'
api_server_endpoint="$vip_endpoint"

# Join CONTROL node(s) into existing cluster
sudo kubeadm join "$api_server_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $caCertHash \
    --control-plane \
    --certificate-key $certKey \
    |& tee kubeadm.join.$(hostname).log

# Join WORKER node(s) into existing cluster
sudo kubeadm join "$api_server_endpoint" \
    --ignore-preflight-errors=Mem \
    --token $bootstrap_token \
    --discovery-token-ca-cert-hash $caCertHash \
    |& tee kubeadm.join.$(hostname).log

```

### `kubeadm` / `kubelet` [Configuration Manifests](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration)

#### `kubeadm init --config $yaml` 

[kubeadm Configuration (v1beta3)](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/)

All supported `kind:` :

```bash
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
...
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
...
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
...
```

```bash
conf=kubeadm-config.yaml
kubeadm init -v 5 --config $conf 
```
- [`kubeadm-config.yaml`](kubeadm-config.yaml) ([`.tpl`](kubeadm-config.yaml.tpl))
- Okay to add other commandline flags; mix declarative and imperative.

>*The preferred way to configure `kubeadm` is to pass an YAML configuration file with the `--config` option.* 
>**However, this declarative method is rapidly evolving, and newer versions may be incompatible with older versions.**

Print "defaults". 

```bash
# InitConfiguration, ClusterConfiguration
kubeadm config print init-defaults 
# InitConfiguration, ClusterConfiguration, KubeletConfiguration
kubeadm config print init-defaults --component-configs KubeletConfiguration
# InitConfiguration, ClusterConfiguration, KubeProxyConfiguration
kubeadm config print init-defaults --component-configs KubeProxyConfiguration
```
- These printed parameters are **not set to the actual default values** 
used at runtime. Instead, they are for use as a template from which the configuration(s) may be declared.


### [`kubeadm-config.yaml.tpl`](kubeadm-config.yaml.tpl)

Our template containing all available `kind` of configuration documents.

Generate the YAML ([`kube-config.yaml`](kube-config.yaml)):

```bash

make k8conf
```

Validate the configuration file

```bash
kubeadm config validate --config $conf
```

REFs:
- `kubelet --help` : To list all command options
- `kubeadm init --help` : To list all `init` command options of `kubeadm`
    - [`kind: InitConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-InitConfiguration)
    - [`kind: ClusterConfiguration`] : uploaded to ConfigMap `kubeadm-config` in Namespace `kube-system`. And then read during `kubeadm join`, `kubeadm upgrade`, and `kubeadm reset`.
- `kubeadm join --help` : All The Things (all command options)
    - [`JoinConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/#kubeadm-k8s-io-v1beta4-JoinConfiguration)
- [`kubeadm config print --help`](https://pkg.go.dev/k8s.io/kubernetes@v1.28.4/cmd/kubeadm/app/apis/kubeadm/v1beta3) : Whereever configuration is not declared, defaults are used. Their manifests are printed by:
    - `kubeadm config print init-defaults`
    - `kubeadm config print join-defaults`
    - `kubeadm config print reset-defaults`

#### Related configuration files:

See `kubelet.service` `dropin` file for locations 
of both `kubelet` and `kubeadm` configuration files:

```bash
$ cat /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```

##### Create/Edit `kubelet` config

@ `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`

```bash
sudo mkdir -p /etc/systemd/system/kubelet.service.d/
suco touch /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```
`KUBELET_KUBEADM_ARGS="--flag1=value1 --flag2=value2 ..."`

```conf
[Service]
Environment="KUBELET_KUBEADM_ARGS=--network-plugin=calico"
```
- See [kublet-kubeadm integration](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)
- See [`/var/lib/kubelet/kubeadm-flags.env`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)

After making changes, restart the `kubelet`

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Cluster-init Verify / Troubleshoot  (Pre CNI addon)

The `kubelet` process is a systemd service.
It spawns all the other core K8s processes,
and communicates with `kube-apiserver`.

```bash
# Re-upload the certs, which last only 2hrs (work from an existing control node)
sudo kubeadm init phase upload-certs --upload-certs
# Print the new join command 
sudo kubeadm token create --print-join-command

# Status of core services
systemctl status kubelet 
systemctl status $unit # Units: kubelet containerd docker
systemctl status $unit 
## Logs of core services
journalctl -u $unit
journalctl -xe |grep kube

## Logs
sudo cat /var/log/messages

## Print all K8s and related processes; commands including options
psk

# Images
sudo crictl images
# Pods running
sudo crictl pods # --state Ready --latest --namespace --label
# Containers running
sudo crictl ps
# Containers all
sudo crictl ps -a

# Config files
cat /etc/kubernetes/admin.config    # Server
cat ~/.kube/config                  # Client
# Manifests of Static Pods
ls -hl /etc/kubernetes/manifests
```
- See `psk`function of [`.bash_functions`](https://github.com/sempernow/home/blob/master/.bash_functions "GitHub/sempernow/home").
- Also re-check HA load balancer status
    - See that section above

### Cluster-init Fix

```bash
# Restart primary service(s)
sudo systemctl restart containerd.service 
sudo systemctl restart kubelet.service

# Last resort : Delete the cluster and start again
sudo kubeadm reset # See "Cluster Teardown"
```


### [`kubelet` config](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration) | [Reference](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)

The `kubelet.service` is dynamically configured by `kubeadm init|join` at runtime. 
Afterward, its configuration may be modified through the systemd Drop-in direcotry scheme.

REFs: 

- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/#kubelet-conf-d

## Cluster Teardown 

The effect of the "`kubeadm reset`" command 
is to undo that of "`kubeadm init`".  
It also prints info regarding its effects.

It deletes the cluster by stopping all core K8s processes, 
manifests, and data store, purging `etcd`.
Yet the RPM package installations, Docker images and such are unharmed, 
leaving the node (host OS) ready for the next run of "`kubeadm init`". 

@ Control node : [`teardown.sh`](teardown.sh)

@ Admin machine (Windows/WSL)

```bash
export ANSIBASH_TARGET_LIST='a0 a1 a2 a3'
ansibash -s teardown/teardown.sh

# Prep for init
ansibash 'sudo reboot'
```

After teardown, the `kubelet.service` will fail. (See `systemctl status kubelet.service`). The journal of systemd logs "`Failed ...`" because `/var/lib/kubelet/config.yaml` file does not exist. (See `sudo jounralctl -ru kubelet.service`).

## Kubernetes Networking

- Node (Host) Network CIDR `192.168.0.0/24`
    - External to cluster.
    - `https://192.168.0.100:8443` (HALB VIP)
        - Load Balancer's IP:PORT is the Control Plane Endpoint; 
          a VIP on the Node (Host) Network.
            - The HAProxy/Keepalived HALB implements VRRP 
              to affect a Virtual Gateway Router whose clients are all the control nodes.
                - The VIP should lie outside the subnet's DHCP-server range,
                  else a reserved (static) address therein.
        - `sudo cat /etc/kubernetes/admin.conf |yq .clusters.[].cluster.server`
        - `--advertise-address=192.168.0.93`
            - @ `kubelet`, `kube-apiserver`, `etcd`
        - E.g., @ `a0.local`
            ```text
            ☩ ip -4 addr
            ...
            2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
                inet 192.168.0.93/24 brd 192.168.0.255 scope global ... eth0
                ...
                inet 192.168.0.100/24 scope global secondary eth0
                ...
            ```
    - `192.168.0.93` (`a0.local`)
    - `192.168.0.94` (`a1.local`)
- "Service Subnet" AKA "Service CIDR" AKA "Service ClusterIP Range" AKA "Service-Cluster CIDR". 
    Used for internal communication between services within the cluster. 
    It defines the IP address range assigned to Kubernetes services.
    - `10.96.0.0/12` (`kubeadm init` default); *1,048,576 Services*
        - `--service-cidr=$cidr` 
            - @ `kubeadm init`
        - `--service-cluster-ip-range=$cidr`
            - @ `kubelet`, `kube-apiserver`, `etcd`;
              which is initialized on `kubeadm init`
    - Virtual IPs (VIPs) per Service, 
      providing a stable IP address  for all
- "Pod Subnet" AKA "Pod-Network CIDR" AKA "Pod CIDR" AKA "Cluster CIDR"  AKA "Cluster-Network CIDR".
    Defines the IP address range for individual pods within the cluster.
    Pods communicate directly with each other using these IP addresses.
    - `10.244.0.0/16` (`kubeadm init` default); *65,536 Pods*
    - `172.16.0.0/12` (`kubeadm init` default alt); *1,048,576 Pods*
        - Default CIDR is per environment;
          upon Kubernetes' evaluation of the host network.
    - `10.10.0.0/16` (commonly chosen alt) 
        - `--pod-network-cidr=$cidr`
            - @ `kubeadm init`
    - `192.168.0.0/16` (Calico default)
        - WARNING: This overlaps with a common default Node (Host) CIDR.
        - Calico adopts that of `kubeadm init` if set (`--pod-network-cidr`).
        - At other (non-K8s) deployments
            - @ `calico.yaml`
            ```yaml
            - name: CALICO_IPV4POOL_CIDR
              value: "10.10.0.0/16"
            ```

## IP Address Ranges

Cluster-internal CIDRs for Service and Pod networks (subnets) must not overlap. 
Select from within the **Private Address Space** ([RFC-1918](https://www.ietf.org/rfc/rfc1918.txt)):

    RANGE                                               COMMON CIDR

    10.0.0.0    - 10.255.255.255  (10/8 prefix)         10.0.0.0/16
    172.16.0.0  - 172.31.255.255  (172.16/12 prefix)    172.16.0.0/12
    192.168.0.0 - 192.168.255.255 (192.168/16 prefix)   192.168.0.0/24

Note that Static Pods are always asigned the public IP address of their node (host).
Ulike all other Pods, they are handled directly by their node's `kubelet`, 
not by the Kubernetes API (`kube-apiserver`).

### Routing 

Routing rules distinguish between traffic destined for services (handled by `kube-proxy`) 
and traffic between pods (handled by the CNI plugin).

### TLS Cipher Suites 

Configuration isssues regarding network admins placing restrictions,
limiting cipher suites to their "allowed" list:

- TLS 1.2
    - An unallowed cipher is mandated for use at HTTP/2 spec (`RFC-7540`).
        - `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
        - Unable to disable HTTP/2 using `crypto/tls` pkg, 
          and if able may cause cluster comms problems.
- TLS 1.3 (`RFC-8446`)
    - An unallowed cipher is mandated (with qualifier) for use per spec.
    - Cipher suites for this TLS version are not configurable at either `crypto/tls` pkg 
      or Kubernetes [`KubeletConfiguration.tlsCipherSuites: []`](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration)

REFs:

- [IANA : TLS Parameters](https://www.iana.org/assignments/tls-parameters/tls-parameters.xml)
- HTTP/2 : [RFC-7540](https://www.rfc-editor.org/rfc/rfc7540#section-9.2.2)
- TLS 1.3 : [RFC-8446](https://www.rfc-editor.org/rfc/rfc8446.html#section-9.1)
- [`crypto/tls` (`go1.20.11`)](https://pkg.go.dev/crypto/tls@go1.20.11) 
    - [TLS Cipher Suites @ `crypto/tls`](https://tip.golang.org/blog/tls-cipher-suites)
    - @ TLS 1.3, its cipher suites are [not configurable](https://github.com/golang/go/issues/29349) 
    - [FIPS-verified version](https://stackoverflow.com/questions/68433362/go-dev-boringcrypto-branch-x-crypto-library-fips-140-2-compliance)
        ```text
        The dev.boringcrypto branch of Go replaces the built-in crypto modules with a FIPS-verified version:
        ```
        - [BoringSSL](https://boringssl.googlesource.com/boringssl/)
-  [`kube-apiserver` command options](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
    - @ `/etc/kubernetes/manifests/kube-apiserver.yaml`
    ```yaml
    spec:
    containers:
    - command:
        - kube-apiserver
        ## Default
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        ## Fails to disable HTTP/2.
        #- --feature-gates=AllAlpha=false
        ## TLS settings:
        - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
        - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
        ## Ciphers are not configurable at TLS 1.3 of Golang's crypto/tls package.
        #- --tls-min-version=VersionTLS13 
        #- --tls-cipher-suites=TLS_AES_256_GCM_SHA384
        #...
    ```

## K8s process params : `ps aux` (See `psk`)

## Helm : Install | [Releases](https://github.com/helm/helm/releases)

See [install-helm.sh](rhel/install-helm.sh)

## Install Pod Network 

CNI-compliant NetworkPolicy addon that creates 
and manages the Pod Network AKA Cluster Network.
It accepts the existing Pod Network CIDR if already set, 
else defaults to `192.168.0.0/16`, 
which often conflicts with the subnet CIDR of node(s). 

Popular CNI-compliant Network Addons:

- Cillium is eBPF based, which allows for advanced observability, load balancing, api-aware networking, service-mesh integration, and security.
    - eBPF requires newer distros; is not supported in CentOS/RHEL 7.
- Canal is popular and simple; build of Calico (Policy) and Flannel (overlay).
- Calico is the most popular Network Policy addon

### [Calico : Install by Manifest method](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less)

```bash
ver='3.26.4'
manifest='calico.yaml'
wget -nv https://raw.githubusercontent.com/projectcalico/calico/v${ver}/manifests/$manifest
kubectl apply -f $manifest

```
## Install Kubernetes Ingress Controller

Without a 3rd-party Ingress Controller (Pod(s)), K8s Ingress (object) is useless.

### [Istio Ingress Controller](https://istio.io/latest/docs/setup/install/)

This (`istiod`) is a heavyweight addon requiring at least 4GB per node,
and dozens of Linux-kernel modules (some of which don't exist on AlmaLinux 8). 

- [Kernel Module requirements](https://istio.io/latest/docs/setup/platform-setup/prerequisites/#kernel-module-requirements-on-cluster-nodes)
- [Pod requirements](https://istio.io/latest/docs/ops/deployment/requirements/#pod-requirements)
- [Ports](https://istio.io/latest/docs/ops/deployment/requirements/#ports-used-by-istio)

Install using either Helm or Istioctl (Istio Operator is depricated)

Install Istio:

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

```

### [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/deploy/) | [GitHub](https://github.com/kubernetes/ingress-nginx)

Does NOT include external device (load balancer) necessary for ingress.

[Bare-matal considerations (implementations)](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)



### [Gateway API](https://github.com/kubernetes-sigs/gateway-api#kubernetes-gateway-api) (K8s-sig)

This is a promising architecture and API from the Kubernetes-sigs group, 
but it's not quite ready for production.

Core Gateway API:

- Gateway
- GatewayClass
- HTTPRoute
- TCPRoute
- TLSRoute
- UDPRoute

Install the Gateway-API CRDs:

```bash
ver='1.0.0'
gateway=gateway-standard-install.yaml
wget -nvO $gateway https://github.com/kubernetes-sigs/gateway-api/releases/download/v${ver}/standard-install.yaml
kubectl apply -f $gateway

```

Then install a 3rd-party implementation &hellip;

#### [Implementations](https://gateway-api.sigs.k8s.io/implementations/#gateways) 

Note those having GA status are the more mature.

- Gateway Controllers 
    - [NGINX Gateway Fabric](https://gateway-api.sigs.k8s.io/implementations/#nginx-gateway-fabric)


## REFerence : K8s core Processes, Pods and containers

### Ephemeral Storage 

The `kubelet` tracks: 

- `emptyDir` volumes, except volumes of `tmpfs`
- Directories holding node-level logs
- Writeable container layers

>The `kubelet` tracks ***only the root filesystem*** for ephemeral storage. OS layouts that mount a separate disk to `/var/lib/kubelet` or `/var/lib/containers` *will not report ephemeral storage correctly*.

### Cluster-level Logging 

Aggregate application logs and store externally so they survive the pod.

#### EFK stack:

- Elasticsearch: This is a highly scalable search and analytics engine. It allows you to store, search, and analyze big volumes of data quickly and in near real-time. In the context of Kubernetes, it is used as the central storage for logs.
- Fluentd: Fluentd is an open-source data collector for unified logging. It is used to collect and send logs from different sources (in this case, the Kubernetes nodes and pods) to Elasticsearch. Fluentd is efficient and flexible, with a lightweight footprint and a pluggable architecture.
- Kibana: Kibana is a visualization layer that works on top of Elasticsearch. It provides a user interface for visualizing and querying the log data stored in Elasticsearch. This makes it easier to perform data analysis, monitor applications, and troubleshoot issues.

#### ELK stack 

Logstash instead of Fluentd for log processing and aggregation. Logstash is more resource-intensive but offers more complex processing capabilities.

#### Loki/Grafana

Newer. Simplest.

### GitOps : CNCF Projects

Argo CD and Flux CD (Flux) are both popular open-source tools used for GitOps in Kubernetes environments. They enable **automated, continuous delivery** (CD) and make it easier to manage deployments and operations **using Git as the source of truth**. Flagger, on the other hand, is a progressive delivery tool often used in conjunction with Flux for implementing advanced deployment strategies like canary releases and A/B testing.

#### Argo CD

- Purpose: Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes, like Flux.
- Key Features:
    - Application Definitions, Configurations, and Environments: All these are declaratively managed and versioned in Git.
    - Automated Deployment: Argo CD automatically applies changes made in the Git repository to the designated Kubernetes clusters.
    - Visualizations and UI: Argo CD provides a rich UI and CLI for viewing the state and history of applications, aiding in troubleshooting and management.
    - Rollbacks and Manual Syncs: Supports rollbacks and manual interventions for syncing with Git repositories.

#### Argo Rollouts
    
Similar to Flagger. It offers advanced deployment strategies like canary and blue/green.


#### Flux CD (Flux) and Flagger

- Flux CD (Flux):
    - Purpose: Flux is primarily a continuous delivery solution that synchronizes a Git repository with a Kubernetes cluster. It ensures that the state of the cluster matches the configuration stored in the Git repository.
    - Key Features: Flux supports automated deployments, where changes to the Git repo trigger updates in the Kubernetes cluster. It also has capabilities for handling secret management and multi-tenancy.
    - Integration with Flagger: Flux can be used together with Flagger for progressive delivery. Flagger extends Flux’s functionality by adding advanced deployment strategies.
- Flagger:
    - Purpose: Flagger is designed for **progressive delivery** techniques like canary releases, A/B testing, and blue/green deployments.
    - Key Features: It automates the release process by gradually shifting traffic to the new version while measuring metrics and running conformance tests. If anomalies are detected, Flagger can automatically rollback.
    - Integration with Service Meshes: Flagger is often used with service meshes like Istio, Linkerd, and others, leveraging their features for traffic shifting and monitoring.

### @ `kubeadm init`

>A successful "`kubeadm init ...`" should look like this 
>before the CNI-compatible Pod Network addon is installed.

```bash
☩ ssh a0 kubectl get nodes -o wide
NAME       STATUS     ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                           KERNEL-VERSION                 CONTAINER-RUNTIME
a0.local   NotReady   control-plane   18h   v1.28.3   192.168.0.83   <none>        AlmaLinux 8.8 (Sapphire Caracal)   4.18.0-477.10.1.el8_8.x86_64   containerd://1.6.24

☩ ssh a0 sudo crictl image
IMAGE                                     TAG                 IMAGE ID            SIZE
registry.k8s.io/coredns/coredns           v1.10.1             ead0a4a53df89       16.2MB
registry.k8s.io/etcd                      3.5.9-0             73deb9a3f7025       103MB
registry.k8s.io/kube-apiserver            v1.28.3             5374347291230       34.7MB
registry.k8s.io/kube-controller-manager   v1.28.3             10baa1ca17068       33.4MB
registry.k8s.io/kube-proxy                v1.28.3             bfc896cf80fba       24.6MB
registry.k8s.io/kube-scheduler            v1.28.3             6d1b4fd1b182d       18.8MB
registry.k8s.io/pause                     3.9                 e6f1816883972       322kB

☩ ssh a0 sudo crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD
72d811859581e       6d1b4fd1b182d       About an hour ago   Running             kube-scheduler            9                   65d7192909e91       kube-scheduler-a0.local
4d606ea6c582a       10baa1ca17068       About an hour ago   Running             kube-controller-manager   9                   8977ebc01a183       kube-controller-manager-a0.local
f9f0d1cbabeaa       bfc896cf80fba       18 hours ago        Running             kube-proxy                0                   1613b17736276       kube-proxy-d8hq7
e7ef81dd76787       73deb9a3f7025       18 hours ago        Running             etcd                      8                   dd11363d1cec2       etcd-a0.local
36b84ea53223c       5374347291230       18 hours ago        Running             kube-apiserver            8                   c7133111b7f82       kube-apiserver-a0.local

☩ ssh a0 systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Sat 2023-11-11 01:19:08 EST; 18h ago
     Docs: https://kubernetes.io/docs/
 Main PID: 7321 (kubelet)
    Tasks: 13 (limit: 10714)
   Memory: 132.9M
   CGroup: /system.slice/kubelet.service
           └─7321 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.9

Nov 11 19:19:23 a0.local kubelet[7321]: E1111 19:19:23.250596    7321 kubelet.go:2855] "Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
Nov 11 19:19:28 a0.local kubelet[7321]: E1111 19:19:28.251590    7321 kubelet.go:2855] "Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
# ... repeated every 5 seconds

☩ ssh a0 systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2023-11-11 00:58:10 EST; 18h ago
     Docs: https://docs.docker.com
 Main PID: 1041 (dockerd)
    Tasks: 9
   Memory: 44.0M
   CGroup: /system.slice/docker.service
           └─1041 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.

☩ ssh a0 systemctl status containerd
● containerd.service - containerd container runtime
   Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2023-11-11 01:11:09 EST; 18h ago
     Docs: https://containerd.io
 Main PID: 6276 (containerd)
    Tasks: 76
   Memory: 126.4M
   CGroup: /system.slice/containerd.service
           ├─6276 /usr/bin/containerd
           ├─6882 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id c7133111b7f82dfc25e3053cb2bf620f72b837cd900419831ef7467937746e4e -address /run/containerd/containerd.sock
           ├─6909 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id 8977ebc01a1835aad8052d3f74efd84669b8a0f1f0671f7338ec987e73643f45 -address /run/containerd/containerd.sock
           ├─6946 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id dd11363d1cec2d0a5a2eba59795489445dfbdcb9d968198b2b5f4c2e7e9b3b30 -address /run/containerd/containerd.sock
           ├─6970 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id 65d7192909e91d84e76c6030a982ab54f0b7a54581d71b58987baf469bafaeea -address /run/containerd/containerd.sock
           └─7353 /usr/bin/containerd-shim-runc-v2 -namespace k8s.io -id 1613b17736276644a6b8735eeb16e886d8ccd48bf5886f73d4305682fc4b7191 -address /run/containerd/containerd.sock

Nov 11 17:47:52 a0.local containerd[6276]: time="2023-11-11T17:47:52.920080462-05:00" level=info msg="RemoveContainer for \"f204c6ad7a53e6a5c5a8027b269f056b71cd068ab8a46d8a3059e381fb85a1c9\""
Nov 11 17:47:52 a0.local containerd[6276]: time="2023-11-11T17:47:52.925746998-05:00" level=info msg="RemoveContainer for \"f204c6ad7a53e6a5c5a8027b269f056b71cd068ab8a46d8a3059e381fb85a1c9\" returns successfully"
Nov 11 17:48:11 a0.local containerd[6276]: time="2023-11-11T17:48:11.912410311-05:00" level=info msg="CreateContainer within sandbox \"8977ebc01a1835aad8052d3f74efd84669b8a0f1f0671f7338ec987e73643f45\" for container &ContainerMetadata{Name:kube-controller-manager,Attempt:9,}"
Nov 11 17:48:11 a0.local containerd[6276]: time="2023-11-11T17:48:11.939738749-05:00" level=info msg="CreateContainer within sandbox \"8977ebc01a1835aad8052d3f74efd84669b8a0f1f0671f7338ec987e73643f45\" for &ContainerMetadata{Name:kube-controller-manager,Attempt:9,} returns container id \"4d606ea6c582a29fba80579f108e45430a27848d54d72065b47e2efbd3778503\""
Nov 11 17:48:11 a0.local containerd[6276]: time="2023-11-11T17:48:11.940123665-05:00" level=info msg="StartContainer for \"4d606ea6c582a29fba80579f108e45430a27848d54d72065b47e2efbd3778503\""
Nov 11 17:48:12 a0.local containerd[6276]: time="2023-11-11T17:48:12.010394991-05:00" level=info msg="StartContainer for \"4d606ea6c582a29fba80579f108e45430a27848d54d72065b47e2efbd3778503\" returns successfully"
Nov 11 17:48:13 a0.local containerd[6276]: time="2023-11-11T17:48:13.912098969-05:00" level=info msg="CreateContainer within sandbox \"65d7192909e91d84e76c6030a982ab54f0b7a54581d71b58987baf469bafaeea\" for container &ContainerMetadata{Name:kube-scheduler,Attempt:9,}"
Nov 11 17:48:13 a0.local containerd[6276]: time="2023-11-11T17:48:13.985540326-05:00" level=info msg="CreateContainer within sandbox \"65d7192909e91d84e76c6030a982ab54f0b7a54581d71b58987baf469bafaeea\" for &ContainerMetadata{Name:kube-scheduler,Attempt:9,} returns container id \"72d811859581e150353cf3a98d3f6657e5f07988e95096f57f93a2e4b1451e02\""
Nov 11 17:48:13 a0.local containerd[6276]: time="2023-11-11T17:48:13.986381461-05:00" level=info msg="StartContainer for \"72d811859581e150353cf3a98d3f6657e5f07988e95096f57f93a2e4b1451e02\""
Nov 11 17:48:14 a0.local containerd[6276]: time="2023-11-11T17:48:14.078895713-05:00" level=info msg="StartContainer for \"72d811859581e150353cf3a98d3f6657e5f07988e95096f57f93a2e4b1451e02\" returns successfully"

☩ ssh a0 /bin/bash -s < rhel/psk.sh
@ containerd
--containerd=/run/containerd/containerd.sock
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
--kubeconfig=/etc/kubernetes/kubelet.conf
--config=/var/lib/kubelet/config.yaml
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
--pod-infra-container-image=registry.k8s.io/pause:3.9
--
@ docker
--containerd=/run/containerd/containerd.sock
--
@ etcd
--advertise-address=192.168.0.83
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction
--enable-bootstrap-token-auth=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
--proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
--requestheader-allowed-names=front-proxy-client
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--secure-port=6443
--service-account-issuer=https://kubernetes.default.svc.cluster.local
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--advertise-client-urls=https://192.168.0.83:2379
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--client-cert-auth=true
--data-dir=/var/lib/etcd
--experimental-initial-corrupt-check=true
--experimental-watch-progress-notify-interval=5s
--initial-advertise-peer-urls=https://192.168.0.83:2380
--initial-cluster=a0.local=https://192.168.0.83:2380
--key-file=/etc/kubernetes/pki/etcd/server.key
--listen-client-urls=https://127.0.0.1:2379,https://192.168.0.83:2379
--listen-metrics-urls=http://127.0.0.1:2381
--listen-peer-urls=https://192.168.0.83:2380
--name=a0.local
--peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
--peer-client-cert-auth=true
--peer-key-file=/etc/kubernetes/pki/etcd/peer.key
--peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
--snapshot-count=10000
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
--
@ kubelet
--advertise-address=192.168.0.83
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction
--enable-bootstrap-token-auth=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
--proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
--requestheader-allowed-names=front-proxy-client
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--secure-port=6443
--service-account-issuer=https://kubernetes.default.svc.cluster.local
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
--kubeconfig=/etc/kubernetes/kubelet.conf
--config=/var/lib/kubelet/config.yaml
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
--pod-infra-container-image=registry.k8s.io/pause:3.9
--
@ kube-apiserver
--advertise-address=192.168.0.83
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction
--enable-bootstrap-token-auth=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
--proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
--requestheader-allowed-names=front-proxy-client
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--secure-port=6443
--service-account-issuer=https://kubernetes.default.svc.cluster.local
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
@ kube-controller-manager
--authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
--authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
--bind-address=127.0.0.1
--client-ca-file=/etc/kubernetes/pki/ca.crt
--cluster-name=kubernetes
--cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
--cluster-signing-key-file=/etc/kubernetes/pki/ca.key
--controllers=*,bootstrapsigner,tokencleaner
--kubeconfig=/etc/kubernetes/controller-manager.conf
--leader-elect=true
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--root-ca-file=/etc/kubernetes/pki/ca.crt
--service-account-private-key-file=/etc/kubernetes/pki/sa.key
--use-service-account-credentials=true
--
@ kube-scheduler
--authentication-kubeconfig=/etc/kubernetes/scheduler.conf
--authorization-kubeconfig=/etc/kubernetes/scheduler.conf
--bind-address=127.0.0.1
--kubeconfig=/etc/kubernetes/scheduler.conf
--leader-elect=true
--
@ kube-proxy
--config=/var/lib/kube-proxy/config.conf
--hostname-override=a0.local
--

```

@ `/etc/kubernetes/admin.json` || `~/.kube/config`

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0...S0K
    server: https://192.168.0.100:8443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0...tCg==
    client-key-data: LS0...LQo=
```
