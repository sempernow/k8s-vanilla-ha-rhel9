# [`k8s-vanilla-ha-rhel9`](https://github.com/sempernow/k8s-vanilla-ha-rhel9 "GitHub : sempernow/k8s-vanilla-ha-rhel9") | [Kubernetes.io](https://kubernetes.io/docs/) | [Releases](https://github.com/kubernetes/kubernetes/releases)

Install an on-prem K8s cluster of 3 control nodes using `kubeadm`.

## Usage

See `make` recipes

```bash
make
```

Create cluster 
```bash
# Prepare the host
make conf 
make reboot 
make install 
make reboot
# Initialize cluster ( 1st node) 
make init 
# Configure client on this admin host
make kubeconfig 
# Install CNI Pod/Service network
make kuberouter-install 
# Here, add PKI params of join command to Makefile.settings
# Join other control nodes
make join-control

```

__Remove taint `NoSchedule`__ from joined control nodes


```bash
k taint nodes a2 node-role.kubernetes.io/control-plane:NoSchedule-
k taint nodes a3 node-role.kubernetes.io/control-plane:NoSchedule-
```
- Ref:
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
