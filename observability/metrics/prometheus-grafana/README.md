# Prometheus / Grafana | [K8s Monitoring](https://grafana.com/solutions/kubernetes/kubernetes-monitoring-introduction/ "grafana.com")

## TL;DR

Use KPS : Helm chart `kube-prometheus-stack` based on Prometheus Operator.

See:

- `kps.minimal.*`([MD](kps/kps.minimal.md)|[HTML](kps/kps.minimal.html))
- [`stack.sh`](kps/stack.sh)
- [`values.minimal.yaml`](kps/values.minimal.yaml)
- [`kps.images.log`](kps/kps.images.log)

```bash
make prom-install
make prom-access
```

```bash
☩ kw
=== a1 : 2/12
kps-kube-state-metrics-7d6845769d-vrmf4              1/1     Running   0          19m   10.244.141.143   a1     <none>           <none>
kps-prometheus-node-exporter-vj5vh                   1/1     Running   0          19m   192.168.11.101   a1     <none>           <none>
=== a2 : 2/12
kps-prometheus-node-exporter-j56qq                   1/1     Running   0          19m   192.168.11.102   a2     <none>           <none>
prometheus-kps-kube-prometheus-stack-prometheus-0    2/2     Running   0          19m   10.244.78.210    a2     <none>           <none>
=== a3 : 3/11
kps-grafana-679ff68fc-pq62l                          3/3     Running   0          19m   10.244.65.88     a3     <none>           <none>
kps-kube-prometheus-stack-operator-64496876f-fm8fd   1/1     Running   0          19m   10.244.65.98     a3     <none>           <none>
kps-prometheus-node-exporter-9sqvp                   1/1     Running   0          19m   192.168.11.103   a3     <none>           <none>

7/35 @ kube-metrics

☩ k get pod -o yaml |yq .items[].spec.containers[].image |sort -u
docker.io/grafana/grafana:12.0.0
quay.io/kiwigrid/k8s-sidecar:1.30.0
quay.io/prometheus-operator/prometheus-config-reloader:v0.82.2
quay.io/prometheus-operator/prometheus-operator:v0.82.2
quay.io/prometheus/node-exporter:v1.9.1
quay.io/prometheus/prometheus:v3.3.1
registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0
```

## About

*Widely considered reliable* in K8s.

**Pros:**

