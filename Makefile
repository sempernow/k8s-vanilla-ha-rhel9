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
## Registry : registry.k8s.io

#export CNCF_REGISTRY_IMAGE    ?= registry:2.8.3
#export CNCF_REGISTRY_HOST     ?= registry.local
#export CNCF_REGISTRY_HOST     ?= a0.local
#export CNCF_REGISTRY_PORT     ?= 5000
#export CNCF_REGISTRY_ENDPOINT ?= ${CNCF_REGISTRY_HOST}:${CNCF_REGISTRY_PORT}
#export CNCF_REGISTRY_STORE    ?= /mnt/registry

##############################################################################
## HAProxy/Keepalived :
### VIP within targets' network mask
export HALB_VIP      ?= 10.11.111.234
### anet Network is segmented (/27; 5 bit mask) so 30 hosts per (user? program?)
export HALB_MASK     ?= 27
### CIDR: 10.11.111.234/27 : IP Range : 224-255
export HALB_CIDR     ?= ${HALB_VIP}/${HALB_MASK}
export HALB_VIP6     ?= 0:0:0:0:0:ffff:0aa0:7164
export HALB_PORT     ?= 8443
export HALB_DEVICE   ?= ens192
export HALB_FQDN_1   ?= foo128.bar
export HALB_FQDN_2   ?= foo129.bar
export HALB_FQDN_3   ?= foo130.bar

export HALB_ENDPOINT ?= ${HALB_VIP}:${HALB_PORT}

##############################################################################
## Cluster

## ansibash 
### Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER          ?= $(shell id -un)
export ADMIN_USER          ?= u2
export ADMIN_KEY           ?= ${HOME}/.ssh/vm_lime
export ADMIN_NODES_CONTROL ?= a1 a2 a3
export ADMIN_NODES_WORKER  ?= 
export ADMIN_TARGET_LIST   ?= ${ADMIN_NODES_CONTROL} ${ADMIN_NODES_WORKER}
export ADMIN_SRC_DIR       ?= $(shell pwd)
#export ADMIN_DST_DIR       ?= ${ADMIN_SRC_DIR}
export ADMIN_DST_DIR       ?= /tmp/$(shell basename "${ADMIN_SRC_DIR}")

export ANSIBASH_TARGET_LIST ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER        ?= ${ADMIN_USER}

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
## K8s RELEASEs https://kubernetes.io/releases/
export K8S_CLUSTER_NAME       ?= lime
#export K8S_VERSION            ?= $(shell curl -sSL https://dl.k8s.io/release/stable.txt)
export K8S_VERSION            ?= v1.29.6
#export K8S_VERSION            ?= v1.32.0
export K8S_PROVISIONER        ?= ${ADMIN_USER}
export K8S_PROVISIONER_KEY    ?= ${GITIPS_KEY}
#export K8S_REGISTRY           ?= ${CNCF_REGISTRY_ENDPOINT}
export K8S_REGISTRY           ?= registry.k8s.io
export K8S_VERBOSITY          ?= 5
export K8S_INIT_NODE          ?= $(shell echo ${ADMIN_NODES_CONTROL} |awk '{printf $$1}')
export K8S_JOIN_NODES         ?= $(shell echo ${ADMIN_NODES_CONTROL} |awk '{for (i=2; i<NF; i++) printf $$i " "; print $$NF}')
export K8S_KUBEADM_CONF_INIT  ?= kubeadm-config-init.yaml
export K8S_KUBEADM_CONF_JOIN  ?= kubeadm-config-join.yaml
export K8S_JOIN_KUBECONFIG    ?= discovery.yaml
export K8S_CONTROL_PLANE_IP   ?= 192.168.11.101
export K8S_CONTROL_PLANE_PORT ?= 6443
export K8S_NETWORK_DEVICE     ?= eth0
export K8S_ENDPOINT           ?= ${K8S_CONTROL_PLANE_IP}:${K8S_CONTROL_PLANE_PORT}
## CNI projects notoriously ignore custom CIDRs : Even masks (/16 v. /24) are a shaky proposition
#export K8S_SERVICE_CIDR       ?= 10.32.0.0/16
export K8S_SERVICE_CIDR       ?= 10.96.0.0/12
#export K8S_POD_CIDR           ?= 10.22.0.0/16
export K8S_POD_CIDR           ?= 10.244.0.0/16
export K8S_POD_CIDR6          ?= fd00:10:22::/64
# @ Cilium eBPF mode
#export K8S_POD_CIDR           ?= 10.0.0.0/8
export K8S_NODE_CIDR_MASK     ?= 24
export K8S_NODE_CIDR6_MASK    ?= 96
export K8S_CRI_SOCKET         ?= unix:///var/run/containerd/containerd.sock
export K8S_CGROUP_DRIVER      ?= systemd
## PKI : See Makefile.settings : Values are generated ONLY IF NOT EXIST

