# SELinux affecting K8s `nfs`

# Q: 

NFS isn't even mounted on the nodes because K8s builtin nfs storage class is a server to container mount, 
so do we need 

# A:

With Kubernetes' built-in NFS volume mounting, the NFS share is mounted directly from the storage server (NetApp) to the container's mount namespace, bypassing the host/node mount. This architecture changes the SELinux considerations significantly.

## Key Implications for Direct NFS-to-Container Mounts

1. **No Node-Level NFS Mount**:
   - Traditional NFS client tools (`mount.nfs`, `showmount`) won't show the mount
   - SELinux on worker nodes has limited interaction with the mount

2. **Primary SELinux Interaction Points**:
   - **Container Runtime**: Controls how containers access host resources
   - **Kernel NFS Client**: Handles the mount in container's network namespace
   - **NetApp Server**: Still needs proper export policies (but no SELinux)

## Recommended Configuration

### 1. Container Runtime SELinux Settings (All Worker Nodes)

```bash
# For containerd/docker with SELinux:
sudo setsebool -P container_use_nfs=1
sudo setsebool -P virt_use_nfs=1

# Verify with:
getsebool -a | grep -E '(container|virt)_use_nfs'
```

### 2. Kubernetes Deployment Configuration

```yaml
securityContext:
  seLinuxOptions:
    type: "container_file_t"  # Default container access context
  runAsUser: 200
  runAsGroup: 200
  fsGroup: 200
```

### 3. NetApp Export Policy Verification

Ensure your NetApp export policy has:
- `rw` access for Kubernetes node IPs
- `nosuid` flag
- `root=*` or specific UID mapping
- `sec=sys` (AUTH_SYS authentication)

### 4. Advanced Troubleshooting

1. **Check Kernel-Level NFS Errors**:
   ```bash
   dmesg | grep NFS
   journalctl -k | grep NFS
   ```

2. **Verify Container's View of Mount**:
   ```bash
   kubectl exec -it <pod> -- mount | grep nfs
   kubectl exec -it <pod> -- ls -lZ /nexus-data
   ```

3. **Network Policy Verification**:
   - Ensure NFS ports (2049 TCP/UDP) are open between:
     - Pod network → NetApp
     - Worker node → NetApp (for initial negotiation)

## Critical Checks for Direct NFS-to-Container

1. **NetApp Export Configuration**:
   ```bash
   # On NetApp CLI (example):
   export-policy rule show -vserver <your_vserver> -policyname <policy>
   ```

2. **Worker Node Kernel Modules**:
   ```bash
   lsmod | grep nfs
   lsmod | grep sunrpc
   ```

3. **Pod Network Connectivity**:
   ```bash
   kubectl exec -it <pod> -- nc -zv <netapp-ip> 2049
   ```

## Final Solution Approach

Given this is a direct NetApp→container mount:

1. **First** verify basic connectivity and permissions:
   ```bash
   kubectl exec -it <pod> -- touch /nexus-data/testfile
   ```

2. **If failing**, check in this order:
   - NetApp export policies (rw access for pod network)
   - Kubernetes node's NFS client functionality
   - Container runtime SELinux booleans
   - Pod securityContext settings

Would you like me to provide specific NetApp CLI commands to verify the export policy configuration for your particular setup?

# Q:

What is the context of 

```bash
sudo setsebool -P container_use_nfs=1
sudo setsebool -P virt_use_nfs=1
```

Are those operations on or at a directory?

# A:
The `setsebool` commands you're asking about operate at the **SELinux policy level**, not on any specific directory. They're global boolean switches that change how SELinux behaves system-wide for certain operations. Let me break this down clearly:

## Understanding SELinux Booleans

### 1. What These Commands Do
```bash
sudo setsebool -P container_use_nfs=1
sudo setsebool -P virt_use_nfs=1
```
- **`container_use_nfs`**: Allows containers to use NFS mounts directly
- **`virt_use_nfs`**: Allows virtualized/containerized environments to access NFS
- **`-P`**: Makes the change persistent across reboots
- **`=1`**: Enables the boolean (0 would disable it)

### 2. Key Characteristics
- **Not directory-specific**: These are system-wide policy switches
- **Stored in kernel memory**: They modify the running SELinux policy
- **Persistent changes**: Written to `/etc/selinux/targeted/modules/active/booleans.local`

### 3. How They Affect Your System

| Boolean | Affected Components | Typical Use Case |
|---------|----------------------|------------------|
| `container_use_nfs` | Container runtimes (Docker, containerd) | Direct NFS mounts in containers |
| `virt_use_nfs` | Kubelet, container runtimes | NFS in virtualized environments |

