##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
include Makefile.settings

##############################################################################
## Environment variable rules:
## - Any TRAILING whitespace KILLS its variable value and may break recipes.
## - ESCAPE only that required by the shell (bash).
## - Environment hierarchy:
##   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
##  	  - `FOO ?= bar` is overridden by parent setting; `export FOO=new`.
##  	  - `FOO :=`bar` is NOT overridden by parent setting.
##   - Docker YAML `env_file:` OVERRIDEs OS and Makefile environments.
##   - Docker YAML `environment:` OVERRIDEs YAML `env_file:`.
##   - CMD-inline OVERRIDEs ALL REGARDLESS; `make recipeX FOO=new BAR=new2`.

##############################################################################
## $(INFO) : Usage : `$(INFO) 'What ever'` prints a stylized "@ What ever".
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "@ $$1";printf $(RESTORE)' MESSAGE

##############################################################################
## Project Meta

export PRJ_ROOT   := $(shell pwd)
export LOG_PREFIX := make.$(shell date '+%Y-%m-%dT%H.%M.%Z')

##############################################################################
## Registry

#export CNCF_REGISTRY_IMAGE    ?= registry:2.8.3
#export CNCF_REGISTRY_HOST     ?= registry.local
#export CNCF_REGISTRY_HOST     ?= a0.local
#export CNCF_REGISTRY_PORT     ?= 5000
#export CNCF_REGISTRY_ENDPOINT ?= ${CNCF_REGISTRY_HOST}:${CNCF_REGISTRY_PORT}
#export CNCF_REGISTRY_STORE    ?= /mnt/registry


##############################################################################
## Cluster

## HAProxy/Keepalived : 
### VIP within targets' network mask
export HALB_VIP      ?= 192.168.28.222
### anet Network is segmented (/27; 5 bit mask) so 30 hosts per (user? program?)
export HALB_MASK     ?= 24
#export HALB_MASK6    ?= 64
### CIDR: 10.11.111.234/27 : IP Range : 224-255 
export HALB_CIDR     ?= ${HALB_VIP}/${HALB_MASK}
#export HALB_VIP6     ?= 0:0:0:0:0:ffff:0aa0:7164
#export HALB_CIDR6    ?= ${HALB_VIP6}/${HALB_MASK6}
#export HALB_PORT     ?= 8443
export HALB_DEVICE   ?= eth0
export HALB_FQDN_1   ?= a1.local
export HALB_FQDN_2   ?= a2.local
export HALB_FQDN_3   ?= a3.local

#export HALB_ENDPOINT ?= ${HALB_VIP}:${HALB_PORT}

## ansibash 
### Public-key string of ssh user must be in ~/.ssh/authorized_keys of GITOPS_USER at all targets.
#export GITOPS_USER          ?= $(shell id -un)
export GITOPS_USER          ?= u1
export GITOPS_KEY           ?= ${HOME}/.ssh/vm_common
export GITOPS_NODES_MASTER  ?= a1 a2 a3
export GITOPS_NODES_WORKER  ?= 
export GITOPS_TARGET_LIST   ?= ${GITOPS_NODES_MASTER} ${GITOPS_NODES_WORKER}
export GITOPS_SRC_DIR       ?= $(shell pwd)
#export GITOPS_DST_DIR       ?= ${GITOPS_SRC_DIR}
export GITOPS_DST_DIR       ?= /tmp/$(shell basename "${GITOPS_SRC_DIR}")

