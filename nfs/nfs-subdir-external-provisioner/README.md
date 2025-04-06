# [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner )

K8s (CSI-compliant) External Provisioner that dynamically provisions NFS (client host) storage (`PersistentVolume`) per claim (`PersistentVolumeClaim`).

    SERVER:MOUNT/${namespace}-${pvcName}-${pvName}

UPDATE : Use [__NFS Subdir CSI Driver__](https://github.com/kubernetes-csi/csi-driver-nfs) | [via Helm](https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/charts/README.md)

## Install

See [`nfs-subdir-provisioner.sh`](nfs-subdir-provisioner.sh)

@ `Ubuntu (master) .../nfs/nfs-subdir-external-provisioner`

```bash
# Install the provisioner and its test
☩ bash nfs-subdir-provisioner.sh

# Verify test-pod status : Success, "Completed", imiplies pv created and written to.
☩ k get pod
NAME                  READY   STATUS      RESTARTS      AGE
...
test-pod              0/1     Completed   0             13m

# Diff running v. declared states
☩ diff helm.get.manifest.nfs-provisioner.yaml helm.template.nfs-provisioner.yaml
161d160
<

# Show SC, PVC and its dynamically-created PV
☩ k get sc,pvc,pv
NAME                                               PROVISIONER                                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storageclass.storage.k8s.io/nfs-client (default)   cluster.local/nfs-provisioner-nfs-subdir-external-provisioner   Delete          Immediate           true                   16m

NAME                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/test-claim   Bound    pvc-c7663062-dc60-4d22-b900-69bdc2cc724f   1Mi        RWX            nfs-client     <unset>                 16m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-c7663062-dc60-4d22-b900-69bdc2cc724f   1Mi        RWX            Delete           Bound    default/test-claim   nfs-client     <unset>                          16m

# Inspect the physical (host) backing store, post test pod/pvc
☩ ssh a0 ls -Rhl /srv/nfs
/srv/nfs:
total 0
drwxrwxrwx. 4 root root 101 Apr  6 11:03 k8s

/srv/nfs/k8s:
total 0
-rw-r--r--. 1 u1   u1              0 Apr  6 08:36 a
-rw-r--r--. 1 u2   ad-linux-users  0 Apr  6 10:34 b
drwxr-xr-x. 2 u2   ad-linux-users 15 Apr  6 10:41 bb
drwxrwxrwx. 2 root root           21 Apr  6 11:03 default-test-claim-pvc-c7663062-dc60-4d22-b900-69bdc2cc724f

/srv/nfs/k8s/bb:
total 0
-rw-r--r--. 1 u2 ad-linux-users 0 Apr  6 10:41 a

/srv/nfs/k8s/default-test-claim-pvc-c7663062-dc60-4d22-b900-69bdc2cc724f:
total 0
-rw-r--r--. 1 root root 0 Apr  6 11:03 SUCCESS
```

Delete the PVC and observe behavior

```bash
☩ k delete -f test-claim.yaml
persistentvolumeclaim "test-claim" deleted

☩ k get sc,pvc,pv
NAME                                               PROVISIONER                                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storageclass.storage.k8s.io/nfs-client (default)   cluster.local/nfs-provisioner-nfs-subdir-external-provisioner   Delete          Immediate           true
```

Verify the phy (host) store is retained yet moved to `archived-*`

```bash
☩ ssh a0 ls -Rhl /srv/nfs
/srv/nfs:
total 0
drwxrwxrwx. 4 root root 110 Apr  6 11:21 k8s

/srv/nfs/k8s:
total 0
-rw-r--r--. 1 u1   u1              0 Apr  6 08:36 a
drwxrwxrwx. 2 root root           21 Apr  6 11:03 archived-default-test-claim-pvc-c7663062-dc60-4d22-b900-69bdc2cc724f
-rw-r--r--. 1 u2   ad-linux-users  0 Apr  6 10:34 b
drwxr-xr-x. 2 u2   ad-linux-users 15 Apr  6 10:41 bb

/srv/nfs/k8s/archived-default-test-claim-pvc-c7663062-dc60-4d22-b900-69bdc2cc724f:
total 0
-rw-r--r--. 1 root root 0 Apr  6 11:03 SUCCESS

/srv/nfs/k8s/bb:
total 0
-rw-r--r--. 1 u2 ad-linux-users 0 Apr  6 10:41 a
```

## Q:

The NFS client provisioner project documents nothing whatsoever about filesystem permissions issues, and yet we know that's the fly in the ointment for all container storage PV/PVC mounts. What's going on here?

## A:

You're absolutely right — the [`nfs-subdir-external-provisioner`](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) project is *very* sparse when it comes to addressing the practical realities of filesystem permissions, UID/GID mapping, and security contexts — which are *critical* in almost every real-world deployment. It's one of the biggest footguns for people trying to get NFS-backed storage to "just work."

### Here's the reality they don't say out loud:

1. **Provisioned directories inherit NFS export defaults.**  
    The provisioner creates subdirectories, but:
    - It doesn’t set permissions (unless you use `setVolumeNameAsSubdir: true` and manually pre-create the folders).
    - NFS servers (especially NetApp, Synology, or older enterprise systems) may impose `root_squash`, UID remapping, or default permissions like `755`, which prevent write access for containers expecting `nobody:nogroup` or `1000:1000` ownership.

2. **Pod security context is crucial.**  
    If the container writes as `uid 1000`, and the directory on the NFS server is owned by `uid 2000`, it's going to fail unless:
    - The pod uses `securityContext.runAsUser` and `runAsGroup` to match NFS ownership.
    - Or the directory permissions are open (`0777`) — insecure, but commonly used as a workaround.

3. **NFS doesn’t handle SELinux or fsGroup well.**  
    - `fsGroup` doesn't help on NFS unless you're using a CSI driver that properly chowns the mount — and `nfs-subdir-external-provisioner` does **not**.
    - SELinux labels can be a non-starter unless the server supports and exports labels (rare).

4. **`root_squash` on the NFS server prevents chown.**  
    If the container runs as root and tries to `chown` its data volume, it'll silently fail unless the export is configured with `no_root_squash`.

---

### What's missing in the docs (and should be added):

- **UID/GID behavior.** Explain what happens when a pod runs as a different user from the directory ownership.
- **Permission workarounds:**
    - `setPermissions: "0777"` in values.yaml.
    - `setVolumeNameAsSubdir: true` + pre-create dirs with proper ownership.
- **SecurityContext guidance:**
    - Example `runAsUser` / `runAsGroup` settings.
    - Warnings about when fsGroup *won’t* work.
- **Export advice:**
    - Recommend `no_root_squash` *only* if trusted.
    - Mention implications of using `async` vs `sync` on exports.
- **Better error messages.** Most people get stuck with `Permission denied` or `Read-only filesystem` and have no idea why.

---

Here's a working example tailored for **RHEL 9 clients and a RHEL 9 NFS server**, with appropriate NFS server settings, export configuration, and Kubernetes pod security settings that make it all play nicely with `nfs-subdir-external-provisioner`.


## ✅ RHEL 9 NFS Server Setup

### 1. Install and configure NFS server:

```bash
dnf install -y nfs-utils
systemctl enable --now nfs-server
```

### 2. Create and export the base path:

```bash
mkdir -p /srv/nfs/k8s
chmod 0777 /srv/nfs/k8s  # Simplest method to avoid permission issues
```

### 3. Add to `/etc/exports`:

```bash
/srv/nfs/k8s  *(rw,sync,no_subtree_check,no_root_squash)
```

> ⚠️ `no_root_squash` is *crucial* here — otherwise, root in the pod will be squashed to `nfsnobody`, making chown or file creation break silently.

### 4. Export it:

```bash
exportfs -rav
```

---

## ✅ Kubernetes: Helm Install for NFS Subdir Provisioner

### Add Helm repo and install with matching settings:

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
```

### Create a `values.yaml`:

```yaml
nfs:
  server: <nfs-server-ip>
  path: /srv/nfs/k8s

storageClass:
  defaultClass: true
  name: nfs-client
  accessModes: ["ReadWriteMany"]
  reclaimPolicy: Delete
  archiveOnDelete: true

securityContext:
  runAsUser: 0
  runAsGroup: 0
  fsGroup: 0
```

> If you're not okay with `runAsUser: 0`, then you’ll need to align directory ownership or permission with the user you want the pod to run as.

```bash
helm install nfs-client nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner --create-namespace \
  -f values.yaml
```

---

## ✅ PVC + Pod Example (writes to NFS volume)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  containers:
    - name: app
      image: busybox
      command: ["sh", "-c", "echo Hello from NFS > /data/hello.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: demo-pvc
  securityContext:
    runAsUser: 0
    runAsGroup: 0
    fsGroup: 0
```

---

## 🔍 Key Notes

- If you change `runAsUser` to something non-root (like `1000`), then you **must** pre-create NFS subfolders with matching UID/GID or give `0777` perms.
- `fsGroup` will **not** work unless NFS allows the container to chown the mounted folder — and that only works with `no_root_squash`.

---


# Tighten security 

Without changing the export parameters, mod the export's FS owner, group and mode (`chown`,`chmod`)

@ `a0:/srv/nfs/k8s` (`0770`)

```bash
sudo find /srv/nfs/k8s -mindepth 1 -type d -exec chmod 0770 {} \+
sudo find /srv/nfs/k8s -mindepth 1 -type f -exec chmod 0660 {} \+
sudo chown -R root:ad-linux-users /srv/nfs/k8s
```
```bash
☩ ssh a0 ls -ahl /srv/nfs/k8s
total 4.0K
drwxrwx---. 7 root ad-linux-users 4.0K Apr  6 12:42 .
drwxr-xr-x. 3 root root             17 Apr  6 08:17 ..
-rw-rw----. 1 root ad-linux-users    0 Apr  6 08:36 a
drwxrwx---. 2 root ad-linux-users   21 Apr  6 12:22 archived-default-test-claim-pvc-1531e25c-e4ca-4e14-8c16-bf714817836d
drwxrwx---. 2 root ad-linux-users   21 Apr  6 11:03 archived-default-test-claim-pvc-c7663062-dc60-4d22-b900-69bdc2cc724f
drwxrwx---. 2 root ad-linux-users   23 Apr  6 12:41 archived-default-test-pv-init-access-pvc-0b62a27c-721f-44c8-9b39-0b73946028a4
drwxrwx---. 2 root ad-linux-users   23 Apr  6 12:26 archived-default-test-pv-init-access-pvc-6db66903-5398-4cb6-baeb-4df6da7e76bf
-rw-rw----. 1 root ad-linux-users    0 Apr  6 10:34 b
drwxrwx---. 2 root ad-linux-users   15 Apr  6 10:41 bb
```

@ admin (Ubuntu)

```yaml
apiVersion: v1
kind: Pod
...
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: secure-nfs-pod
  initContainers:
    - name: init-perms
      image: busybox
      # @ K8s nodes
      # UID : id nfsanon : uid=50000(nfsanon) gid=50000(nfsanon) groups=50000(nfsanon)
      # GID : getent group ad-linux-users : ad-linux-users:*:322202601:admin,u2,u1
      command: ["sh", "-c", "chown 50000:322202601 /mnt/data && chmod 0770 /mnt/data"]
      volumeMounts:
        - name: data
          mountPath: /mnt/data
...
```
- [`secure-nfs-pod.yaml`](secure-nfs-pod.yaml)
    - Set `UID:GID` (`nfsanon:ad-linux-users`) and `MODE` (`770`)

```bash
kubectl apply -f secure-nfs-pod.yaml --wait 
kubectl get pod,pvc,pv
kubectl delete -f secure-nfs-pod.yaml

```

```bash
☩ ssh a0 ls -hl /srv/nfs/k8s
...
drwxrwx---. 2 nfsanon ad-linux-users   23 Apr  6 15:03 archived-default-secure-nfs-pod-pvc-6cc2b960-f314-4b88-936f-f98149d888e5
```
- `archived-${namespace}-${pvcName}-${pvName}`