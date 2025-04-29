# [Grafana : Loki](https://github.com/grafana/loki/tree/main/production/helm/loki)

## TL;DR

Loki default install is broken by design. 
It presumes a completely configured cloud-storage backend.


## Helm `grafana/loki`

- https://github.com/grafana/helm-charts : Helm chart
- https://github.com/grafana/loki
- https://grafana.com/oss/loki/
- https://artifacthub.io/packages/helm/grafana/loki


```bash
repo=grafana
chart=loki
v=6.29.0 # App Version: 3.4.2
values=values.on-prem-nfs-minimal.yaml
helm repo add $repo https://grafana.github.io/helm-charts
helm upgrade --install $chart $repo/$chart --version $v --values $values

```
- [`values.on-prem-nfs-minimal.yaml`](values.on-prem-nfs-minimal.yaml)
    - From ChatGPT. Isn't valid (see below)
__ERR__

```bash
☩ helm template $repo/$chart --values $values

Error: execution error at (loki/templates/validate.yaml:19:4): Cannot run scalable targets (backend, read, write) or distributed targets without an object storage backend.
```