export ANSIBASH_TARGET_LIST ?= ${GITOPS_TARGET_LIST}
export ANSIBASH_USER        ?= ${GITOPS_USER}

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
## K8s RELEASEs https://kubernetes.io/releases/
export K8S_VERSION            ?= 1.29.6
export K8S_PROVISIONER        ?= ${GITOPS_USER}
export K8S_PROVISIONER_KEY    ?= ${HOME}/.ssh/vm_common
#export K8S_REGISTRY           ?= registry.k8s.io
export K8S_REGISTRY           ?= ${CNCF_REGISTRY_ENDPOINT}
export K8S_VERBOSITY          ?= 5
export K8S_INIT_NODE_SSH      ?= $(shell echo ${GITOPS_NODES_MASTER} |cut -d' ' -f1)
export K8S_INIT_NODE          ?= ${HALB_FQDN_1}
export K8S_KUBEADM_CONFIG     ?= kubeadm-config.yaml
export K8S_IMAGE_REPOSITORY   ?= registry.k8s.io
export K8S_CONTROL_PLANE_IP   ?= ${HALB_VIP}
export K8S_CONTROL_PLANE_PORT ?= ${HALB_PORT}
#export K8S_SERVICE_CIDR       ?= 10.55.0.0/12
export K8S_SERVICE_CIDR       ?= 10.96.0.0/12
#export K8S_POD_CIDR           ?= 10.20.0.0/16
export K8S_POD_CIDR           ?= 10.244.0.0/24
export K8S_CRI_SOCKET         ?= unix:///var/run/containerd/containerd.sock
export K8S_CGROUP_DRIVER      ?= systemd
## PKI : These values are overridden by those at Makefile.settings 
### K8S_CERTIFICATE_KEY=$(kubeadm certs certificate-key)
#export K8S_CERTIFICATE_KEY    ?= e7bd0818d8ff317537d2f65ab553a3185f0ddae646dafc224a2e98e873acc4bc
### kubeadm init phase upload-certs --upload-certs …
export K8S_CERTIFICATE_KEY    ?= 991348057d057866f56feabfb1dfe0f3dd06dc848a2dc79b8c51b1e7cde7a612
### K8S_CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"
export K8S_CA_CERT_HASH       ?= sha256:212b51ebc405c032152bd9fe8264d88fd876afc971c247562be8da61d6aec3c2
### K8S_BOOTSTRAP_TOKEN=$(kubeadm token generate)
export K8S_BOOTSTRAP_TOKEN    ?= nmijxk.irqyzts0x5glr2cr

#export K8S_INSTALL_DIR ?= k8s-air-gap-install

##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Install K8s onto all target hosts : RHEL 9 is expected'
	@echo "env          : Print Makefile environment"
#	@echo "pki          : Setup this user's PKI at remote provisioner account"
#	@echo "pki2         : Same but automated. Requires user having root access sans password"
#	@echo "hello        : hostname and user at target(s)"
	@echo "home         : Update dotfiles of targets per Git project @ github.com/sempernow/home.git"
#	@echo "dl           : Download to admin machine all assets; RPMs, binaries, charts, …"
#	@echo "dl-rpms      : Download to admin machine all RPM packages and all their dependencies"
#	@echo "dl-bins      : Download to admin machine all non-RPM assets (except container images)"
#	@echo "push         : Push this project, ${PWD}, to targets @ /tmp/"
#	@echo "prep         : Pre-install tasks"
#	@echo "firewalls    : firewalld mods"
#	@echo "rpms         : Install all RPM packages"
#	@echo "bins         : Install binaries"
	@echo "prep         : kernel selinux swap : See scripts/configure-*"
	@echo "  kernel     : Configure targets' kernel for K8s/CNI/CRI : load modules and set runtime params"
	@echo "  selinux    : Configure targets' SELinux : Set to Permissive"
	@echo "  swap       : Configure targets' swap : Disable all swap devices"
	@echo "reboot       : Reboot targets"
	@echo "provision    : cri k8s : See scripts/provision-*.sh"
	@echo "  cri        : Provision targets with CRI tools and services"
	@echo "  k8s        : Provision targets with K8s/CNI tools and services"
#	@echo "post         : Configure host, services, and user (${GITOPS_USER})"
#	@echo "etcd-test    : Smoke test etcd"
#	@echo "enforcing    : Set SELinux to Enforcing (reboot targets afterward)"
#	@echo "proxy        : Restore /etc/environment from ~/etc.environment (uploaded earlier)"
#	@echo "============== "
#	@echo "lbmake       : Generate HA-LB configurations from .tpl files"
#	@echo "lbconf       : Configure HA LB on all control nodes"
#	@echo "lbverify     : Verify HA-LB dynamics"
#	@echo "lbshow       : Show HA-LB status"
#	@echo "============== "
#	@echo "imghelm      : Build list of all helm-chart images"
#	@echo "imgload      : Load container images into Docker cache"
#	@echo "imgreg       : docker run … a CNCF-distribution registry (${CNCF_REGISTRY_ENDPOINT}) on this machine (local)"
#	@echo "imgpush      : Tag and push container images to local registry (${CNCF_REGISTRY_ENDPOINT})"
#	@echo "imgcat       : GET /v2/_catalog of local registry (${CNCF_REGISTRY_ENDPOINT})"
	@echo "============== "
	@echo "conf-prep    : Generate cluster PKI (if not exist) at K8S_INIT_NODE; update Makefile.settings"
	@echo "conf-gen     : Generate ${K8S_KUBEADM_CONFIG} from .tpl"
	@echo "conf-push    : Upload ${K8S_KUBEADM_CONFIG} to all nodes"
	@echo "conf-pull    : kubeadm config images pull -v${K8S_VERBOSITY} --config ${K8S_KUBEADM_CONFIG}"
	@echo "init-pre     : kubeadm init phase preflight"
	@echo "============== "
	@echo "init         : kubeadm init … (${GITOPS_USER}@${K8S_INIT_NODE_SSH})"
	@echo "upload-certs : Re-upload certificates for joining another control-plane node"
	@echo "join-command : Print full join command for a control-plane node (includes token and hash)"
	@echo "join-control : Join all other control-plane nodes into cluster : kubeadm join --control-plane …"
	@echo "join-worker  : Join all worker nodes into the cluster : kubeadm join …"
	@echo "conf-kubectl : Make ~/.kube/config"
	@echo "nodes        : kubectl get nodes"
	@echo "kw           : kubectl get pods -o wide (current namespace; see kn)"
	@echo "cilium       : cilium status"
	@echo "etcd-members : List member nodes of the etcd cluster (expect all control-plane nodes)"