### 4. Verification Commands

To see current values:
```bash
getsebool container_use_nfs virt_use_nfs
```

To see all NFS-related booleans:
```bash
getsebool -a | grep nfs
```

### 5. When You Need These

For your Kubernetes NFS situation, these booleans are needed because:
1. The container runtime needs permission to handle NFS mounts
2. Kubelet needs permission to set up the mount namespace
3. The kernel needs to allow NFS operations in container contexts

### 6. Important Notes
- These changes **don't require restarting** containers or services
- They take effect **immediately** for new operations
- They're **complementary** to directory contexts (`chcon`) and file labels


# Q:

Given that of K8s nfs, do we need any SELinux related declarations in any K8s manifest?

# A:

In a Kubernetes NFS volume setup where mounting happens directly between the NFS server (NetApp) and containers (bypassing node mounts), **you typically don't need SELinux-related declarations in your Kubernetes manifests**. Here's why and when you might still need them:

---

### **Typical Case: No SELinux Manifest Declarations Needed**
1. **Default Behavior is Sufficient**  
   - With `container_use_nfs=1` and `virt_use_nfs=1` set on worker nodes, the default SELinux context (`container_file_t`) usually works.
   - Kubernetes NFS volumes inherit the host's SELinux policy without requiring pod-specific settings.

2. **NetApp NFS Server Considerations**  
   - NetApp typically doesn't enforce SELinux on its exports, so client-side (container) permissions dominate.
   - Ensure NetApp export policies allow the pod's UID/GID (e.g., `root=*` or `anonuid=200`).

---

### **When You *Might* Need SELinux in Manifests**
Add SELinux settings **only** if:
1. **Custom SELinux Policies Exist**  
   If your cluster enforces strict SELinux policies (e.g., OpenShift, RHEL with custom modules), specify:
   ```yaml
   securityContext:
     seLinuxOptions:
       type: "container_file_t"  # Or your custom policy type
   ```

2. **Audit Logs Show Denials**  
   Check worker node logs for AVC denials:
   ```bash
   sudo ausearch -m avc -ts recent | grep nfs
   ```
   If denials reference the pod, add the suggested context from logs.

3. **Using ReadWriteMany (RWX) Volumes**  
   For multi-pod NFS access, ensure consistency:
   ```yaml
   securityContext:
     seLinuxOptions:
       type: "container_file_t"
     runAsUser: 200   # Match NetApp export permissions
     fsGroup: 200
   ```

---

### **Best Practice Approach**
1. **First, Try Without Manifest SELinux Settings**  
   Deploy without `seLinuxOptions` and test:
   ```bash
   kubectl exec -it <pod> -- touch /nexus-data/testfile
   ```

2. **Only Add SELinux Contexts If Needed**  
   If you see permission errors:
   - Check worker node SELinux booleans (`container_use_nfs`, `virt_use_nfs`).
   - Verify NetApp exports allow the pod's UID/GID.
   - Add `seLinuxOptions` only as a last resort.

3. **For OpenShift or Strict Policies**  
   OpenShift automatically injects SELinux contexts. Use:
   ```yaml
   securityContext:
     seLinuxOptions:
       type: "spc_t"  # OpenShift-specific
   ```

---

### **Key Takeaways**
- **Most clusters**: No manifest SELinux settings needed if worker nodes have `container_use_nfs=1`.
- **NetApp-specific**: Focus on export policies (`rw,no_root_squash,anonuid=200`) rather than SELinux.
- **Debug steps**: Check `audit.log` on worker nodes before adding pod SELinux rules.

Would you like help crafting a minimal test deployment to verify your configuration?

---

<!-- 

# Markdown Cheatsheet

[Markdown Cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet "Wiki @ GitHub")

# … ⋮ ︙ • “” ‘’ – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × € ¢ £ ¤ ¥ ₽ ♻ ⚐ ⚑
# ☢ ☣ ☠ ¦ ¶ § † ‡ ß µ ø Ø ƒ Δ ⚒ ☡ ☈ ☧ ☩ ✚ ☨ ☦ ☓ ♰ ♱ ✖ ☘ 웃 𝐀𝐏𝐏 𝐋𝐀𝐁
# ⚠️ ✅ 🚀 🚧 🛠️ ⚡ ❌ 🔒 🧩 📊 📈 🔍 🧪 📦 🔧 🧳 🥇 💡 ✨️ 🔚

# Bookmark

- Reference
[Foo](#foo)

- Target
<a name="foo"></a>


-->
