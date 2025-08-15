###############################################################################
# Diff from chart ingress-nginx-4.12.3.tgz default @ ingress-nginx/values.yaml
###############################################################################
controller:
  # -- Global configuration passed to the ConfigMap consumed by the controller. Values may contain Helm templates.
  # Ref.: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
  config:
    use-proxy-protocol: true
    forwarded-for-header: "X-Forwarded-For"
    proxy-real-ip-cidr: "HALB_DOMAIN_CIDR"
  # -- This configuration defines if Ingress Controller should allow users to set
  # their own *-snippet annotations, otherwise this is forbidden / dropped
  # when users add those annotations.
  # Global snippets in ConfigMap are still respected
  allowSnippetAnnotations: true
  # -- Additional command line arguments to pass to Ingress-Nginx Controller
  # E.g. to specify the default SSL certificate you can use
  extraArgs:
    default-ssl-certificate: "NAMESPACE/DEFAULT_SSL_CERTIFICATE"
  # -- Use a `DaemonSet` or `Deployment`
  kind: DaemonSet
  service:
    # -- External traffic policy of the external controller service. Set to "Local" to preserve source IP on providers supporting it.
    # Ref: https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip
    externalTrafficPolicy: "Local"
    # -- Type of the external controller service.
    # Ref: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types
    type: NodePort
    nodePorts:
      # -- Node port allocated for the external HTTP listener. If left empty, the service controller allocates one from the configured node port range.
      http: "HALB_PORT_HTTP"
      # -- Node port allocated for the external HTTPS listener. If left empty, the service controller allocates one from the configured node port range.
      https: "HALB_PORT_HTTPS"
  metrics:
    port: 10254
    portName: metrics
    # if this port is changed, change healthz-port: in extraArgs: accordingly
    enabled: true
    service:
      # -- Enable the metrics service or not.
      enabled: true
      servicePort: 10254
      type: ClusterIP