env : 
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep HALB_ 
	@env |grep K8S_
	@env |grep GITOPS_ 


perms :
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \+
	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \+

    ##… Each affected file has mtime RESET by `make perms`

#ansibash sudo firewall-cmd --permanent --zone=public --service=k8s-workers --add-interface=cni0
foo :
	bash foo.sh

#echo ${GITOPS_SRC_DIR}
#echo /tmp/$(shell basename "${GITOPS_SRC_DIR}")

##############################################################################
## Recipes : Cluster

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	sudo nmap -sn ${HALB_CIDR} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.scan.nmap.log
#	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
#		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.scan.arp-scan.log

# Smoke test this setup
status hello :
	@ansibash 'printf "%12s: %s\n" User $$(id -un) \
		&& printf "%12s: %s\n" Host $$(hostname) \
		&& printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
		&& printf "%12s: %s\n" SELinux $$(getenforce) \
		&& printf "%12s: %s\n" containerd $$(systemctl is-active containerd) \
		&& printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
	'

home :
	ansibash 'pushd home && git pull && make user && make all'

# Configure the provisioner (GITOPS_USER) on each node. Final task is manual.
# See script for details.
pki :
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} scp ${GITOPS_KEY}.pub {}:. 
	printf "%s\n" ${GITOPS_TARGET_LIST} |xargs -I{} scp ${GITOPS_SRC_DIR}/scripts/create_provisioner_target_node.sh {}:. 
	bash ${GITOPS_SRC_DIR}/scripts/create_provisioner_target_node_instruct.sh

# Configure the provisioner (GITOPS_USER) on each node ONLY IF ssh user ($USER) has NOPASSWD set at /etc/sudoers.d/$USER .
pki2 :
	GITOPS_USER=${USER} ANSIBASH_USER=${USER} ansibash -s ${GITOPS_SRC_DIR}/scripts/create_provisioner_target_node.sh '$(shell cat ${GITOPS_KEY}.pub)'

prep : kernel selinux swap

kernel :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-kernel.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.configure-kernel.log
selinux :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-selinux.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.configure-selinux.log
swap :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/configure-swap.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.configure-swap.log

reboot :
	ansibash sudo reboot

provision : cri k8s 
cri :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/provision-cri.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.provision-cri.log
k8s :
	ansibash -s ${GITOPS_SRC_DIR}/scripts/provision-kubernetes.sh \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.provision-kubernetes.log


## Generate cluster PKI (if not exist) and declare kubeadm-relevant params at Makefile.settings 
conf-prep :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} /bin/bash -s < \
		${GITOPS_SRC_DIR}/scripts/conf-prep.sh ${K8S_INIT_NODE} ${K8S_KUBEADM_CONFIG} \
		|grep 'export K8S_' |& tee ${GITOPS_SRC_DIR}/scripts/conf-prep
	echo '## @ Makefile.settings : This file is DYNAMICALLY GENERATED  (See Makefile recipes)' \
		|tee Makefile.settings
	cat scripts/conf-prep |tee -a Makefile.settings