##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Install K8s onto all target hosts : RHEL9 is expected'
	@echo "env          : Print Makefile environment"
	@echo "mode         : Fix file mode of this source"
	@echo "html         : Process all MD files to HTML"
	@echo "push         : Commit and push this source"
	@echo "============== "
	@echo "status       : Print targets' status"
	@echo "net          : Network interfaces"
	@echo "psrss        : Print targets' top memory usage : RSS [MiB]"
	@echo "home         : Configure shell using latest @ github.com/sempernow/home.git"
	@echo "============== "
	@echo "conf         : kernel selinux swap : See scripts/configure-*"
	@echo "  -kernel    : Configure kernel for K8s/CNI/CRI : load modules and set runtime params"
	@echo "  -selinux   : Configure targets' SELinux : Set to Permissive"
	@echo "  -swap      : Configure targets' swap : Disable all swap devices"
	@echo "reboot       : Reboot targets"
	@echo "install      : Install K8s and all deps"
	@echo "  -rpms      : Install host tools and K8s dep (conntrack)"
	@echo "  -cni       : Install K8s CNI Pod network providers"
	@echo "  -cri       : Install K8s CRI and all deps, and tools"
	@echo "  -k8s       : Install K8s and CNI plugins"
	@echo "============== "
	@echo "lbmake       : Generate HA-LB configurations from .tpl files"
	@echo "lbconf       : Configure HA LB on all control nodes"
	@echo "lbverify     : Verify HA-LB dynamics"
	@echo "lbshow       : Show HA-LB status"
	@echo "============== "
	@echo "init         : Create 1st control node of the cluster" 
	@echo "  -gen       : Generate ${K8S_KUBEADM_CONF_INIT} from template (.yaml.tpl)"
	@echo "  -push      : Upload ${K8S_KUBEADM_CONF_INIT} to all nodes"
	@echo "  -images    : kubeadm config images pull …"
	@echo "  -certs     : Generate cluster PKI (once)"
	@echo "  -pre       : kubeadm init phase preflight …"
	@echo "  -now       : kubeadm init … : at 1st node (${ADMIN_USER}@${K8S_INIT_NODE})"
	@echo "============== "
	@echo "kubeconfig 	: Configure the client"
	@echo "============== "
	@echo "cilium       : Install Cilium"
	@echo "calico       : Install Calico"
	@echo "  -status    : calicoctl commands"
	@echo "kuberouter   : Install Kube Router"
	@echo "  -teardown  : Per-CNI teardown"
	@echo "============== "
	@echo "join-control : Join all other control-plane nodes into cluster"
	@echo "  -prep      : join-certs join-gen join-push"
	@echo "  -certs     : See kubeadm-join-certs.sh"
	@echo "  -gen       : Process ${K8S_KUBEADM_CONF_JOIN}.tpl into YAML"
	@echo "  -push      : Push ${K8S_KUBEADM_CONF_JOIN} to nodes"
	@echo "============== "
	@echo "upload-certs : Generate new certificate-key for K8s store to join node into control-plane"
	@echo "join-command : Print join command for control-plane node : same cert key/hash; new token"
	@echo "join-token   : kubeadm token list"
	@echo "============== "
	@echo "healthz      : K8s API : GET /healthz?verbose"
	@echo "psk          : ps of K8s processes"
	@echo "psrss        : ps sorted by RSS usage"
	@echo "crictl       : CRI status"
	@echo "============== "
	@echo "ingress-nginx: Install Ingress NGINX Controller"
	@echo "  -down      : Teardown"
	@echo "  -e2e       : End-to-end test"
	@echo "============== "
	@echo "metrics      : Install metrics-server, enabling: kubectl top ..."
	@echo "dashboard    : Install K8s Dashboard : Web UI for K8s API"
	@echo "trivy        : Install Trivy Operator by Helm"
	@echo "============== "
	@echo "csi-local    : Install local-path-provisioner"
	@echo "csi-rook-up  : Install Rook Operator / Ceph "
	@echo "csi-rook-down: Teardown Rook Operator / Ceph "
	@echo "============== "
	@echo "efk-up       : Install EFK stack"
	@echo "efk-down     : Teardown EFK stack"
	@echo "============== "
	@echo "teardown     : kubeadm reset and cleanup at target node(s)"

