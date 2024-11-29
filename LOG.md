# k8s-air-gap-install

# 2024-10-04

## Unnecessary to configure host firewall for CNI's virtual interfaces

Modify findings of prior log, 2024-08-30, regarding firewall configuration.

See `REF.Network.firewalld.sh` and [CNI Traffic](https://chatgpt.com/share/e0a68be8-70e6-408b-886d-80ba92566101 "ChatGPT")

# 2024-08-30

## [Allow traffic through Virtual Interfaces](https://chatgpt.com/share/7c5d78ff-8305-4051-9209-5bc39d4900cd "ChatGPT.com")

In environments where a host/OS-level firewall is required, 
the advised firewall configruation for K8s nodes 
is to have the external interface for the cluster endpoint bound to a zone 
that is created and configured for K8s requirements. 

However, this does nothing for traffic across any other interface,
including the virtual interface(s) created dynamically 
by K8s network/related (CNI,CRI) providers. 

### Q:

So, __how to configure the host firewall__ 
such that any such virtual interface 
gets bound to `k8s` interface, 
thereby applying that zone's rules 
to these dynamic interfaces?

### A:

Good question, because this CNI/CRI requirement is not explicitly documented anywhere, 
and failing to configure for this may affect both east-west (CNI) and north-south (CRI) traffic, 
and much of that will be intermittent because east-west traffic doesn't cross the host firewall unless it crosses nodes (and so depends on Pods' scheduling/location).

#### Method 1 : Using Rich rules

If CNI and CRI patterns are `cni*` and `veth*`, then 

```bash
firewall-cmd --permanent --zone=k8s \
    --add-rich-rule='rule family="ipv4" source NOT address="'$podCIDR'" accept'
firewall-cmd --permanent --zone=k8s \
    --add-rich-rule='rule family="ipv4" source address="'$podCIDR'" accept'

firewall-cmd --permanent --zone=k8s --add-interface=cni+ 
firewall-cmd --permanent --zone=k8s --add-interface=veth+
```

#### Method 2 : Using firewalld configuration file 

@ `/etc/firewalld/zones/k8s.xml`

```xml
<zone>
  <short>k8s</short>
  <interface name="cni+" />
  <interface name="veth+" />
  ...
</zone>
```

#### Method 3 : Using NetworkManager keyfile (RHEL 8+)

@ `/etc/NetworkManager/system-connections/cni-connection.nmconnection`

```ini
[connection]
id=cni-connection
type=ethernet
interface-name=cni+
permissions=
zone=k8s
autoconnect=true

[ethernet]
mac-address-blacklist=

[ipv4]
method=auto

[ipv6]
method=ignore
```

Formerly (RHEL 8-), used ifcfg format file:

@ `/etc/sysconfig/network-scripts/ifcfg-cni+`

```ini
NAME=cni+
DEVICE=cni+
ZONE=k8s
ONBOOT=yes
```


# 2024-07-08


## `kubeadm init`

`*Configuration` files must be generated sequentially, iteratively, 
with first set prior to certs generation (`kubeadm init phase certs all`), 
and the second set (including `key`, `token`, and `hashes`) afterward.

1. Prior to certs @ `/etc/kubernetes/pki`