conf-gen :
	cat ${GITOPS_SRC_DIR}/kubernetes/${K8S_KUBEADM_CONFIG}.tpl \
		|sed 's#K8S_VERSION#${K8S_VERSION}#g' \
		|sed 's#K8S_REGISTRY#${K8S_REGISTRY}#g' \
		|sed 's#K8S_VERBOSITY#${K8S_VERBOSITY}#g' \
		|sed 's#K8S_INIT_NODE#${K8S_INIT_NODE}#g' \
		|sed 's#K8S_IMAGE_REPOSITORY#${K8S_IMAGE_REPOSITORY}#g' \
		|sed 's#K8S_CONTROL_PLANE_IP#${K8S_CONTROL_PLANE_IP}#g' \
		|sed 's#K8S_CONTROL_PLANE_PORT#${K8S_CONTROL_PLANE_PORT}#g' \
		|sed 's#K8S_SERVICE_CIDR#${K8S_SERVICE_CIDR}#g' \
		|sed 's#K8S_POD_CIDR#${K8S_POD_CIDR}#g' \
		|sed 's#K8S_CRI_SOCKET#${K8S_CRI_SOCKET}#g' \
		|sed 's#K8S_CGROUP_DRIVER#${K8S_CGROUP_DRIVER}#g' \
		|sed 's#K8S_BOOTSTRAP_TOKEN#${K8S_BOOTSTRAP_TOKEN}#g' \
		|sed 's#K8S_CERTIFICATE_KEY#${K8S_CERTIFICATE_KEY}#g' \
		|sed 's#K8S_CA_CERT_HASH#${K8S_CA_CERT_HASH}#g' \
		|sed '/^ *#/d' |sed '/^\s*$$/d' \
		|tee ${GITOPS_SRC_DIR}/kubernetes/${K8S_KUBEADM_CONFIG}

conf-push :
	ansibash -u ${GITOPS_SRC_DIR}/kubernetes/${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.conf-push.log

conf-pull :
	ansibash sudo kubeadm config images pull -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.conf-pull.log

init-pre init-preflight :
	ansibash sudo kubeadm init phase preflight -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.init-pre.log

init :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm init -v${K8S_VERBOSITY} \
		--upload-certs \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.init.log

upload-certs : 
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm init phase upload-certs \
		--upload-certs \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.upload-certs.log

join-command :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm token create \
		--print-join-command \
		--certificate-key ${K8S_CERTIFICATE_KEY} \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.print-join-command.log

## TODO : Separate kubeadm-config.yaml for join of control v. worker
## https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-JoinControlPlane
join-control :
	ANSIBASH_TARGET_LIST='${GITOPS_NODES_MASTER}' \
		&& ansibash sudo kubeadm join ${K8S_CONTROL_PLANE_IP}:${K8S_CONTROL_PLANE_PORT} \
			-v${K8S_VERBOSITY} \
			--token ${K8S_BOOTSTRAP_TOKEN} \
			--discovery-token-ca-cert-hash ${K8S_CA_CERT_HASH} \
			--control-plane \
			--certificate-key ${K8S_CERTIFICATE_KEY} \
			--cri-socket ${K8S_CRI_SOCKET} \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log


# GITOPS_TARGET_LIST=${GITOPS_NODES_MASTER} \
# 	&& ansibash sudo kubeadm join -v${K8S_VERBOSITY} \
# 		--control-plane \
# 		--config ${K8S_KUBEADM_CONFIG} \
# 		|& tee ${GITOPS_SRC_DIR}/logs/kubeadm.join-control.log

join-worker :
	ANSIBASH_TARGET_LIST="${GITOPS_NODES_WORKER}" \
		&& ansibash sudo kubeadm join -v${K8S_VERBOSITY} \
			--config ${K8S_KUBEADM_CONFIG} \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.join-worker.log

etcd-members :
	ANSIBASH_TARGET_LIST='${GITOPS_NODES_MASTER}' \
		&& ansibash sudo /usr/local/bin/etcdctl member list \
			--endpoints=https://127.0.0.1:2379 \
			--cacert=/etc/kubernetes/pki/etcd/ca.crt \
			--cert=/etc/kubernetes/pki/etcd/server.crt \
			--key=/etc/kubernetes/pki/etcd/server.key \
			|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.etcd-members.log

conf-kubectl :
	bash make.recipes.sh conf_kubectl

node nodes get-nodes :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} kubectl get nodes \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.get-nodes.log

kw :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} kw \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.kw.log

cilium :
	ssh ${GITOPS_USER}@${K8S_INIT_NODE_SSH} cilium status \
		|& tee ${GITOPS_SRC_DIR}/logs/${LOG_PREFIX}.cilium.status.log

