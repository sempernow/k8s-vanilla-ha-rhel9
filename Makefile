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
## Cluster

## ansibash 
### Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER          ?= $(shell id -un)
export ADMIN_USER          ?= u1
export ADMIN_KEY           ?= ${HOME}/.ssh/vm_common
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
export K8S_VERSION            ?= 1.29.6
export K8S_PROVISIONER        ?= ${ADMIN_USER}
export K8S_PROVISIONER_KEY    ?= ${GITIPS_KEY}
#export K8S_REGISTRY           ?= registry.k8s.io
export K8S_REGISTRY           ?= ${CNCF_REGISTRY_ENDPOINT}
export K8S_VERBOSITY          ?= 5
export K8S_INIT_NODE_SSH      ?= $(shell echo ${ADMIN_NODES_CONTROL} |cut -d' ' -f1)
export K8S_INIT_NODE          ?= a1
export K8S_KUBEADM_CONFIG     ?= kubeadm-config-init.yaml
export K8S_IMAGE_REPOSITORY   ?= registry.k8s.io
export K8S_CONTROL_PLANE_IP   ?= 192.168.11.101
export K8S_CONTROL_PLANE_PORT ?= 6443
export K8S_NETWORK_DEVICE     ?= eth0
export K8S_ENDPOINT           ?= ${K8S_CONTROL_PLANE_IP}:${K8S_CONTROL_PLANE_PORT}
export K8S_SERVICE_CIDR       ?= 10.33.0.0/12
#export K8S_SERVICE_CIDR       ?= 10.96.0.0/12
export K8S_POD_CIDR           ?= 10.22.0.0/16
#export K8S_POD_CIDR           ?= 10.244.0.0/16
export K8S_CRI_SOCKET         ?= unix:///var/run/containerd/containerd.sock
export K8S_CGROUP_DRIVER      ?= systemd
## PKI : These values are overridden by those at Makefile.settings 
### K8S_CERTIFICATE_KEY=$(kubeadm certs certificate-key)
#export K8S_CERTIFICATE_KEY    ?= e7bd0818d8ff317537d2f65ab553a3185f0ddae646dafc224a2e98e873acc4bc
### kubeadm init phase upload-certs --upload-certs …
export K8S_CERTIFICATE_KEY    ?= 991348057d057866f56feabfb1dfe0f3dd06dc848a2dc79b8c51b1e7cde7a612
### K8S_CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |openssl rsa -pubin -outform der 2>/dev/null |openssl dgst -sha256 -hex |sed 's/^.* //')"
export K8S_CA_CERT_HASH       ?= sha256:212b51ebc405c032152bd9fe8264d88fd876afc971c247562be8da61d6aec3c2
### K8S_BOOTSTRAP_TOKEN=$(sudo kubeadm token create)
export K8S_BOOTSTRAP_TOKEN    ?= nmijxk.irqyzts0x5glr2cr

#export K8S_INSTALL_DIR ?= k8s-air-gap-install

##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Install K8s onto all target hosts : RHEL9 is expected'
	@echo "env          : Print Makefile environment"
	@echo "mode         : Fix file mode of this source"
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
	@echo "  -cni       : Install K8s CNI Pod network providers"
	@echo "  -cri       : Install K8s CRI and all deps, and tools"
	@echo "  -k8s       : Install K8s and CNI plugins"
	@echo "============== "
	@echo "init         : Create 1st control node of the cluster" 
	@echo "  -certs     : Generate cluster PKI (once) and pull bootstrap creds"
	@echo "  -gen       : Generate ${K8S_KUBEADM_CONFIG} from template (.yaml.tpl)"
	@echo "  -push      : Upload ${K8S_KUBEADM_CONFIG} to all nodes"
	@echo "  -images    : kubeadm config images pull -v${K8S_VERBOSITY} --config ${K8S_KUBEADM_CONFIG}"
	@echo "  -pre       : kubeadm init phase preflight …"
	@echo "  -now       : kubeadm init … (${ADMIN_USER}@${K8S_INIT_NODE_SSH})"
	@echo "============== "
	@echo "kubeconfig 	: Configure the client"
	@echo "============== "
	@echo "cilium       : Install Cilium CNI for Pod Network "
	@echo "calico       : Install Calico CNI for Pod Network"
	@echo "kuberouter-install  : kube-router install"
	@echo "kuberouter-teardown : kube-router teardown"
	@echo "============== "
	@echo "join-control : Join all other control-plane nodes into cluster"
	@echo "upload-certs : Re-upload certificates for joining another control-plane node"
	@echo "join-pre     : Refresh join creds"
	@echo "join-command : Print full join command for a control-plane node (includes token and hash)"
	@echo "join-worker  : Join all worker nodes into the cluster : kubeadm join …"
	@echo "============== "
	@echo "psk          : ps of K8s processes"
	@echo "psrss        : ps sorted by RSS usage"
	@echo "crictl       : CRI status"
	@echo "============== "
	@echo "teardown     : kubeadm reset and cleanup at target node(s)"