env : 
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep K8S_
	@env |grep ADMIN_ 

perms mode :
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \;
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \;
#	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \;

html :
	find . -type f ! -path './.git/*' -name '*.md' -exec md2html.exe "{}" \;

push commit : html mode
	gc && git push && gl && gs


##############################################################################
## Recipes : Cluster

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	sudo nmap -sn ${HALB_CIDR} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.scan.nmap.log
#	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
#		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.scan.arp-scan.log

# Smoke test this setup
status hello :
	@ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash 'printf "%12s: %s\n" Host $$(hostname) \
			&& printf "%12s: %s\n" User $$(id -un) \
			&& printf "%12s: %s\n" Kernel $$(uname -r) \
			&& printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
			&& printf "%12s: %s\n" SELinux $$(getenforce) \
			&& printf "%12s: %s\n" containerd $$(systemctl is-active containerd) \
			&& printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
		'

network net ip:
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash '\
			ip -brief addr; \
			sudo iptables -L -n -v; \
			sudo nft list ruleset \
		'

psrss :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s scripts/psrss.sh

# Configure bash shell of target hosts using the declared Git project
home :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash 'git clone https://github.com/sempernow/home 2>/dev/null || echo ok'
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash 'pushd home;git pull;make sync-user && make user'

# Configure the installer (ADMIN_USER) on each node. Final task is manual.
# See script for details.
pki :
	printf "%s\n" ${ADMIN_TARGET_LIST} |xargs -I{} scp ${ADMIN_KEY}.pub {}:. 
	printf "%s\n" ${ADMIN_TARGET_LIST} |xargs -I{} scp ${ADMIN_SRC_DIR}/scripts/create_provisioner_target_node.sh {}:. 
	bash ${ADMIN_SRC_DIR}/scripts/create_provisioner_target_node_instruct.sh

# Configure the provisioner (ADMIN_USER) on each node ONLY IF ssh user ($USER) has NOPASSWD set at /etc/sudoers.d/$USER .
pki2 :
	ADMIN_USER=${USER} ANSIBASH_USER=${USER} ansibash -s ${ADMIN_SRC_DIR}/scripts/create_provisioner_target_node.sh '$(shell cat ${ADMIN_KEY}.pub)'

tools :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo dnf install -y conntrack dnf-plugins-core make iproute-tc bash-completion bind-utils tar nc socat rsync lsof wget curl tcpdump traceroute nmap arp-scan git httpd httpd-tools jq vim tree htop fio sysstat

reboot :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo reboot

## Host config
conf : conf-kernel conf-selinux conf-swap
conf-kernel :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/configure-kernel.sh \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.conf-kernel.log
conf-selinux :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/configure-selinux.sh \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.conf-selinux.log
conf-swap :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/configure-swap.sh \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.conf-swap.log

## Install K8s and all deps : RPM(s), binaries, systemd, and other configs
install : install-rpms install-cri install-cni install-k8s
install-rpms:
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/install-rpms.sh \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.install-rpms.log
install-cri :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/install-cri.sh \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.install-cri.log
install-cni :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/install-cni.sh eBPF \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.install-cni.log
install-k8s :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -s ${ADMIN_SRC_DIR}/scripts/install-k8s.sh ${K8S_VERSION} ${K8S_REGISTRY} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.install-k8s.log

#lbclean :
#ansibash -s ${ADMIN_SRC_DIR}/halb/clean-halb.sh ${HALB_VIP} ${HALB_DEVICE}
#ansibash -s ${ADMIN_SRC_DIR}/halb/configure-halb.sh ${HALB_VIP} ${HALB_DEVICE}

