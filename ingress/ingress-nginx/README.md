# [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal-clusters "kubernetes.github.io") | [Releases](https://github.com/kubernetes/ingress-nginx/releases) | Configuration ( [GitHub](https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/index.md) | [kubernetes.github.io](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#configuration-options) )
 

## TL;DR

~~Using manifest method on generated helm template because bug in `--set controller.proxySetHeaders` causes non-string mapping on direct install by `helm upgrade ...`. ~~

Install by Chart method.

See [`ingress-nginx.sh`](ingress-nginx.sh).


## `Ingress` : Rewrite ([`rewrite-target`](https://github.com/kubernetes/ingress-nginx/blob/main/docs/examples/rewrite/README.md "github.com/kubernetes/ingress-nginx")) Syntax

URL rewrite rules are based on RegEx [Capture Group](https://www.regular-expressions.info/refcapture.html "regular-expressions.info")s, which are saved in numbered placeholders; `$1`, `$2` &hellip; `$n`.
So, rewrite rule `\$n` declares the capture group (of the request) that survives the rewrite, and is sent upstream. 

__Here are some example patterns__:

### 1. `/*` --> `/*`

Here there is no actual rewrite. 
Request for `/a1` is sent to upstream app as `/a1`.
The pattern is used only to optimize 
handling by NGINX processor.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
...
  annotations:
    # Apply rewrite to the 1st ($1) Capture Group.
    # That is, preserve only that group.
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
 ...
  rules:
    ...
      paths:
        # This 1st (only) capture group to capture everything after leading slash and rewrite to root. So actually rewrite nothing, yet this pattern informs NGINX to fully injest and process, resulting in optimized handling of edge-cases and query params.
      - path: /(.*) 
        # Inform K8s that path interpretation is performed by Ingress Controller (RegEx)
        pathType: ImplementationSpecific
        ...
```

>Different Ingress controllers support different annotations.

###  2. `/a/*` --> `/*`

```yaml
...
  annotations:
    # Apply rewrite to the 2nd ($2) Capture Group.
    # That is, preserve only that group.
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
..
      - path: /a(/|$)(.*)
        pathType: ImplementationSpecific

```
- `/a` is the literal string.
- `(/|$)` is the 1st capture group, 
  matching either a forward slash `/` 
  or the end of the string `($)`.
- `(.*)` is the 2nd capture group, 
   matching `/a` strictly, 
   or anything that comes after `/a/`.

So __client request__ `/a/1/2?q=v` 
is __rewritten__ to `/1/2?q=v`, 
__before it is sent upstream__. 
Request `/a` matches, yet `/aany` does not.

### 3. `/a/*` --> `/b/*`

```yaml
...
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /b/$1
...
      - path: /a/(.*)
        pathType: ImplementationSpecific

```

So, __client request__ `/a/any` matches and 
is __rewritten__ to `/b/any`, yet `/aany` does not match.

### `app-root: /a` 

```yaml
...
  annotations:
    nginx.ingress.kubernetes.io/app-root: /a
...
      - path: /
        pathType: Prefix
        ...
```
- Request of `http://foo.lime.lan/` responds with HTTP __redirect__:
    - Code: `302 Moved Temporarily`
    - Header: `Location: http://foo.lime.lan/a`

Respond to request of root (`/`) with redirect to app root `/a`. There is no interal rewrite; the application is not sent that original (`/`) request.


## Deploy (DaemonSet) : Baremetal (On-prem) Configuration

See [__`ingress-nginx.sh`__](ingress-nginx.sh)

Install by __Helm__ chart :

| Setting                                                    | Purpose                                                                                       |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `controller.kind=DaemonSet`                                | Ensures each node has a controller pod, needed for `NodePort` + `externalTrafficPolicy=Local` |
| `controller.service.externalTrafficPolicy=Local`           | Preserves source IP for ingress controllers behind a TCP load balancer                        |
| `controller.config.use-proxy-protocol=true`                | Tells NGINX to expect and parse the PROXY protocol header                                     |
| `controller.config.enable-real-ip=true`                    | Enables use of `X-Forwarded-For` / real client IPs                                            |
| `controller.config.forwarded-for-header=X-Forwarded-For`   | Ensures consistent header interpretation                                                      |
| `controller.config.proxy-real-ip-cidr=$proxy_real_ip_cidr` | Crucial to trust only the HAProxy LB (e.g., `192.168.11.0/24`) as a legitimate PROXY sender   |




__Needn't bother with__ @ [__`ingress-nginx-baremetal-v1.12.0.yaml`__](ingress-nginx-baremetal-v1.12.0.yaml). Use the chart method of [__`ingress-nginx.sh`__](ingress-nginx.sh)


The Ingress-NGINX-Controller project uses the term "bare metal" as a synonym for on-prem. Use their "baremetal" configuration for on-prem clusters, 
whether those hosts are "bare-metal" (physical sever) or on a hypervisor. Compare to the default by generating the manifest using "`helm template ...`". (See below.)

```bash
# https://github.com/kubernetes/ingress-nginx/releases
v=1.11.3
url=https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$v/deploy/static/provider/baremetal/deploy.yaml
manifest=ingress-nginx-baremetal.yaml
curl -sSL -o $manifest $url

kubectl apply -f $manifest
```
- This manifest is from project owners;
  an edited version of that generated 
  by a "`helm template ...`" statement.


```bash
# To use remote chart
helm show values $repo/$chart |tee $values
# Or
helm show values $chart --repo $repo |tee $values
vi $values # Edit to fit environment
helm upgrade $release $chart \
    --install \   
    --repo $repo \
    --values $values \
    --namespace $release \
    --create-namespace 

# To use local chart
helm pull $repo/$chart --version $v
# Or
helm pull $chart --repo $repo
tar -xaf ${chart}-${v}.tgz
cp $chart/$values .
vi $values # Edit to fit environment
helm upgrade $release $chart \
    --install \
    --values $values \  
    --namespace $release \
    --create-namespace 

```
- [`helm.template.ingress-nginx.4.12.0.yaml`](helm.template.ingress-nginx.4.12.0.yaml)

The baremetal configuration Service `ingress-nginx-controller` 
wires each service port (`http`, `https`) to a `nodePort` (`port`), 
each an upstream target of the external (HA)LB pool of such.
See [Using a self-provisioned edge](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#using-a-self-provisioned-edge "Ingress NGINX Controller : Deployment : Bare-metal considerations").

```yaml
apiVersion: v1
kind: Service
metadata:
  ...
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: NodePort
  ports:

  - appProtocol: http
    name: http
    port: 30080
    protocol: TCP
    targetPort: http

  - appProtocol: https
    name: https
    port: 30443
    protocol: TCP
    targetPort: https
  ...
```

## [Configuration Options](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#configuration-options)


Modify the `ConfigMap` (`cm.ingress-nginx-controller`) 
of a release __to overwrite any parameter__.

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    ...
data:
  ## Configuration Options : 
  ## - All keys and values of ConfigMap must be type *string*.
  ## - Use `helm install ... --set cm.data.$key=$val` to override default/values settings.
  ## https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
  ##
  ## Enable allow-snippet-annotations grants access to Ingress objects, which may modify nginx.conf
  allow-snippet-annotations: "true"
  annotation-value-word-blocklist: "load_module,lua_package,_by_lua,location,root,proxy_pass,serviceaccount,{,},',\""
  ## client-body-buffer-size : "0" # No limit, else HTTP 413 if over limit.
  client-body-buffer-size: "4096m" # E.g., allow clients to upload OCI-images
  ssl-protocols: "TLSv1.2 TLSv1.3" # Restrict TLS versions
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384." #... the default list
  ## use-proxy-protocol : Must set this key to "true" if the downstream 
  ## (external HA)LB uses PROXY protocol, else must set to "false".
  ## In TCP (TLS-passthrough) mode, HAProxy (LB) configured for "send-proxy" 
  ## adds cleartext PROXY-protocol header(s) to TLS payload. 
  ## NGINX responds HTTP 400 if not so informed of PROXY protocol/mode.
  ## https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#use-proxy-protocol
  use-proxy-protocol: "true" # Default: "false"
  ## enable-real-ip : To preserve client-endpoint IP address under PROXY protocol.
  enable-real-ip: "true"
  forwarded-for-header: "X-Forwarded-For" # Default: "X-Forwarded-For"
  proxy-real-ip-cidr: "192.168.11.0/24"   # Default: "0.0.0.0/0"

```

## E2E Test

- [`ingress-nginx.sh`](ingress-nginx.sh)
    - [`ingress-nginx-usage.yaml`](ingress-nginx-usage.yaml)


```bash
☩ bash ingress-nginx.sh e2e
```

Or

```bash
☩ k apply -f ingress-nginx-usage.yaml

☩ k get node a1 -o wide
NAME   STATUS   ROLES           AGE   VERSION   INTERNAL-IP      EXTERNAL-IP ...
a1     Ready    control-plane   17h   v1.29.6   192.168.11.101   <none>      ...

☩ kubectl -n ingress-nginx get svc ingress-nginx-controller
NAME                       TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)                     
ingress-nginx-controller   NodePort   10.37.30.17   <none>        80:30409/TCP,443:32390/TCP

☩ curl http://192.168.11.101:30409/foo/hostname
foo
```
- HTTP @ `30409`
- HTTPS @ `32390`

We would declare these if connecting to an external (HA) load balancer (LB).
Those service ports of this Ingress controller would be 
the cluster's data-plane upstreams proxied by that HA LB. 

Typically, a single external loadbalancer (HA LB) 
is configured to proxy both the control and data planes, 
providing a single, stable (HA) entrypoint to the (multi-node) cluster.

### &nbsp;

## Metrics of Ingress NGINX

Enable them. See [__`values.diff.yaml`__](values.diff.yaml).

### Options to Expose the Metrics Service

Quick test : Expose by `port-forward`ing the Service

```bash
☩ kubectl port-forward svc/ingress-nginx-controller-metrics -n ingress-nginx 8080:10254 &
[1] 33329
Forwarding from [::1]:8080 -> 10254

☩ curl -fsSIX GET http://localhost:8080/healthz
...
HTTP/1.1 200 OK
...
```

Better to __patch__ the metrics Service,
`ingress-nginx-controller-metrics`,
from `type: ClusterIP` __to `type: NodePort`__

```bash
kubectl patch svc ingress-nginx-controller-metrics -n ingress-nginx -p '{"spec":{"type":"NodePort"}}'

☩ kubectl patch svc ingress-nginx-controller-metrics -n ingress-nginx -p '{"spec":{"type":"NodePort"}}'
service/ingress-nginx-controller-metrics patched

☩ k get svc
NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.103.201.149   <none>        80:30080/TCP,443:30443/TCP   48m
ingress-nginx-controller-admission   ClusterIP   10.103.122.51    <none>        443/TCP                      48m
ingress-nginx-controller-metrics     NodePort    10.97.37.75      <none>        10254:31435/TCP              25m

# Confirm
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
METRICS_PORT=$(kubectl get svc ingress-nginx-controller-metrics -n ingress-nginx -o jsonpath='{.spec.ports[0].nodePort}')
curl http://$NODE_IP:$METRICS_PORT/healthz

# Or simply
☩ curl -fsS http://kube.lime.lan:31435/healthz
ok
```

Better yet to leave as `type: ClusterIP` 
and rather expose it using Ingress:

@ `values.diff.yaml` : Add ...

```yaml
controller:
  metrics:
    service:
      type: ClusterIP  # Keep as ClusterIP
      
  extraArgs:
    metrics-port: "10254"

  # Add ingress for metrics
  extraResources:
    - apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: nginx-metrics
        annotations:
          nginx.ingress.kubernetes.io/rewrite-target: /metrics
      spec:
        ingressClassName: nginx
        rules:
        - host: metrics.yourdomain.com
          http:
            paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: ingress-nginx-controller-metrics
                  port:
                    number: 10254
```
