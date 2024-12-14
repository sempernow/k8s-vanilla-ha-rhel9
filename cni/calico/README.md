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

### CNI by Operator Method

Though the advised method, `tigera-operator` fails regardless of helm chart or manifest method. 
Operator method has zero configuration, and so every k-v setting for a given set of options, (BGP, VXLAN, ...) 
must be found and properly set, with zero system-level information.

```bash
operator=tigera-operator.yaml
crds=custom-resources-bpf-bgp.yaml
# Install the operator
kubectl create -f $operator 
# Install CRDs
kubectl create -f $crds

```

```bash
☩ k api-resources |grep calico |wc -l
37

☩ k get tigerastatuses
NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver   True        False         False      57m
calico      True        False         False      22m
ippools     True        False         False      58m


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