#ansibash sudo ip addr del ${HALB_VIP}/24 dev ${HALB_DEVICE}

#bash make.recipes.sh halb
lbmake lbbuild :
	bash ${ADMIN_SRC_DIR}/halb/build-halb.sh
	
#bash halb/push-halb.sh
lbconf :
	scp -p ${ADMIN_SRC_DIR}/halb/keepalived-${HALB_FQDN_1}.conf ${GITOPS_USER}@${HALB_FQDN_1}:keepalived.conf \
		&& scp -p ${ADMIN_SRC_DIR}/halb/keepalived-${HALB_FQDN_2}.conf ${GITOPS_USER}@${HALB_FQDN_2}:keepalived.conf \
		&& scp -p ${ADMIN_SRC_DIR}/halb/keepalived-${HALB_FQDN_3}.conf ${GITOPS_USER}@${HALB_FQDN_3}:keepalived.conf \
		&& ansibash -u ${ADMIN_SRC_DIR}/halb/systemd/99-keepalived.conf \
		&& ansibash -u ${ADMIN_SRC_DIR}/halb/keepalived-check_apiserver.sh \
		&& ansibash -u ${ADMIN_SRC_DIR}/halb/haproxy.cfg \
		&& ansibash -u ${ADMIN_SRC_DIR}/halb/haproxy-rsyslog.conf \
		&& ansibash -u ${ADMIN_SRC_DIR}/halb/etc.hosts \
		&& ansibash -u ${ADMIN_SRC_DIR}/halb/etc.environment \
		&& ansibash -s ${ADMIN_SRC_DIR}/halb/configure-halb.sh ${HALB_CIDR} ${HALB_DEVICE} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.lbconf.log

lbverify : 
	bash ${ADMIN_SRC_DIR}/halb/verify-instruct.sh

lbshow lblook :
#ansibash ip -4 -brief addr show dev ${HALB_DEVICE} |grep -e ${HALB_VIP} -e ===
	ansibash ip -4 -brief addr show dev ${HALB_DEVICE} 
	ansibash 'sudo journalctl -eu keepalived |grep -e Entering -e @'

lbfix :	
	ssh gitops@vm124 /bin/bash -s <${ADMIN_SRC_DIR}/halb/firewalld-halb.sh ${HALB_VIP} ${HALB_VIP6} ${HALB_PORT} ${HALB_DEVICE}


## K8s cluster creation

init-imperative : 
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} \
		sudo kubeadm init --control-plane-endpoint "${K8S_ENDPOINT}" \
			--kubernetes-version ${K8S_VERSION} \
			--upload-certs \
			--pod-network-cidr "${K8S_POD_CIDR}" \
			--service-cidr "${K8S_SERVICE_CIDR}" \
			--apiserver-advertise-address ${K8S_CONTROL_PLANE_IP} \
			--node-name ${K8S_INIT_NODE} \
			--cri-socket "${K8S_CRI_SOCKET}" \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kubeadm.init-imperative.log

# @ init-certs phase : config (K8S_KUBEADM_CONF_INIT) must not have PKI
# @ final init phase : config (K8S_KUBEADM_CONF_INIT) may have PKI, but ours does not.

init : init-purge init-gen init-push init-images init-pre init-now
	@echo === Get kubeconfig and set K8S_CERTIFICATE_KEY @ Makefile.settings prior to join-gen
init-purge :
	bash make.recipes.sh settings_purge
init-gen : 
	bash make.recipes.sh settings_inject \
		${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_INIT} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-gen.log
init-push :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -u ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_INIT} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-push.log
init-images :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo kubeadm config images pull -v${K8S_VERBOSITY} \
			--config ${K8S_KUBEADM_CONF_INIT} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-images.log
## Generate cluster PKI (if not exist) : Cleanup old settings
## This K8S_KUBEADM_CONF_INIT must NOT have PKI (key, hash, token)
init-certs :
	cat ${ADMIN_SRC_DIR}/scripts/kubeadm-init-certs.sh \
		|ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} \
			/bin/bash -s - ${K8S_KUBEADM_CONF_INIT} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-certs.log
	scp ${K8S_INIT_NODE}:Makefile.settings .
init-pre : 
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo kubeadm init phase preflight -v${K8S_VERBOSITY} \
			--config ${K8S_KUBEADM_CONF_INIT} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-pre.log
