# [`k8s-vanilla-ha-rhel9`](https://github.com/sempernow/k8s-vanilla-ha-rhel9 "GitHub : sempernow/k8s-vanilla-ha-rhel9") | [Kubernetes.io](https://kubernetes.io/docs/) | [Releases](https://github.com/kubernetes/kubernetes/releases)

Install an on-prem K8s cluster of 3 control nodes using `kubeadm`.

## Usage

See `make` recipes

```bash
make
```

### Create cluster 

```bash
# Prepare the host
make conf 
make reboot 
make install 
make reboot
# Initialize cluster ( 1st node) 
make init 
vi Makefile.settings # Set K8S_CERTIFICATE_KEY
# Configure client on this admin host
make kubeconfig 
# Install Pod network (CNI addon)
make kuberouter-install 
# Join other control nodes
make join-control

```
- `kubeadm` configuration documents:
    - [`kubeadm-config-init.yaml`](scripts/kubeadm-config-init.yaml)
    - [`kubeadm-config-join.yaml`](scripts/kubeadm-config-join.yaml)
- [`join-control.sh`](scripts/join-control.sh)


```bash
kubectl proxy # K8s API @ http://127.0.0.1:8001 (Blocks) 
```
```bash
curl http://127.0.0.1:8001/healthz #> ok
```

## Delete/Re-join a Control-Plane Node

Modifications to Static Pod manifest(s) do not typically require `drain`/`delete`/`join` of (control-plane) nodes. 
However, some changes require it:

- Pod CIDR Allocations
    - Existing nodes will not adopt changes to Pod CIDR, 
      whether declared by modifying manifests or otherwise.
- Control-Plane Certificates 
    - If expired or improperly rotated, 
      rejoining nodes may be necessary.
- Adding New Control-Plane Nodes.


### Drain/Delete/Join

From remote (admin) host:

```bash
user=u1
node=a1
# Delete
kubectl drain $node --delete-local-data --force --ignore-daemonsets
kubectl delete node $node
ssh $user@$node /bin/bash -c '
    sudo systemctl stop kubelet 
    sudo rm -rf /etc/kubernetes/manifests/*
    sudo rm -rf /var/lib/kubelet/*
    sudo rm -rf /var/lib/etcd/*
    sudo systemctl start kubelet 
'
# Join
ssh $user@$node sudo kubeadm join --config kubeadm-config-join.yaml

```

## Remove taint 

```bash
# taints : get : spec.taints: [{key: <str>, value: <str>, effect: <str>}, ...]
k get node $name -o jsonpath='{.spec.taints}'
# taints : get keys, e.g., "node-role.kubernetes.io/control-plane"
k get node a2 -o jsonpath='{.spec.taints[*].key}'
# taints : remove
# - remove if value (key) exist
kubectl taint nodes $name $key1=$value1:$effect-
# - remove if value (key) not exist
kubectl taint nodes $name $key1:$effect-

```

Remove __`NoSchedule`__ from joined control nodes

```bash
k get node a1 -o yaml |yq .spec.taints
```
```yaml
- effect: NoSchedule
  key: node-role.kubernetes.io/control-plane
```
```bash
k taint node a1 node-role.kubernetes.io/control-plane:NoSchedule-
node/a1 untainted

```

## CNI

The eBPF-based variants of CNI projects are purportedly ready for production. However, they have a large number of methods, protocols and configuration parameters per option making it quite challenging to implement a fully functioning network. That stands even after "properly" configuring and passing all their smoke tests. It is not unusual to have recurring failures, evermore revealing some new fail mode.

## Modify `kubelet` Configuration 

__View__ current configuration files

```bash
# Reveal all of its sources
sudo systemctl cat kubelet

```

__Reveal the sum total effect__ of all those configuration sources

@ Server terminal 

```bash
kubectl proxy
```

@ Client terminal

```bash
no=a1
curl -X GET http://127.0.0.1:8001/api/v1/nodes/$no/proxy/configz |jq .

```

__Modify__

### Method 1. Directly declcare in its `--config` file (`KubeletConfiguration`)

@ `/var/lib/kubelet/config.yaml/`


```yaml
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
...
cgroupDriver: systemd
systemReserved:
  cpu: "500m"
  memory: "1Gi"
kubeReserved:
  cpu: "500m"
  memory: "1Gi"
enforceNodeAllocatable:
  - "pods"
  - "system-reserved"
  - "kube-reserved"
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
systemReservedCgroup: "/sys/fs/cgroup/system.slice/system-reserved.slice"
                       /sys/fs/cgroup/system.slice/system-reserved.slice
kubeReservedCgroup: "/sys/fs/cgroup/system.slice/kube-reserved.slice"
```
- [`KubeletConfiguration`](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration)


