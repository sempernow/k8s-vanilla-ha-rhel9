## kubeadm-config @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/ 
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
## @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration
## RELEASEs https://kubernetes.io/releases/
kubernetesVersion: K8S_VERSION
# imageRepository: K8S_IMAGE_REPOSITORY
# apiServer:
#   timeoutForControlPlane: 4m
# certificatesDir: /etc/kubernetes/pki
clusterName: sbx
# controllerManager: ## https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ControlPlaneComponent
#   extraArgs: {} # map[string]string of flag name(s) sans leading dash(es)
#   extraVolumes: []
# dns: {}
# etcd:
#   local:
#     dataDir: /var/lib/etcd
## HA LB endpoint else that of init node
controlPlaneEndpoint: K8S_ENDPOINT
networking:
#   ## Services subnet CIDR : 10.96.0.0/12 (default)
  serviceSubnet: K8S_SERVICE_CIDR
#   ## Pod subnet CIDR : 172.16.0.0/16 (default)
  podSubnet: K8S_POD_CIDR
#   dnsDomain: cluster.local
# scheduler: {}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration  ## /var/lib/kubelet/config.yaml
## @ https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
## PER NODE
## See kubelet -h
## kubeadm config print init-defaults --component-configs KubeletConfiguration
## kubectl get configmap kubelet-config-1 -n kube-system -o json |jq -Mr .data.kubelet |base64 -d 
## ConfigMaps, kubelet-config-1, exist PER NODE.
## Restart kubelet.service on any change to its --config CONFIG
# enableServer: true 
# cgroupDriver: systemd # systemd || cgroupfs
# imageGCHighThresholdPercent: 85
# imageGCLowThresholdPercent: 80 
## TLS Params : See https://pkg.go.dev/crypto/tls#pkg-constants
# tlsCipherSuites: []
# tlsMinVersion: VersionTLS12 #... VersionTLS12 || VersionTLS13 
# authentication:                                        
#   anonymous:                                           
#     enabled: false                                     
#   webhook:                                             
#     cacheTTL: 0s                                       
#     enabled: true                                      
#   x509:                                                
#     clientCAFile: /etc/kubernetes/pki/ca.crt           
# authorization:                                         
#   mode: Webhook                                        
#   webhook:                                             
#     cacheAuthorizedTTL: 0s                             
#     cacheUnauthorizedTTL: 0s    
## Docker-K8s shim : /var/run/cri-docker.sock
## See https://github.com/mirantis/cri-dockerd 
## + https://www.mirantis.com/blog/the-future-of-dockershim-is-cri-dockerd/
## + https://mirantis.github.io/cri-dockerd/usage/install/
#containerRuntimeEndpoint: /var/run/cri-docker.sock                   
cgroupDriver: K8S_CGROUP_DRIVER 
# containerLogMaxSize: 10Mi 
# containerLogMaxFiles: 5
# localStorageCapacityIsolation: true
# ---
# apiVersion: kubeproxy.config.k8s.io/v1alpha1
# kind: KubeProxyConfiguration
# ## @ https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/#kubeproxy-config-k8s-io-v1alpha1-KubeProxyConfiguration
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
## @ https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration
# Use --upload-certs
## Certificate Key:
## See "kubeadm init" output : ... --certificate-key <KEY>
## --certificate-key=$(kubeadm certs certificate-key)
# certificateKey: K8S_CERTIFICATE_KEY 
# bootstrapTokens:
# ## --token=$(kubeadm token generate)
# - token: K8S_BOOTSTRAP_TOKEN
#   ttl: 24h
#   usages:
#   - authentication
#   - signing
#   groups:
#   - system:bootstrappers:kubeadm:default-node-token
## Local API Endpoint is NOT the cluster (HA-LB) endpoint
# localAPIEndpoint:
#   advertiseAddress: 1.2.3.4  # IP address of this control node
#   bindPort: 6443             # 6443 (default)
nodeRegistration:
  name: K8S_INIT_NODE ## Default to hostname
  # imagePullPolicy: IfNotPresent ## Always|Never|IfNotPresent (default)
  criSocket: K8S_CRI_SOCKET
  # taints: null  ## Default taints on control nodes
  taints: []    ## No taints on control nodes
  # taints:       ## []core/v1.Taint
  # - key: "kubeadmNode"
  #   value: "someValue"
  #   effect: "NoSchedule"
  # ignorePreflightErrors:
  # - Mem
  # kubeletExtraArgs:  
  ## See kubelet --help
  ## Some kubeletExtraArgs are exclusive to Standalone mode,
  ## which is enabled by `kubelet --kubeconfig ...`
  #   v: "5" 
  #   pod-cidr: K8S_POD_CIDR 
  #   cgroup-driver: K8S_CGROUP_DRIVER 
