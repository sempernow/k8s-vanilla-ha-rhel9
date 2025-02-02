---
## The JoinConfiguration is IGNORED on init
## https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-JoinConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery: # TLS Bootstrap process
  ## Use *either* method: file *or* bootstrapToken
  ## The file method is simpler, requiring only K8S_CERTIFICATE_KEY and K8S_JOIN_KUBECONFIG
  file:
    kubeConfigPath: K8S_JOIN_KUBECONFIG
  # bootstrapToken:
  #   ## Generate token and CA certificate : kubeadm token generate
  #   ## CA certificate @ /etc/kubernetes/pki/ca.crt
  #   token: K8S_BOOTSTRAP_TOKEN
  #   apiServerEndpoint: K8S_ENDPOINT
  #   ## CA-Certificate Hash(es):
  #   ## See "kubeadm init" output: 
  #   ## --discovery-token-ca-cert-hash sha256:<hex-encoded-value>
  #   ## Is hash of "Subject Public Key Info" (SPKI) object
  #   ## Is DISABLED (Unsafe) if empty.
  #   ## Create a caCertHash
  #   ## (The SHA-256 hash of the public key extracted from ca.crt)
  #   ## --ca-cert-hashes="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"
  #   caCertHashes: 
  #   - K8S_CA_CERT_HASH
  #   unsafeSkipCAVerification: false
  timeout: 1m
  # tlsBootstrapToken: K8S_BOOTSTRAP_TOKEN 
nodeRegistration: 
  # ignorePreflightErrors:
  # - Mem           # Useful at VM having dynamically-allocated memory.
  # imagePullPolicy: IfNotPresent # Always|Never|IfNotPresent(default)
  criSocket: K8S_CRI_SOCKET 
  name: THIS_NODE_NAME
  # taints: null    # For default taints
  taints: []        # For no taints
  # kubeletExtraArgs: 
  ## See kubelet --help
  ## Some kubeletExtraArgs are exclusive to Standalone mode,
  ## which is enabled by `kubelet --kubeconfig ...`
    # v: K8S_VERBOSITY            
    # pod-cidr: K8S_POD_CIDR 
    # cgroup-driver: K8S_CGROUP_DRIVER
## REQUIRED @ CONTROL node
controlPlane:
  localAPIEndpoint: 
    advertiseAddress: THIS_NODE_IP
    bindPort: K8S_CONTROL_PLANE_PORT
  ## certificateKey is ephemeral and revealed only *once* per key gen.
  certificateKey: K8S_CERTIFICATE_KEY