init-now :
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} \
		sudo kubeadm init -v${K8S_VERBOSITY} \
			--upload-certs \
			--config ${K8S_KUBEADM_CONF_INIT} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-now.log

kubeconfig :
	bash make.recipes.sh kubeconfig

## _install [replace_kube_proxy|pod_ntwk_only] : Default is replace else pod on fail
kuberouter kuberouter-install :
	bash ${ADMIN_SRC_DIR}/cni/kube-router/kube-router.sh _install replace_kube_proxy \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kuberouter-install.log
	kubectl get pod -A -o wide -w

kuberouter-teardown :
	bash ${ADMIN_SRC_DIR}/cni/kube-router/kube-router.sh _teardown \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kuberouter-teardown.log

#cilium : cilium-gen cilium-helm
export cilium_values := values-bpf.yaml
cilium : cilium-gen cilium-cli
cilium-cli :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium.sh install_by_cli \
		${cilium_values} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-cli.log
cilium-gen : 
	bash make.recipes.sh settings_inject \
		${ADMIN_SRC_DIR}/cni/cilium/${cilium_values} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-gen.log
cilium-helm : 
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium.sh install_by_helm \
		${cilium_values} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-helm.log
cilium-teardown :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium.sh teardown \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-teardown.log

export calico_operator := custom-resources-bpf-bgp.yaml
calicoctl calico-status : 
	#kubectl calico get node
	ansibash sudo /usr/local/bin/calicoctl node status
	kubectl get tigerastatuses
	kubectl calico get ippool
	#kubectl calico ipam check
	kubectl calico ipam show --show-blocks
	kubectl calico ipam show --show-configuration
	kubectl calico ipam show --ip=${K8S_CONTROL_PLANE_IP}

calico : calico-operator-gen calico-operator
calico-operator-gen : 
	bash make.recipes.sh settings_inject \
		${ADMIN_SRC_DIR}/cni/calico/operator-method/${calico_operator} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico-operator-gen.log
calico-operator :
	bash ${ADMIN_SRC_DIR}/cni/calico/operator-method/calico-operator.sh apply ${calico_operator}
calico-manifest :
	kubectl create -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/crds.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico.crds.log
	kubectl apply -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/calico.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico.calico.log
calico-teardown :
	bash ${ADMIN_SRC_DIR}/cni/calico/operator-method/calico-operator.sh teardown ${calico_operator} || echo
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/calico.yaml || echo 
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/crds.yaml || echo 

export selector := non-cni
kubeproxy-cleanup :
	kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"${selector}": "true"}}}}}' || echo 
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		ansibash -u scripts/kube-proxy-cleanup.sh
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		ansibash sudo bash kube-proxy-cleanup.sh
kubeproxy-restore :
	kubectl patch ds -n kube-system kube-proxy \
    --type=json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/${selector}"}]'

## Makefile.settings must have valid K8S_CERTIFICATE_KEY 
join-control : join-prep
	ANSIBASH_TARGET_LIST='${K8S_JOIN_NODES}' \
		ansibash sudo bash join-control.sh \
			${K8S_NETWORK_DEVICE} ${K8S_KUBEADM_CONF_JOIN} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log

join-prep : join-gen join-push 
join-certs : init-push
	cat ${ADMIN_SRC_DIR}/scripts/kubeadm-join-certs.sh \
		|ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} \
			/bin/bash -s - ${K8S_KUBEADM_CONF_INIT} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-certs.log
	scp ${K8S_INIT_NODE}:Makefile.settings .
join-gen :
	bash make.recipes.sh settings_inject \
		${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_JOIN} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-gen.log
join-push :
	ANSIBASH_TARGET_LIST='${K8S_JOIN_NODES}' \
		ansibash -u ${ADMIN_SRC_DIR}/scripts/join-control.sh
	ANSIBASH_TARGET_LIST='${K8S_JOIN_NODES}' \
		ansibash -u ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_JOIN}
	ANSIBASH_TARGET_LIST='${K8S_JOIN_NODES}' \
		ansibash -u ~/.kube/config discovery.yaml

join-token :
	@sudo kubeadm token list |awk '{printf "%25s\t%s\t%s\n",$$1,$$2,$$4}'