env : 
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep K8S_
	@env |grep ADMIN_ 

perms mode :
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \+
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \+
	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \+

html :
	md2html.exe LOG.md
	md2html.exe README.md

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
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
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
		&& ansibash ip -brief addr

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
install : install-cri install-cni install-k8s
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

## K8s cluster creation

init-imperative : init-images init-pre
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} \
		sudo kubeadm init --control-plane-endpoint "${K8S_ENDPOINT}" \
			--kubernetes-version ${K8S_VERSION} \
			--upload-certs \
			--pod-network-cidr "${K8S_POD_CIDR}" \
			--service-cidr "${K8S_SERVICE_CIDR}" \
			--apiserver-advertise-address ${K8S_CONTROL_PLANE_IP} \
			--node-name ${K8S_INIT_NODE} \
			--cri-socket "${K8S_CRI_SOCKET}" \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kubeadm.init.log

init : init-gen init-push init-images init-pre
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} \
		sudo kubeadm init --control-plane-endpoint "${K8S_ENDPOINT}" \
			--upload-certs \
			--config ${K8S_KUBEADM_CONFIG} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kubeadm.init.log

kubeconfig :
	bash make.recipes.sh kubeconfig

join-control-imperative :
	ANSIBASH_TARGET_LIST='${ADMIN_NODES_CONTROL}' \
		&& ansibash sudo kubeadm join "${K8S_ENDPOINT}" \
			-v${K8S_VERBOSITY} \
			--token ${K8S_BOOTSTRAP_TOKEN} \
			--discovery-token-ca-cert-hash ${K8S_CA_CERT_HASH} \
			--control-plane \
			--certificate-key ${K8S_CERTIFICATE_KEY} \
			--cri-socket "${K8S_CRI_SOCKET}" \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log

init-declarative : init-images init-certs init-gen init-push init-pre init-now 

## Catch any CRI registry issues 
init-images :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo kubeadm config images pull -v${K8S_VERBOSITY} \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-images.log

## Generate cluster PKI (if not exist) and pull the related init/join params
init-certs : init-gen init-push
	cat ${ADMIN_SRC_DIR}/scripts/kubeadm-init-certs.sh \
		|ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} \
			/bin/bash -s - ${K8S_KUBEADM_CONFIG} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-certs.log

## Generate kubeadm config file 
init-gen :
	bash ${ADMIN_SRC_DIR}/scripts/kubeadm-conf-gen.sh kubeadm-config-init.yaml

init-push :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -u ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONFIG} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-push.log

init-pre : 
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo kubeadm init phase preflight -v${K8S_VERBOSITY} \
			--config ${K8S_KUBEADM_CONFIG} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-pre.log

init-now :
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm init -v${K8S_VERBOSITY} \
		--upload-certs \
		--config ${K8S_KUBEADM_CONFIG} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init.log

## Only after init
upload-certs : 
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} sudo kubeadm init phase upload-certs \
		--upload-certs --config ${K8S_KUBEADM_CONFIG} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.upload-certs.log

## _install [replace_kube_proxy|pod_ntwk_only] : Default is replace else pod on fail
kuberouter-install :
	bash ${ADMIN_SRC_DIR}/cni/kube-router/kube-router.sh _install replace_kube_proxy \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kuberouter-install.log
kuberouter-teardown :
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/kube-router/kube-router.sh _teardown \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.kuberouter-teardown.log

