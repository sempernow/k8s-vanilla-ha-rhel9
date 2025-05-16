# [Grafana : Loki](https://github.com/grafana/loki/tree/main/production/helm/loki)

## TL;DR

Loki default install is broken by design. 
It presumes a completely configured cloud-storage backend.

Yet **Grafana Loki + Fluent Bit** as a lighter alternative to EFK. Loki indexes *labels only* (not full log content), so it’s cheaper and easier to run.


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
- …means that your `values.on-prem-nfs-minimal.yaml` is enabling scalable mode (distributed components: read, write, backend) but does not define an object storage backend like S3, GCS, Azure, or even a local MinIO.

The error you're seeing:

```
Cannot run scalable targets (backend, read, write) or distributed targets without an object storage backend.
```

…means that your `values.on-prem-nfs-minimal.yaml` is enabling **scalable mode** (distributed components: `read`, `write`, `backend`) but **does not define an object storage backend** like S3, GCS, Azure, or even a local MinIO.

---

### 🔧 Solution: Disable Scalable Mode (Enable Monolithic Mode)

If you're running **on-prem with NFS** and want a **minimal, single-binary Loki deployment**, you should **disable** the scalable components entirely.

Your `values.yaml` should set:

```yaml
loki:
  isDefault: true

  # Disable distributed mode
  commonConfig:
    replication_factor: 1

  storage:
    type: filesystem
    filesystem:
      directory: /var/loki/chunks

  schemaConfig:
    configs:
      - from: 2020-10-15
        store: boltdb-shipper
        object_store: filesystem
        schema: v11
        index:
          prefix: index_
          period: 24h

singleBinary:
  enabled: true

write:
  enabled: false
read:
  enabled: false
backend:
  enabled: false

# PVC (optional if using NFS-backed volume)
persistence:
  enabled: true
  storageClassName: "nfs-client"
  accessModes:
    - ReadWriteOnce
  size: 10Gi
```

---

### ✅ Validate

After updating your values file, validate with:

```bash
helm template $chart $repo/$chart --version $v --values $values
```

If it renders cleanly, proceed to install or upgrade:

```bash
helm upgrade --install $chart $repo/$chart --version $v --values $values
```

---

Would you like me to generate a full working `values.on-prem-nfs-minimal.yaml` for you?
