# Prometheus / Grafana | [K8s Monitoring](https://grafana.com/solutions/kubernetes/kubernetes-monitoring-introduction/ "grafana.com")

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

## Grafana Web UI

- http://localhost:3000/login
    - __user__: __admin__
    - __pass__: __prom-operator__
- http://localhost:3000/dashboards


```bash
☩ curl -IX GET http://localhost:3000/login
Handling connection for 3000
HTTP/1.1 200 OK
...
```