cilium : cilium-helm
cilium-teardown : cilium-helm-teardown
cilium-cli :
	cilium install --kubeconfig ~/.kube/config --values ${ADMIN_SRC_DIR}/cni/cilium/values.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-cli.log
cilium-helm :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium-helm.sh _install \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-helm-install.log
cilium-helm-teardown :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium-helm.sh _teardown \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.cilium-helm-teardown.log

calico : calico-operator
calico-operator :
	kubectl create -f ${ADMIN_SRC_DIR}/cni/calico/operator-method/tigera-operator.yaml
	kubectl apply -f ${ADMIN_SRC_DIR}/cni/calico/operator-method/custom-resources-bpf-bgp.yaml
calico-manifest :
	kubectl create -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/crds.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico.crds.log
	kubectl apply -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/calico.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico.calico.log
calico-teardown :
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/calico.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico.calico.log
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/crds.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.calico.crds.log

join-control : join-certs join-gen join-push

join-certs : 
	cat ${ADMIN_SRC_DIR}/scripts/kubeadm-join-certs.sh \
		|ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} \
			/bin/bash -s - kubeadm-config-init.yaml \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-certs.log
	scp ${K8S_INIT_NODE_SSH}:Makefile.settings .

join-gen :
	bash ${ADMIN_SRC_DIR}/scripts/kubeadm-conf-gen.sh kubeadm-config-join.yaml
join-push :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -u ${ADMIN_SRC_DIR}/scripts/kubeadm-config-join.yaml \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.init-push.log

join-command :
	ssh -T ${ADMIN_USER}@${K8S_INIT_NODE_SSH} \
		sudo kubeadm token create --print-join-command \
		--certificate-key ${K8S_CERTIFICATE_KEY} \
		|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.print-join-command.log

## TODO : Separate kubeadm-config.yaml for join of control v. worker
## https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-JoinControlPlane
join-control-imperative :
	ANSIBASH_TARGET_LIST='${ADMIN_NODES_CONTROL}' \
		&& ansibash sudo kubeadm join "${K8S_CONTROL_PLANE_IP}:${K8S_CONTROL_PLANE_PORT}" \
			-v${K8S_VERBOSITY} \
			--token ${K8S_BOOTSTRAP_TOKEN} \
			--discovery-token-ca-cert-hash ${K8S_CA_CERT_HASH} \
			--control-plane \
			--certificate-key ${K8S_CERTIFICATE_KEY} \
			--cri-socket ${K8S_CRI_SOCKET} \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log

foo :
	ansibash echo '$$(hostname) and ${K8S_INIT_NODE_SSH}'

join-control-discovery :
	ANSIBASH_TARGET_LIST='a2' \
		&& ansibash -u ${ADMIN_SRC_DIR}/discovery.yaml \
		&& ansibash sudo kubeadm join \
			--discovery-file discovery.yaml \
			--control-plane \
			--node-name '$$(hostname)' \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log

join-control :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash -u ${ADMIN_SRC_DIR}/scripts/join-control.sh \
		&& ansibash sudo bash join-control.sh ${K8S_NETWORK_DEVICE} kubeadm-config-join.yaml \
			|& tee ${ADMIN_SRC_DIR}/logs/${LOG_PREFIX}.join-control.log

join-control-discovery-file :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
		&& ansibash sudo kubeadm join --discovery-file discovery.yaml --control-plane --certificate-key ${K8S_CERTIFICATE_KEY}

watch : 
	watch kubectl get pod -A -o wide
psk :
	ansibash psk
crictl : crictl-ps crictl-pods crictl-images
crictl-ps crictl-ctnr :
	ansibash sudo crictl ps 
crictl-pods :
	ansibash sudo crictl pods 
crictl-images :
	ansibash sudo crictl images
images :
	kubectl get pod -A -o yaml |yq .items[].spec.containers[].image |sort -u 

teardown : calico-teardown cilium-teardown kuberouter-teardown 
	ANSIBASH_TARGET_LIST="${ADMIN_TARGET_LIST}" \
		&& ansibash -u ${ADMIN_SRC_DIR}/scripts/teardown.sh
	ANSIBASH_TARGET_LIST="${ADMIN_TARGET_LIST}" \
		&& ansibash sudo bash teardown.sh
	tar -caf kube.tgz ~/.kube && rm -rf ~/.kube/*