Generate NEW cluster PKI @ `/etc/kubernetes/pki/`. No configuration is required here, but for any custom settings. See [`ClusterConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration) .


```bash
# Using a ClusterConfig declaration :
$cfg='kubeadm-config.yaml'
[[ -f /etc/kubernetes/pki/apiserver.key ]] \
	|| sudo kubeadm init phase certs all --config $cfg

# Else, sans ClusterConfig :
[[ -f /etc/kubernetes/pki/apiserver.key ]] \
	|| sudo kubeadm init phase certs all --version $ver

```
- @ `kubeadm-config.yaml` has only [`ClusterConfiguration`](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration): 
  Nothing is required 

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: 1.29.6
#certificatesDir: /etc/kubernetes/pki
#...
```

Now we can get/set all related params required at `InitConfiguration` and `JoinConfiguration`

###  @ `rhel9.4-hyperv/`

@ [`kubeadm-config.yaml.tpl`](rhel9.4-hyperv/kubeadm-config.yaml.tpl)

```yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
...
certificateKey: K8S_CERTIFICATE_KEY 
bootstrapTokens:
- token: K8S_BOOTSTRAP_TOKEN
...
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
...
discovery:
  bootstrapToken:
    token: K8S_BOOTSTRAP_TOKEN
    caCertHashes: 
    - sha256:K8S_CA_CERT_HASH
  tlsBootstrapToken: K8S_BOOTSTRAP_TOKEN 
...
```

Get all

```bash
# K8S_CERTIFICATE_KEY
key=$(sudo kubeadm certs certificate-key)
# K8S_CA_CERT_HASH
hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
        |openssl rsa -pubin -outform der 2>/dev/null \
        |openssl dgst -sha256 -hex \
        |sed 's/^.* //' \
)
# K8S_BOOTSTRAP_TOKEN
tkn=$(sudo kubeadm token generate)
```
Set all for subsequent `kubadm init ...`.

```bash
# Declare all for Makefile recipes
cat <<-EOH |tee -a Makefile.settings
export K8S_CERTIFICATE_KEY ?= $key
export K8S_CA_CERT_HASH    ?= sha256:$hash
export K8S_BOOTSTRAP_TOKEN ?= $tkn
EOH
```

# 2024-04-15

~~TODO:~~ Project synchronization shut down at client insistence.

- Mod Ingress NGINX Controller (INC) to fit HALB
- Test workload (ngx) against that HALB/Ingress setup.

## Debug Ingress NGINX Controller


Work:

The ingress itself is up, 

```bash
$ k apply -f ingress-nginx-1.9.6-k8s-baremetal.deploy-vm128.yaml

NAME                                        READY   STATUS      RESTARTS   AGE   IP           NODE                           NOMINATED NODE   READINESS GATES
ingress-nginx-admission-create-dqdsn        0/1     Completed   0          60s   10.0.0.140   foo129.bar   <none>           <none>
ingress-nginx-admission-patch-dw9tp         0/1     Completed   1          60s   10.0.2.120   foo128.bar   <none>           <none>
ingress-nginx-controller-595dcf97bf-c5649   1/1     Running     0          60s   10.0.0.49    foo129.bar   <none>           <none>

```

but adding Ingress object fails

```bash
$ k apply -f ingress-test-01.yaml

Error from server (InternalError): error when creating "ingress-01.yaml": Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": Unknown Host

```

Ignore the Webhook fail :

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: ingress-nginx-admission
  ...
webhooks:
...
  failurePolicy: Ignore # Fail | Ignore
```
- Successfully created `Ingress` object after reset this to "`Ignore`"

Run as DeamonSet :

https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/


This is not the problem. 

All endpoints ping, but
**Cluster DNS is not working**

```bash
k exec -it abox-xxx-yyy -- nslookup $svc
k exec -it abox-xxx-yyy -- nslookup $svc.svc
k exec -it abox-xxx-yyy -- nslookup $svc.ingress-nginx.svc
k exec -it abox-xxx-yyy -- nslookup $svc.ingress-nginx.svc.cluster.local
```
- Fails for all services of the cluster in any namespace
    - `frewalld` disabled
    - SELinux `Permissive` mode


Pod network problems? Cilium defaults to allow all.

This DNS failure may be a load balancer issue 

## HALB


- `/etc/haproxy/haproxy.cfg`
- `/etc/rsyslog/rsyslog.d/99-haproxy.conf`

```bash
sudo systemctl restart haproxy
sudo systemctl restart rsyslog
```
```bash
sudo cat /var/log/haproxy.log
```


Logging to `rsyslog`

- `/etc/haproxy/haproxy.cfg`
```conf
global
      	log         127.0.0.1:514 local0
```
- `/etc/rsyslog/rsyslog.d/99-haproxy.conf`
```conf
$ModLoad imudp
$UDPServerAddress 127.0.0.1
$UDPServerRun 514

local0.*  /var/log/haproxy.log
```

See log:

```bash
sudo cat /var/log/haproxy.log
```


## [Flux](https://fluxcd.io/) : GitOps 

CNCF Graduated project for CD

### Flux Install

```bash
# Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash
# Bash completions
source <(flux completion bash)
# Bootstrap the Flux controllers
flux bootstrap
```

# 2024-04-11

## `ingress-nginx-controller`

Configure/Install/Test

Manifest method

@ `gitops@vm128` `~/ingress-nginx-controller`

```bash
k apply -f ingress-nginx-1.9.6-k8s.baremetal.deploy-vm128.yaml
```

Helm method

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --version 4.10.0
```

### Configure for our environment

HALB and local CNCF-distribution registry

@ `ingress-nginx-1.9.6-k8s.baremetal.deploy-vm128.yaml`

HALB integration : Declare the two NodePorts (`http`, `https`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  ...
spec:
  type: NodePort
  ports:
  - appProtocol: http
    name: http
    port: 80
    nodePort: 30080
    protocol: TCP
    targetPort: http
  - appProtocol: https
    name: https
    port: 443
    nodePort: 30443
    protocol: TCP
    targetPort: https
  ...

```

Local CNCF-distribution registry integration: 
change images' registry to : 
foo
Images list

```bash
# List
cat ingress-nginx-1.9.6-k8s.baremetal.deploy-vm128.yaml \
    |yq .spec.template.spec.containers[].image \
    |grep -v -- --- \
    |sort -u 
# Pull to local cache
... |xargs -IX sudo crictl pull X

```
```text
foo121.bar:5000/ingress-nginx/controller:v1.9.6
foo121.bar:5000/ingress-nginx/kube-webhook-certgen:v20231226-1a7112e06
```

Get version running

```bash
POD_NAMESPACE=ingress-nginx
POD_NAME=$(kubectl get pods -n $POD_NAMESPACE -l app.kubernetes.io/name=ingress-nginx --field-selector=status.phase=Running -o name)
kubectl exec $POD_NAME -n $POD_NAMESPACE -- /nginx-ingress-controller --version
```

FAILing @ Ingress
``
```bash
$ k apply -f ingress-test-01.yaml

Error from server (InternalError): error when creating "ing.01.yaml": Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": Unknown Host

```
- "The controller uses an admission webhook to validate Ingress definitions. Make sure that you don't have Network policies or additional firewalls preventing connections from the API server to the `ingress-nginx-controller-admission` service."
    - Cilium : [Default Security Policy](https://docs.cilium.io/en/latest/security/network/policyenforcement/) : 
        ```
        If no policy is loaded, the default behavior is to allow all communication unless policy enforcement has been explicitly enabled. As soon as the first policy rule is loaded, policy enforcement is enabled automatically and any communication must then be white listed or the relevant packets will be dropped.

        Similarly, if an endpoint is not subject to an L4 policy, communication from and to all ports is permitted. Associating at least one L4 policy to an endpoint will block all connectivity to ports unless explicitly allowed.
        ```

HAProxy Stats endpoint 

https://jumpcloud.com/blog/how-to-install-configure-haproxy-rhel-9


# 2024-04-10

## Sprint Review to close

Demos on anet (inside) to Joe

## SSH mode 

Working again for no reason.

# 2024-04-02

## K8s cluster 

## LB to Ingress

### HALB : HAProxy

```ini
## Frontend for K8s Ingress by HTTP
frontend k8s-ingress-http
    bind                *:80
    default_backend     k8s-ingress-http
    
## Backend for K8s Ingress by HTTP
backend k8s-ingress-http
    #option      httpchk GET /
    #http-check  expect status 200
    #option      ssl-hello-chk
    balance     leastconn
    server      foo128.bar 10.11.111.250:30080 send-proxy
    server      foo129.bar 10.11.111.251:30080 send-proxy
    server      foo130.bar 10.11.111.249:30080 send-proxy

```
## Deploy NGINX workload : `svc` + `deploy` + `cm` 

@ `gitops@vm128`

- Connectivity thru HAProxy
    - `80` <--> `30080` <--> `80`
- Accepting PROXY protocol
    - Reporting real client IP
- Timeouts if multiple instances across the cluster
    - Service of Ingress NGINX Controller is not overlapping
        - `80:32297` (default)

#### NGINX as workload 

@ `ngx.2.yaml` (See work above)

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ngx
  namespace: default
    ...
      containers:
      - image: foo121.bar:5000/nginx
        imagePullPolicy: Always
        name: nginx
        ...
        volumeMounts:
        - name: conf
          mountPath: /etc/nginx/conf.d
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: conf
        configMap:
          name: ngx-default.conf
      - name: html
        configMap:
          name: ngx-index.html
...
```

@ `default.conf`

```ini
server {
    listen       80 proxy_protocol;
    listen  [::]:80 proxy_protocol;
    server_name  localhost;
...
```
- Accept PROXY protocol (from downstream HAProxy LB)


```bash
$ k apply -f ngx.2.yaml
$ k get cm,svc,ep,pod,deploy -l app=ngx 
```
```text
NAME                         DATA   AGE
configmap/ngx-default.conf   1      48m
configmap/ngx-index.html     1      48m

NAME          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/ngx   NodePort   10.108.169.72   <none>        80:30080/TCP   18h

NAME            ENDPOINTS       AGE
endpoints/ngx   10.0.1.177:80   18h

NAME                      READY   STATUS    RESTARTS   AGE
pod/ngx-555bcff96-dxbw6   1/1     Running   0          9m19s

NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ngx   1/1     1            1           61m
```

See `/sessions@vm128`

```bash 
# Accept proxy_protocol and add /heath endpoint (JSON)
kubectl create cm ngx-default.conf --from-file=default.conf
# Modified landing page
kubectl create cm ngx-index.html --from-file=index.html
# Concat of all objects for this app
kubectl apply -f ngx.yaml
# Test
vip=10.11.111.234
curl --noproxy '*' --max-time 2 http://$vip/health
```
```json
{
    "host":"10.11.111.234",
    "client":"10.0.1.209",
    "server":"localhost",
    "status":"Okay"
}
```
- `client` : `10.0.1.209` ???
    - That's of pod network, but none there


@ `4uzer@foo121 /cifs/xfer-wq/DropBox/4uzer/k8s-air-gap-install`


```bash
$ curl -si --noproxy '*' http://10.11.111.234/health \
    |tee curl-si--noproxy_http.vip.health.log

HTTP/1.1 200 OK
Server: nginx/1.25.4
Date: Tue, 02 Apr 2024 13:51:37 GMT
Content-Type: application/octet-stream
Content-Length: 84
Connection: keep-alive
Content-Type: application/json
X-Real-IP: 10.0.1.209

{"host":"10.11.111.234","client":"10.0.1.209","server":"localhost","status":"Okay"}
```
- Reports bogus/inaccurate client IP (`X-Real-IP`)

NGINX configs 

```ini

http {
  ...
  ##
  # Logging Settings
  ##
  log_format apm '"$time_local" client=$remote_addr '
               'method=$request_method request="$request" '
               'request_length=$request_length '
               'status=$status bytes_sent=$bytes_sent '
               'body_bytes_sent=$body_bytes_sent '
               'referer=$http_referer '
               'user_agent="$http_user_agent" '
               'upstream_addr=$upstream_addr '
               'upstream_status=$upstream_status '
               'request_time=$request_time '
               'upstream_response_time=$upstream_response_time '
               'upstream_connect_time=$upstream_connect_time '
               'upstream_header_time=$upstream_header_time';
  ...
}
```


### Ingress NGINX Controller 


#### TL;DR

- Installed successfully
- Mod ConfigMap to accept PROXY protocol

See `ingress-nginx.yaml`

#### Work

`use-proxy-protocol: "true"`

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
data:
  use-proxy-protocol: "true"
```

Install 

```bash
## Deploy it (modified baremetal deployment)
k apply -f ingress-nginx.yaml
## Capture it
k get svc,ep,deploy,pod |grep -v NAME |cut -d' ' -f1 \
    |xargs -I{} /bin/bash -c 'echo "---";kubectl get {} -o yaml' _ {} \
    |tee ingress-nginx.all.yaml
```



## Cilium 

Leaves a set of Unready pods

```bash
sudo crictl pods
```

Manually prune 

```
ansibash 'sudo crictl pods |grep NotReady |cut -d" " -f1 |xargs -IX sudo crictl stopp X'
ansibash 'sudo crictl pods |grep NotReady |cut -d" " -f1 |xargs -IX sudo crictl rmp X'
 ```

### bash completion

Add to `.bash_functions` or `.bashrc_k8s`

```bash
[[ $(type -t cilium) ]] && source <(cilium completion bash)
```

# 2024-04-01

## K8s cluster

@ `gitops@vm128` 

- HALB test @ SELinux @ Enfocing
- `kubeadm ... --config ...` pulls from our local, insecure registry if config declares it.
    - Tested with modified `~/kubeadm.config.yaml`; pulled all K8s v1.29.3 images.
- `kubectl` has connectivity to K8s API server with or without SELinux `Enforcing` 


Create deployment in default namespace

```bash
kn default
reg='foo121.bar:5000'
img="$reg/abox:latest"
k create deploy abox --image $img -- sleep 1d
```
```bash
k get deploy abox -o yaml |tee k.get.deploy.abox.yaml
k get pod abox-84b7cbb58d-nc94b -o yaml |tee k.get.pod.abox.yaml
```

## IA : Docker : AppArmor

AppArmor (Application Armor) is a Linux security module that protects an operating system and its applications from security threats. To use it, a system administrator associates an AppArmor security profile with each program. ***Docker expects to find an AppArmor policy loaded and enforced.***

Docker automatically generates and loads a default profile for containers named `docker-default`. The Docker binary generates this profile in tmpfs and then loads it into the kernel.


```bash
apparmor_parser -r -W /path/to/your_profile

docker run --rm -it --security-opt apparmor=your_profile hello-world
```


# 2024-03-28

## SELinux


```bash

fixfiles -F onboot

# SELinux [Security Enhanced Linux] :: File AND Process Security Policy 
	#
	# TROUBLESHOOTING; turn it off, restart the problematic service; problem fixed?
        sestatus                          # Status + info of SELinux 
		getenforce                        # 'Enforcing'|'Permissive'; current SELinux setting

        # Find reason for fail
        sealert -l "*"

        ausearch -m avc -c $process_name  # SELinux audit logs 
        # Adjust policies : Allow Apache to use port 443
        semanage port -a -t http_port_t -p tcp 443 
        # Recursively relabel a directory
		restorecon -vR  FOLDER            # Update SELinux policies at affected folder

		setenforce {enforcing|permissive} # can toggle to roubleshoot
		setenforce 0|1                    # '0' is 'permissive'

		systemctl restart SERVICE         # now see if it works sans SELinux 
		systemctl status SERVICE          # shows LOG of ACTIVITY for that service

		ls -ZA                            # show SECURITY CONTEXT; LABEL per USER:ROLE:TYPE 
	
		# RESTORE a user's home dir 
	    cd /
	    sudo restorecon -RFv /home/$user
	    sudo restorecon -RFv /home/$user/*
	    sudo restorecon -RFv /home/$user/*.*
	    sudo restorecon -RFv /home/$user/.*

        # Examine http
        semanage port -l |grep http
        # Change the SELinux type of port 3131 to match port 80: 
        semanage port -a -t http_port_t -p tcp 3131

        # Change SELinux type of /new content to that of /old
        semanage fcontext -a -e /old /new

        # Identify SELinux booleans relevant for NFS, CIFS, and Apache:
        semanage boolean -l |grep 'nfs\|cifs' |grep httpd
        # Enable the identified booleans: 
        setsebool httpd_use_nfs on
        setsebool httpd_use_cifs on
        # Verify booleans are on
        getsebool -a |grep 'nfs\|cifs' |grep httpd

	#
	# Enforces MAC [Mandatory Access Control] vs. Linux's DAC [Discretionary Access Control]
	# SECURITY CONTEXT: 3-string [label] context assigned to EVERY user AND process
	#  USER:ROLE:TYPE[domain]
	#   Type Enforcement; on processes and file system objects; object types; policy rules
	#   MCS [Multi Category Security] Enforcement; Roles?
	#   MLS [Multi Level Security] Enforcement; control processes based on the level of the data they; not used much
	# SELinux users and roles do not have to be related to the actual system users and roles.
	# https://en.wikipedia.org/wiki/Security-Enhanced_Linux
	# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/SELinux_Users_and_Administrators_Guide/sect-Security-Enhanced_Linux-Introduction-SELinux_Architecture.html
	# UPG :: User Private Groups; each user gets own group 
	# Typical UNIX umask of 022 [set @ /etc/bashrc] unnecessary, since group is private
	id # =>
	uid=500($user) gid=500($user) groups=500($user),10(wheel) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023

	# RHEL / SELinux utilities
		useradd(8)      # create new users.
		userdel(8)      # delete users.
		usermod(8) 	    # modify users.
		groupadd(8)     # create new groups.
		groupdel(8)     # delete groups.
		groupmod(8)     # modify group membership.
		gpasswd(1)      # manage /etc/group file.
		grpck(8)        # verify integrity of /etc/group file.
		pwck(8)         # verify integrity of /etc/passwd AND /etc/shadow files.
		pwconv(8)       # pwconv, pwunconv, grpconv, grpunconv; convert shadowed info (pw,groups)
		id(1)           # display user and group IDs.
		umask(2)        # work with file mode creation mask. 

		# Add user foo to sudo group
		sudo usermod -a -G sudo foo 

		# Create a new group named foo
		sudo groupadd foo 

	# RHEL / SELinux files
		group(5)    # /etc/group; define system groups.
		passwd(5)   # /etc/passwd; define user information.
		shadow(5)   # /etc/shadow; set passwords and account expiration info 

	# SELinux MODE [enforcing|permissive]; set per boot
		/etc/sysconfig/selinux 
			SELINUX=enforcing
			
				enforcing  # log & stop  syscall if avc:denied
				permissive # log & allow syscall if avc:denied
				disabled   # No SELinux functionality
				
	# Functional Diagram
		syscall # [every process] => SELinux => policy [avc:denied] => auditd 
								
		# auditd [AUDIT DAEMON]						
			/etc/audit/auditd.conf
			/var/log/audit/audit.log # all SELinux events

	# TROUBLESHOOT :: turn selinux on/off 
	getenforce 
	setenforce {enforcing|permissive} # can toggle to troubleshoot
	setenforce 0|1                    # ... or that way 
	
	# CONTEXT :: 3 Parts [USER:ROLE:TYPE] [RHCSA focuses only on TYPE]

		# @ Files; show SECURITY CONTEXT; LABEL per USER:ROLE:TYPE 
			ls -Z /foo # =>
				drwxrwxr-x. u1 u1 unconfined_u:object_r:user_home_t:s0 scripts
				-rwxrwxr-x. u1 u1 unconfined_u:object_r:user_home_t:s0 _u1.cfg
				
				# on copy, context inherited from destination parent [typically]
				# on move, context moves with the dir/file [typically]
				
		# @ Processes; show SECURITY CONTEXT; USER:ROLE:TYPE
			ps Zaux # =>
				system_u:system_r:sshd_t:s0-s0:c0.c1023 878 ?  Ss     0:00 /usr/sbin/sshd
				system_u:system_r:sshd_t:s0-s0:c0.c1023 4079 ? Ss     0:00 sshd: u1 [priv]

			netstat -Ztulpen # =>
				tcp  ... 0.0.0.0:22 ...  878/sshd  system_u:system_r:sshd_t:s0-s0:c0.c1023

	# BOOLEANS :: off|on <==> PREVENT(off) OR ALLOW(on)
		getsebool -a | grep ssh # =>
			fenced_can_ssh --> off
			selinuxuser_use_ssh_chroot --> off
			ssh_chroot_rw_homedirs --> off
			ssh_keysign --> off
			ssh_sysadm_login --> off
		
		# SET BOOLEAN
		# -P(persistent)
		setsebool [ -PNV ] boolean value | bool1=val1 bool2=val2 

			# E.g., allow ftp users to access their home dir 
			getsebool -a | grep ftp
			setsebool ftp_home_dir on 
			semanage boolean -l | grep ftp # =>
			BOOLEAN (CURRENT_VALUE,DEFAULT_VALUE) ...
		
	# WHY SELinux :: Hacked [Story]: 
	#  Developer under admin was hacked thru PHP backdoor; invader opened a shell and stored large number of PHP scripts on victim [admin] machine; scripts used to attack others. Web sites require access and executables @ '/tmp' and '/var/tmp'; Permissions needed too; Firewalling shouldn't block access either. So, Linux hasn't many options to secure. 
	
		# Thus, SELinux; sets file AND process access per process/application, per POLICY 
	
		# CONTEXT of httpd process ...
		ps -Zaux | grep http # =>
			system_u:system_r:httpd_t:s0 ... /usr/sbin/httpd
			
		# CONTEXT of files @ Apache [httpd] access
			# Apache document root dir, '/var/www/html', has CONTEXT [TYPE]: 'httpd_sys_content_t'
			ls -Z /var/www # =>
				drwxr-xr-x. root root system_u:object_r:httpd_sys_script_exec_t:s0 cgi-bin
				drwxr-xr-x. root root system_u:object_r:httpd_sys_content_t:s0 html
			# /tmp dir has CONTEXT [TYPE]: 'tmp_t'
			ls -Zdl /tmp # =>
				drwxrwxrwt. 11 system_u:object_r:tmp_t:s0       root root 240 Feb 12 10:45 /tmp

	# CONFIGURE SELinux :: semanage [man pages have good examples; 'man semanage-fcontext']
		# semanage writes to SELinux POLICY, not to FS
			# E.g., fix context for web-site's DocumentRoot access 
			#  [DocumentRoot (re)set @ /etc/httpd/conf/httpd.conf]  
			semanage fcontext -a -t httpd_sys_content_t "/web(/.*)?" # ... RegEx
			restorecon -R -v /web # (re)writes to FS and validates, per POLICY; 
										 # restores any FS CONTEXT errors, per POLICY
			
			# E.g., fix port binding ... 
			#  [DocumentRoot (re)set @ /etc/httpd/conf/httpd.conf]  
			semanage port -a -t http_port_t -p tcp 8888
			restorecon -R -v /web
			# ... NOPE; failed.
			
		# chcon :: NEVER USE IT; BAD PROGRAM
		#  Writes directly to FS, NOT to POLICY
		#  so [subsequent] relabel activity will reset per policy
			# E.g., say need to set context label 'httpd_sys_content_t' on /foo dir
			chron -R --type=httpd_sys_content_t /blah       # BAD 
			semanage -a -t httpd_sys_content_t "/foo(/.*)?" # GOOD
			# semanage writes to POLICY which then writes to FS
			
		# FIND LABELs [per CONTEXT USER:ROLE:TYPE]
			semanage fcontext -l # list all CONTEXTs; very long list
			# man page for each context/service
			# CentOS-6 [legacy]; very helpful
				man -k _selinux  
			# CentOS-7 # not installed by default
				yum -y install policycoreutils-devel
				sepolicy manpage -a # FAILed; 'No such file or directory...' 
				mandb
				man -k _selinux
		
		# TROUBLESHOOTing 
			yum list installed | grep setrouble # should be installed by default
	
			# SELinux decisions, such as allowing or disallowing access, are cached.
			# AVC [Access Vector Cache]; 
			# Denial messages; AVC denials"; logged to location per daemon
			# Daemon	                                    Log Location
			auditd on                                    /var/log/audit/audit.log
			auditd off; rsyslogd on	                     /var/log/messages
			setroubleshootd, rsyslogd, and auditd on	   /var/log/audit/audit.log
			Easier-to-read denial messages also sent to  /var/log/messages
			
			# AUDIT LOG :: header 'AVC'
			/var/log/audit/audit.log
			
			systemctl status auditd
			grep AVC /var/log/audit/audit.log
			
			less /var/log/messages

```

# 2024-05-27

## Use `cri-dockerd`

At each node:

Open `/var/lib/kubelet/kubeadm-flags.env` on each affected node.  
Modify the `--container-runtime-endpoint` flag to `unix:///var/run/cri-dockerd.sock`.  
Modify the `--container-runtime` flag to `remote` (unavailable in Kubernetes v1.27 and later).


@ `/var/lib/kubelet/kubeadm-flags.env`

```text
--container-runtime-endpoint=unix:///var/run/cri-dockerd.sock
--container-runtime=remote # NOT @ v1.27+
```


# 2024-03-26

## k8s-core

- `lemonldapng/lemonldap-ng-controller:0.2.0`
    - @ `ingress-nginx-controller` chart;  
      NOT part of the required deployment

# 2024-03-25

## Finish K8s core install : Cilium by Helm

### Cilium : upgrade @ mods (`values.yaml`) 

to cure the image-pull problem of local registry.

- Mod @ vim : 
    1. `:%s#quay.io/cilium#foo121.bar:5000/cilium#g`
    2.  `useDigest: false`

&nbsp;

@ `gitops@vm128`

```bash
push /tmp/k8s-air-gap-install/cilium-1.15.1 
helm upgrade cilium cilium/ -f values.yaml --install --namespace kube-system
cilium status 
```
- See See `logs/make.2024-03-25T....log`

```bash
$ make kw
ssh gitops@vm128 kw |& tee ...
NAME                                                   READY   STATUS    RESTARTS         AGE    IP               NODE                           NOMINATED NODE   READINESS GATES
cilium-n7shx                                           1/1     Running   0                9m1s   10.11.111.250   foo128.bar   <none>           <none>
cilium-operator-74c98b497-6jblf                        1/1     Running   0                9m1s   10.11.111.250   foo128.bar   <none>           <none>
cilium-operator-74c98b497-z69tn                        1/1     Running   0                9m1s   10.11.111.251   foo129.bar   <none>           <none>
cilium-rp98x                                           1/1     Running   0                9m2s   10.11.111.249   foo130.bar   <none>           <none>
cilium-sq44w                                           1/1     Running   0                9m2s   10.11.111.251   foo129.bar   <none>           <none>
coredns-56d5b969dd-4n8pq                               1/1     Running   0                12d    10.0.0.72        foo129.bar   <none>           <none>
coredns-56d5b969dd-5zzcb                               1/1     Running   0                12d    10.0.0.112       foo129.bar   <none>           <none>
etcd-foo128.bar                      1/1     Running   3 (3d11h ago)    12d    10.11.111.250   foo128.bar   <none>           <none>
etcd-foo129.bar                      1/1     Running   2 (3d12h ago)    12d    10.11.111.251   foo129.bar   <none>           <none>
etcd-foo130.bar                      1/1     Running   1 (3d11h ago)    7d     10.11.111.249   foo130.bar   <none>           <none>
kube-apiserver-foo128.bar            1/1     Running   10 (3d11h ago)   12d    10.11.111.250   foo128.bar   <none>           <none>
kube-apiserver-foo129.bar            1/1     Running   12 (2d11h ago)   12d    10.11.111.251   foo129.bar   <none>           <none>
kube-apiserver-foo130.bar            1/1     Running   12 (3d11h ago)   7d     10.11.111.249   foo130.bar   <none>           <none>
kube-controller-manager-foo128.bar   1/1     Running   17 (8m26s ago)   12d    10.11.111.250   foo128.bar   <none>           <none>
kube-controller-manager-foo129.bar   1/1     Running   17 (36h ago)     12d    10.11.111.251   foo129.bar   <none>           <none>
kube-controller-manager-foo130.bar   1/1     Running   18 (12h ago)     7d     10.11.111.249   foo130.bar   <none>           <none>
kube-proxy-g8bb7                                       1/1     Running   0                12d    10.11.111.250   foo128.bar   <none>           <none>
kube-proxy-k6hlb                                       1/1     Running   0                7d     10.11.111.249   foo130.bar   <none>           <none>
kube-proxy-m7kl7                                       1/1     Running   0                12d    10.11.111.251   foo129.bar   <none>           <none>
kube-scheduler-foo128.bar            1/1     Running   17 (12h ago)     12d    10.11.111.250   foo128.bar   <none>           <none>
kube-scheduler-foo129.bar            1/1     Running   18 (36h ago)     12d    10.11.111.251   foo129.bar   <none>           <none>
kube-scheduler-foo130.bar            1/1     Running   18 (12h ago)     7d     10.11.111.249   foo130.bar   <none>           <none>
Connection to 10.11.111.250 closed.

```

### `firewalld` mods + enable + test

Script and apply 

Recipe for standalone and composable `Makefile` recipe for all the firewalls. See `scripts/firewalld-*.sh` and `halb/firewalld-halb.sh`

```bash
make firewalls
```
- See `logs/make....firewalls.log`

Test connectivity :

- Enable and start `firewalld` 
- Try client (expect fail) @ any node other than active VIP (currently `vm128`) 
    - `ansibash kw`
        - Okay @ vm128; fail @ API connectivity at others (vm129, vm130)
- Add firewall mods 
    - `make firewalls`
- Retest (expect success)
    - `ansibash kw`
        - Success @ all nodes.

## Transfer this core

Bundle core assets and create transfer ticket

- halb
- kubernetes-v1.29.3
- registry-1.8.3
- cilium-1.15.1

# 2024-03-24

## rhel9-almalinux-9.3

Update with relevant `rhel8-air-gap` mods

# 2024-03-21

## Cilium 

CLI and Helm chart installed manually. 
See `scripts/install-cilium.sh` .

```bash
helm upgrade cilium $folder/cilium/ -f values.yaml --install --namespace kube-system
cilium status
```

All its pods are stuck in ImagePullBackOff and will remain so until chart is upgraded 
using a modified `values.yaml` that accounts for our local (vm121) registry 
from which  containerd is configured to pull. See `/etc/containerd/config.toml`
