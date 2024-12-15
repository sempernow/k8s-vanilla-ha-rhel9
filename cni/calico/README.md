# [Calico : On-prem K8s](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises)

## Download

```bash
ok(){
    DIR=calico
    VER='v3.29.1'
    BASE=https://raw.githubusercontent.com/projectcalico/calico/$VER/manifests

    # Manifest Method
    ok(){
        dir="$DIR/manifest-method"
        file=calico.yaml
        [[ -f $dir/$file ]] && return 0
        mkdir -p $dir
        pushd $dir
        curl -sSLO $BASE/$file || return 100
        popd
    }
    ok || return $?

    # Operator Method
    ok(){
        dir="$DIR/operator-method"
        mkdir -p $dir

        # Operator
        file=tigera-operator.yaml
        [[ -f $dir/$file ]] || {
            pushd $dir
            curl -sSLO $BASE/$file || return 200
            popd
        }

        # CRDs
        file=custom-resources.yaml
        [[ -f $dir/$file ]] || {
            pushd $dir
            curl -sSLO $BASE/$file || return 300
            popd
        }
    }
    ok || return $?

    # CLI
    ok(){
        # calicoctl
        # https://docs.tigera.io/calico/latest/operations/calicoctl/install
        dir="$DIR/cli"
        url=https://github.com/projectcalico/calico/releases/download/$VER/calicoctl-linux-amd64 
        file=calicoctl
        [[ -f $dir/$file ]] && return 0
        mkdir -p $dir
        pushd $dir
        curl -sSL -o $file $url 
        popd
        chmod 0755 $dir/$file && $dir/$file version |grep $VER || return 404
    }
    ok || return $?
}
ok || echo "ERR: $?"

```

## Install 

### CLI

```bash
bin=/usr/local/bin/calicoctl
sudo mv calico $bin &&
    sudo chown root:root $bin &&
        sudo chmod 0755 $bin ||
            echo "ERROR : $?"

```


```bash
☩ calicoctl get ippools -o wide
NAME                  CIDR            NAT    IPIPMODE   VXLANMODE   DISABLED   DISABLEBGPEXPORT   SELECTOR
default-ipv4-ippool   10.244.0.0/24   true   Never      Never       false      false              all()

☩ calicoctl ipam show --show-blocks
+----------+-----------------+-----------+------------+-----------+
| GROUPING |      CIDR       | IPS TOTAL | IPS IN USE | IPS FREE  |
+----------+-----------------+-----------+------------+-----------+
| IP Pool  | 10.244.0.0/24   |       256 | 11 (4%)    | 245 (96%) |
| Block    | 10.244.0.128/26 |        64 | 8 (12%)    | 56 (88%)  |
| Block    | 10.244.0.192/26 |        64 | 1 (2%)     | 63 (98%)  |
| Block    | 10.244.0.64/26  |        64 | 2 (3%)     | 62 (97%)  |
+----------+-----------------+-----------+------------+-----------+

☩ calicoctl ipam show --show-configuration
+--------------------+-------+
|      PROPERTY      | VALUE |
+--------------------+-------+
| StrictAffinity     | false |
| AutoAllocateBlocks | true  |
| MaxBlocksPerHost   |     0 |
+--------------------+-------+

☩ calicoctl ipam show --ip=10.244.0.142
IP 10.244.0.142 is in use
Attributes:
  namespace: kube-system
  node: a1
  pod: coredns-76f75df574-fsxvc
  timestamp: 2024-12-14 21:44:05.795537491 +0000 UTC


```

### CNI by Operator Method

~~Though the advised method, `tigera-operator` fails regardless of helm chart or manifest method. 
Operator method has zero configuration, and so every k-v setting for a given set of options, (BGP, VXLAN, ...) 
must be found and properly set, with zero system-level information.~~

___Success!___

```bash
operator=tigera-operator.yaml
cni=custom-resources-bpf-bgp.yaml
# Install the operator
kubectl create -f $operator 
# Install Calico CNI 
kubectl apply -f $cni

```

```bash
☩ k api-resources |grep calico |wc -l
37

☩ k get tigerastatuses
NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver   True        False         False      57m
calico      True        False         False      22m
ippools     True        False         False      58m

☩ kubectl logs -n calico-system -l k8s-app=calico-node
```
```plaintext
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), mount-bpffs (init), install-cni (init)
...
2024-12-14 21:44:09.100 [INFO][43] felix/syncer.go 580: Applying new state, 6 service
2024-12-14 21:44:09.100 [INFO][43] felix/syncer.go 696: new state written
...
2024-12-14 21:44:49.042 [INFO][48] felix/summary.go 100: Summarising 12 dataplane reconciliation loops over 1m11.6s: avg=7ms longest=30ms (resync-filter-v4,update-bpf-routes,update-filter-v4,update-workload-iface)
2024-12-14 21:45:58.776 [INFO][48] felix/summary.go 100: Summarising 6 dataplane reconciliation loops over 1m9.7s: avg=4ms longest=6ms (resync-raw-v4)
2024-12-14 21:47:21.444 [INFO][48] felix/summary.go 100: Summarising 3 dataplane reconciliation loops over 1m22.7s: avg=3ms longest=6ms (resync-filter-v4)
2024-12-14 21:48:32.271 [INFO][48] felix/summary.go 100: Summarising 3 dataplane reconciliation loops over 1m10.8s: avg=4ms longest=6ms (resync-raw-v4)
2024-12-14 21:50:02.656 [INFO][48] felix/summary.go 100: Summarising 4 dataplane reconciliation loops over 1m30.4s: avg=4ms longest=6ms (resync-filter-v4)
2024-12-14 21:51:07.958 [INFO][48] felix/summary.go 100: Summarising 2 dataplane reconciliation loops over 1m5.3s: avg=4ms longest=5ms (resync-mangle-v4)
```

### by Manifest method

```bash
kubectl apply -f calico.yaml
```

## [Enable __eBPF__ dataplane](https://docs.tigera.io/calico/latest/operations/ebpf/enabling-ebpf)

- [Configure Calico to talk directly to K8s API server](https://docs.tigera.io/calico/latest/operations/ebpf/enabling-ebpf#configure-calico-to-talk-directly-to-the-api-server)

@ Operator method

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubernetes-services-endpoint
  namespace: tigera-operator
data:
  KUBERNETES_SERVICE_HOST: 'K8S_CONTROL_PLANE_IP'
  KUBERNETES_SERVICE_PORT: 'K8S_CONTROL_PLANE_PORT'
```

@ Manifest method

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubernetes-services-endpoint
  namespace: kube-system
data:
  KUBERNETES_SERVICE_HOST: 'K8S_CONTROL_PLANE_IP'
  KUBERNETES_SERVICE_PORT: 'K8S_CONTROL_PLANE_PORT'
```

```bash
sed -i "s,K8S_CONTROL_PLANE_IP,$K8S_CONTROL_PLANE_IP,g" $cm
sed -i "s,K8S_CONTROL_PLANE_PORT,$K8S_CONTROL_PLANE_PORT,g" $cm
kubectl apply -f $cm
kubectl delete pod -n kube-system -l k8s-app=calico-node
kubectl delete pod -n kube-system -l k8s-app=calico-kube-controllers
```


In eBPF mode Calico __replaces `kube-proxy`__, 
so disable it by adding a node selector to `kube-proxy`'s DaemonSet 
that matches no nodes:

```bash
kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'

```