# Print command to join a node into CONTROL PLANE; same cert key/hash; new token
join-command :
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} \
		sudo kubeadm token create --print-join-command \
		--certificate-key ${K8S_CERTIFICATE_KEY} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.print-join-command.log

# upload-certs (re)generates a certificate key.
# INVALIDATES all certificateKey values of kubeadm-conf-*.yaml
# - Run this only to join a control node AFTER KEY HAS EXPIRED.
# K8S_KUBEADM_CONF_INIT file here should *not* contain any PKI params.
upload-certs : 
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} sudo kubeadm init phase upload-certs \
		--upload-certs --config ${K8S_KUBEADM_CONF_INIT} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.upload-certs.log

watch : 
	watch kubectl get pod -A -o wide
healthz :
	curl -ks https://${K8S_ENDPOINT}/healthz?verbose
psk :
	ansibash psk
crictl : crictl-images crictl-ps crictl-pods
crictl-ps crictl-ctnr :
	ansibash sudo crictl ps 
crictl-pods :
	ansibash sudo crictl pods 
crictl-images :
	ansibash sudo crictl images
images :
	kubectl get po -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' |sort -u
crictl-ready :
	ansibash 'sudo crictl pods |grep NotReady |cut -d" " -f1 |xargs -n1 sudo crictl stopp'
	ansibash 'sudo crictl pods |grep NotReady |cut -d" " -f1 |xargs -n1 sudo crictl rmp'

export ingress_manifest := ingress-nginx-baremetal-v1.12.0.yaml
ingress-nginx ingress-nginx-up : 
	bash ${ADMIN_SRC_DIR}/ingress/ingress-nginx/ingress-nginx.sh install ${ingress_manifest}
ingress-nginx-e2e : 
	bash ${ADMIN_SRC_DIR}/ingress/ingress-nginx/ingress-nginx.sh e2e
ingress-nginx-teardown ingress-nginx-down : 
	bash ${ADMIN_SRC_DIR}/ingress/ingress-nginx/ingress-nginx.sh teardown

metrics metrics-up :
	bash ${ADMIN_SRC_DIR}/observability/metrics/metrics-server/metrics-server.sh apply
metrics-down:
	bash ${ADMIN_SRC_DIR}/observability/metrics/metrics-server/metrics-server.sh delete
dashboard :
	bash ${ADMIN_SRC_DIR}/observability/metrics/dashboard/dashboard.sh

iperftest :
	bash make.recipes.sh iperftest

# k apply -f observability/metrics/dashboard/recommended.yaml
# k -n kubernetes-dashboard create token kubernetes-dashboard
# printf "\n  %s\n" Access @ http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
# k proxy

trivy :
	bash ${ADMIN_SRC_DIR}/security/trivy/trivy-operator-install.sh 

csi-local :
	bash ${ADMIN_SRC_DIR}/csi/local-path-provisioner/local-path-provisioner.sh 

csi-rook-up :
	bash ${ADMIN_SRC_DIR}/csi/rook/rook.sh up

# Reboot after teardown 
export rbd := sdb
csi-rook-down :
	bash ${ADMIN_SRC_DIR}/csi/rook/rook.sh down
	ansibash -u ${ADMIN_SRC_DIR}/csi/rook/rook.sh
	ansibash sudo bash ./rook.sh host_teardown
	ansibash 'sudo wipefs --all /dev/${rbd} && sudo dd if=/dev/zero of=/dev/${rbd} bs=1M count=10'

efk-up :
	bash ${ADMIN_SRC_DIR}/observability/logging/efk/efk.sh apply
efk-down :
	bash ${ADMIN_SRC_DIR}/observability/logging/efk/efk.sh delete

teardown : calico-teardown cilium-teardown kuberouter-teardown
	ANSIBASH_TARGET_LIST="${ADMIN_TARGET_LIST}" \
		&& ansibash -u ${ADMIN_SRC_DIR}/scripts/teardown.sh
	ANSIBASH_TARGET_LIST="${ADMIN_TARGET_LIST}" \
		&& ansibash sudo bash teardown.sh
	tar -C ~ --exclude=cache -caf kube.tgz ~/.kube/config_* \
		&& rm -rf ~/.kube/cache \
		mv ~/.kube/config ~/.kube/config.$(shell date '+%F.%T' |sed s,:,.,g) || echo