```bash
☩ sudo systemctl daemon-reload
☩ sudo systemctl restart kubelet
☩ sudo journalctl --no-pager -eu kubelet
...
Dec 27 09:05:44 a1 kubelet[24102]: E1227 09:05:44.189933   24102 kubelet.go:1542] "Failed to start ContainerManager" err="invalid Node Allocatable configuration. Resource \"memory\" has an allocatable of {{2357198848 0} {<nil>}  BinarySI}, capacity of {{-168800256 0} {<nil>}  BinarySI}"
```

### Method 2. Use systemd drop-in file (preferred)

@ `/etc/systemd/system/kubelet.service.d/10-reserved-resources.conf`

```bash
file=etc.systemd.system.kubelet.service.10-reserved-resources.conf
cat <<EOH |tee scripts/$file
[Service]
Environment="KUBELET_EXTRA_ARGS=--system-reserved=cpu=500m,memory=1Gi --kube-reserved=cpu=500m,memory=1Gi --eviction-hard=memory.available<200Mi,nodefs.available<10% --enforce-node-allocatable=pods,system-reserved,kube-reserved"
EOH

file=10-reserved-resources.conf
ansibash -u scripts/etc.systemd.system.kubelet.service.$file $file

cat <<'EOH' |tee scripts/kubelet.drop-in.sh
#!/usr/bin/env bash
file=10-reserved-resources.conf
dir=/etc/systemd/system/kubelet.service.d
sudo mkdir -p $dir &&
    sudo cp -p $file $dir/$file &&
        sudo chown 0:0 $dir/$file &&
            sudo chmod 644 $dir/$file &&
                sudo ls -hl $dir/$file &&
                    sudo cat $dir/$file
EOH

ansibash -s scripts/kubelet.drop-in.sh
```
```bash
ssh u1@a1 sudo systemctl daemon-reload
ssh u1@a1 psk kubelet
ssh u1@a1 sudo systemctl restart kubelet
```

Failing 

```bash
journalctl --no-pager -eu kubelet 

Dec 26 18:32:38 a1 kubelet[8640]: E1226 18:32:38.265597    8640 run.go:74] "command failed" err="failed to validate kubelet configuration, error: [invalid configuration: systemReservedCgroup (--system-reserved-cgroup) must be specified when \"system-reserved\" contained in enforceNodeAllocatable (--enforce-node-allocatable), invalid configuration: kubeReservedCgroup (--kube-reserved-cgroup) must be specified when \"kube-reserved\" contained in enforceNodeAllocatable (--enforce-node-allocatable)], path: &TypeMeta{Kind:,APIVersion:,}" 
Dec 26 18:32:38 a1 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
Dec 26 18:32:38 a1 systemd[1]: kubelet.service: Failed with result 'exit-code'.
```

The error indicates that you are enforcing `--enforce-node-allocatable` with `system-reserved` and `kube-reserved`, but __the corresponding cgroups are unspecified__ (`--system-reserved-cgroup` and `--kube-reserved-cgroup`). The kubelet requires these cgroups to enforce resource reservations properly.

Those flags specify the Linux cgroups where system and Kubernetes-reserved resources will be applied. If they are not set, the kubelet cannot enforce the reservations.

Find cgroup

```bash
☩ ssh u1@a1 'mount | grep cgroup'
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime,seclabel)
```

Create cgroup resources

```bash

# Manual method
sudo mkdir -p /sys/fs/cgroup/system.slice/system-reserved.slice
sudo mkdir -p /sys/fs/cgroup/system.slice/kube-reserved.slice

```

Add to drop-in

```conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--system-reserved=cpu=500m,memory=1Gi --kube-reserved=cpu=500m,memory=1Gi --enforce-node-allocatable=pods,system-reserved,kube-reserved --system-reserved-cgroup=/sys/fs/cgroup/system-reserved --kube-reserved-cgroup=/sys/fs/cgroup/kube-reserved"


```



## Bandwidth test

### `iperf3` : [`nicolaka/netshoot`](https://github.com/nicolaka/netshoot)

@ Server

```bash
☩ kubectl run nbox --image=nicolaka/netshoot -- iperf3 -s
pod/nbox created

☩ k get pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP           NODE  ...
nbox   1/1     Running   0          80s   10.22.0.14   a1    ...
```

@ Client 