* **Built for metrics**, not logs: Prometheus shines at numeric __time-series metrics__, which are *far easier to structure, index, and query* than freeform log messages.
* **Tight Kubernetes integration**: Prometheus scrapes `kubelet`, `cAdvisor`, and Kubernetes API endpoints directly. Provides __node/pod/container stats__, __API server latency__, __controller health__, etc.
* **Grafana dashboards**: Massive __ecosystem of community dashboards__ 
tailored for Kubernetes, node health, network usage, etc.
* **Prometheus Operator ([`kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md))**: 
A Helm chart that bundles __Prometheus__, __Alertmanager__, __Grafana__, __node exporters__, and __rules__. 
All are pre-wired for cluster observability.
* **Minimal tuning**: Once installed, it starts collecting useful data almost immediately.

**Cons:**

* **Limited to metrics**: No stack trace or raw logs, which can be frustrating when metrics point to an issue but give no detail.
* **High cardinality**: You have to tune which metrics to collect or you’ll overwhelm it with per-pod/label series.

---


# [`kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#kube-prometheus-stack "GitHub") 


By default this chart installs additional, dependent charts:

- `prometheus-community/kube-state-metrics`
- `prometheus-community/prometheus-node-exporter`
- `grafana/grafana`

@ [__`kps.sh`__](kps/kps.sh)

```bash
v=17.4.0
repo=prometheus-community
chart=kube-prometheus-stack
release=prom
values=values.yaml
helm repo add $repo https://$repo.github.io/helm-charts --force-update
helm show chart $repo/$chart --version $v
# Pull chart and/or only values
helm pull $repo/$chart --version $v
helm show values $repo/$chart --version $v |tee $values
# Customized the planned release
vi $values
# Upgrade/Install the release
helm upgrade $release $repo/$chart --install -f $values

```
```bash
☩ helm status prom
NAME: prom
LAST DEPLOYED: Fri May 16 15:19:21 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace default get pods -l "release=prom"

Get Grafana 'admin' user password by running:

  kubectl --namespace default get secrets prom-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Access Grafana local instance:

  export POD_NAME=$(kubectl --namespace default get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prom" -oname)
  kubectl --namespace default port-forward $POD_NAME 3000

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
```
- Origin: `http://localhost:3000`
- Login: `admin:prom-operator`

```bash
☩ k get svc
NAME                                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
alertmanager-operated                     ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   21h
kubernetes                                ClusterIP   10.96.0.1        <none>        443/TCP                      20d
prom-grafana                              ClusterIP   10.99.84.207     <none>        80/TCP                       21h
prom-kube-prometheus-stack-alertmanager   ClusterIP   10.103.169.71    <none>        9093/TCP,8080/TCP            21h
prom-kube-prometheus-stack-operator       ClusterIP   10.97.133.135    <none>        443/TCP                      21h
prom-kube-prometheus-stack-prometheus     ClusterIP   10.109.64.94     <none>        9090/TCP,8080/TCP            21h
prom-kube-state-metrics                   ClusterIP   10.101.119.20    <none>        8080/TCP                     21h
prom-prometheus-node-exporter             ClusterIP   10.110.246.105   <none>        9100/TCP                     21h
prometheus-operated                       ClusterIP   None             <none>        9090/TCP                     21h
```


## Metrics

Forward the (Kube State) Metrics service

```bash
☩ k get svc
NAME                                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
...
prom-kube-state-metrics                   ClusterIP   10.101.119.20    <none>        8080/TCP                     21h
...
☩ k port-forward svc/prom-kube-state-metrics 8080 &
```

```bash
☩ curl -s http://localhost:8080/metrics |less
...
# HELP kube_configmap_annotations Kubernetes annotations converted to Prometheus labels.
# TYPE kube_configmap_annotations gauge
# HELP kube_configmap_labels [STABLE] Kubernetes labels converted to Prometheus labels.
# TYPE kube_configmap_labels gauge
# HELP kube_configmap_info [STABLE] Information about configmap.
# TYPE kube_configmap_info gauge
kube_configmap_info{namespace="default",configmap="prom-kube-prometheus-stack-k8s-resources-namespace"} 1
kube_configmap_info{namespace="kube-system",configmap="kube-proxy"} 1
kube_configmap_info{namespace="kube-system",configmap="kubelet-config"} 1
kube_configmap_info{namespace="default",configmap="prom-kube-prometheus-stack-scheduler"} 1
```
- These are the same metrics Prometheus scrapes on its own;
  read-only __Prometheus metrics__ about __the current state__ of K8s API objects; 
 `Deployments`, `Pods`, `ConfigMaps`, `Services`, etc.

---

#### 🔍 What is `kube-state-metrics`?

Unlike `node-exporter` (system metrics), 
`kube-state-metrics` focuses on 
**Kubernetes object state**, such as:

| Metric Name                                 | Description                                             |
| ------------------------------------------- | ------------------------------------------------------- |
| `kube_pod_status_phase`                     | Current status of each pod (`Running`, `Pending`, etc.) |
| `kube_deployment_status_replicas_available` | How many replicas are available                         |
| `kube_service_info`                         | Metadata about services                                 |
| `kube_configmap_info`                       | Metadata about ConfigMaps                               |
| `kube_node_status_condition`                | Whether a node is `Ready`, `OutOfDisk`, etc.            |

Each metric has labels to identify the object (`namespace`, `name`, etc.), 
and values that help determine current state.

Metrics service is rarely used directly. Rather, __Prometheus scrapes it__. 

Use the web UIs of **Grafana** or **Prometheus**  to **visualize**, 
**query**, or **alert on** the state of your cluster:

## Grafana (Web UI) Dashboards to Visualize the Metrics

Forward Grafana:

```bash
kubectl port-forward svc/prom-grafana 3000:80 &
```
- Web UI : http://localhost:3000
- Login : __`admin:prom-operator`__
    - See `helm status ...` for info
    - [stack.sh](kps/stack.sh) : `access`


Search __Dashboards__ for “Kubernetes / Compute Resources / Node” or “Pods” to see these metrics visually.
You can build your own dashboard using metrics like:

* `kube_deployment_spec_replicas`
* `kube_pod_container_resource_requests_memory_bytes`

Log in with:

* **User:** `admin`
* **Password:** (check with `kubectl get secret` or Helm values)

From there, use built-in dashboards like:

* **Kubernetes / Config Maps**
* **Kubernetes / Resources / Cluster**
* Or create custom dashboards using `kube_*` metrics

## Prometheus (Web UI) to Query the Metrics Using __PromQL__

Forward Prometheus:

```bash
kubectl port-forward svc/prom-kube-prometheus-stack-prometheus 9090 &
```
- Web UI : http://localhost:9090/query 
- Query using __PromQL__ 
- Go to the **“Graph”** tab
    1. Type `kube_configmap_info` in the query bar
    1. Click “Execute” to graph it
    1. You’ll see all ConfigMaps being monitored


Other **PromQL queries**:

* 🟢 Show __running pods__:

  ```promql
  kube_pod_status_phase{phase="Running"}
  ```

* 🔵 Available __replicas per Deployment__:

  ```promql
  kube_deployment_status_replicas_available
  ```

* 🔴 __Node readiness__:

  ```promql
  kube_node_status_condition{condition="Ready",status="true"}
  ```

Others

* `count(kube_pod_info)` – number of pods
* `kube_node_status_condition{condition="Ready",status="true"}` – node readiness
* `kube_deployment_status_replicas_available{namespace="default"}` – app health

---