```bash
☩ kubectl run nbox2 -it --rm --image=nicolaka/netshoot -- iperf3 -c 10.22.0.14
```
```plaintext
If you don't see a command prompt, try pressing enter.
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec  4.23 GBytes  36.3 Gbits/sec  583    758 KBytes
[  5]   1.00-2.00   sec  4.65 GBytes  39.9 Gbits/sec    0    954 KBytes
[  5]   2.00-3.00   sec  4.68 GBytes  40.2 Gbits/sec    3    983 KBytes
[  5]   3.00-4.00   sec  4.89 GBytes  42.0 Gbits/sec  304    984 KBytes
[  5]   4.00-5.00   sec  4.80 GBytes  41.2 Gbits/sec  210    987 KBytes
[  5]   5.00-6.00   sec  4.73 GBytes  40.6 Gbits/sec    2    990 KBytes
[  5]   6.00-7.00   sec  4.79 GBytes  41.1 Gbits/sec  332    932 KBytes
[  5]   7.00-8.00   sec  4.79 GBytes  41.1 Gbits/sec  180    935 KBytes
[  5]   8.00-9.00   sec  4.72 GBytes  40.6 Gbits/sec    0    997 KBytes
[  5]   9.00-10.00  sec  4.82 GBytes  41.4 Gbits/sec   45   1.00 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  47.2 GBytes  40.5 Gbits/sec  1659             sender
[  5]   0.00-10.00  sec  47.2 GBytes  40.5 Gbits/sec                  receiver

iperf Done.
Session ended, resume using 'kubectl attach nbox2 -c nbox2 -i -t' command when the pod is running
pod "nbox2" deleted
```

## Observability

- `metrics-server` : [__`deploy.metrics-server.yaml`__](observability/metrics-server/deploy.metrics-server.yaml) 
    ```bash
    k top node
    k top pod
    ```
- [`kubernetes-dashboard`](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) : See [`README`](observability/dashboard/README.html)
    - Web UI @ [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)
        - Auth by token (okay) or KUBECONFIG (fail)


## Security

### [`trivy-operator-install.sh`](security/trivy/trivy-operator-install.sh)

```bash
make trivy
```


## Background 

### [`kubeadm init`](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)

```bash
kubeadm init -v 5 --control-plane-endpoint $LOAD_BALANCER_IP:$LOAD_BALANCER_PORT --upload-certs --ignore-preflight-errors=Mem
```
- `--upload-certs` option uploads the certificates and keys generated during the initialization to the `kubeadm-certs` Secret in the `kube-system` namespace. This allows other control-plane nodes to retrieve these certificates and join the cluster as control-plane members. In a high-availability setup, each control-plane node needs access to these certificates to securely communicate with other control-plane nodes. Absent this option, certificates would have to be manually copied to other control-plane nodes. (Those uploaded certs are deleted after 2 hours.)
- `kubeadm init phase preflight` reveals preflight error(s) by name that must be overridden, each error `NAME` having with its own `--ignore-preflight-errors=NAME`, else error must be fixed out-of-band, else `kubeadm init` fails. 
    - In our case, using Hyper-V machines for cluster nodes, its dynamic-memory allocation interferes with memory-requirements check of "`kubeadm init`", causing initialization failure due to a bogus insufficient-memory finding, reporting error name: "`Mem`".
    ```plaintext
    [preflight] Some fatal errors occurred:
        [ERROR Mem]: the system RAM (844 MB) is less than the minimum 1700 MB
    ```
- All K8s-core pods are Static Pods that run on the host network. Pods created during or after installing the CNI-compliant (Pod network) plugin are assigned IP address(es) within that Pod network CIDR.
    - Each Static Pod is managed directly by the `kubelet` running on its node; 
  they are not of the control plane; not stored in etcd; not by `kube-apiserver`.  
    - Location of Static Pod manifests (YAML):  
      `/etc/kubernetes/manifests/`
- Certs upload is good for 2hrs. After that, the certs are deleted, 
  and must be regenerated at an existing control node:
    ```bash
    sudo kubeadm init phase upload-certs --upload-certs
    ```
    - That requires a new join command:
    ```bash
    sudo kubeadm token create --print-join-command
    ```
- Status of node(s) remains `NotReady` until the "Pod Nework" 
  is configured by installing a CNI-compliant add-on such as Calico. 
  Perform such installs at the init node prior to joining any other node into the cluster. See "Install Pod Network" section.
- `--apiserver-advertise-address $ip_of_this_control_node` : Useful if __this control node__ has more than one interface; bind to stable IP. 
    - __Default__ is `0.0.0.0`, whereof K8s API listens on all interfaces, 
      which is __less secure__ and __less stable__.
- `--control-plane-endpoint` : Useful to set single (shared) endpoint __for all nodes of the control plane__. This is typically the entrypoint to an external (HA) load balancer, making that the K8s-cluster entrypoint in effect for both control and data planes. 
    - Set this to either an IPv4 address or FQDN (`k8s.lime.lan`).

## `kubeconfig` : Configure client(s) on the admin node

By default, clients of K8s API server use the kubeconfig of path declared at environment variable `KUBECONFIG`, else default to `~/.kube/config` :
