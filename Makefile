##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
include Makefile.settings
# … ⋮ ︙ • “” ‘’ – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × ₽ € ¥ £ ¢ ¤ ♻ ⚐ ⚑ ✪ ❤ \ufe0f
# ☢ ☣ ☠ ¦ ¶ § † ‡ ß µ Ø ƒ Δ ☡ ☈ ☧ ☩ ✚ ☨ ☦ ☓ ♰ ♱ ✖  ☘  웃 𝐀𝐏𝐏 🡸 🡺 ➔
# ℹ️ ⚠️ ✅ ⌛ 🚀 🚧 🛠️ 🔧 🔍 🧪 👈 ⚡ ❌ 💡 🔒 📊 📈 🧩 📦 🥇 ✨️ 🔚
##############################################################################
## Environment variable rules:
## - Any TRAILING whitespace KILLS its variable value and may break recipes.
## - ESCAPE only that required by the shell (bash).
## - Environment hierarchy:
##   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
##     - `FOO ?= bar` is overridden by parent setting; `export FOO=new`.
##     - `FOO :=`bar` is NOT overridden by parent setting.
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

export PRJ_ROOT := $(shell pwd)
export LOG_PRE  := make
export UTC      := $(shell date '+%Y-%m-%dT%H.%M.%Z')


##############################################################################
## TLS : Domain's Offline Root CA

export TLS_CN ?= Lime LAN Root CA
export TLS_O  ?= Lime LAN
export TLS_OU ?= lime.lan
export TLS_C  ?= US


##############################################################################
## Registry : registry.k8s.io

#export CNCF_REGISTRY_IMAGE    ?= registry:2.8.3
#export CNCF_REGISTRY_HOST     ?= oci.lime.lan
#export CNCF_REGISTRY_HOST     ?= a0.lime.lan
#export CNCF_REGISTRY_PORT     ?= 5000
#export CNCF_REGISTRY_ENDPOINT ?= ${CNCF_REGISTRY_HOST}:${CNCF_REGISTRY_PORT}
#export CNCF_REGISTRY_STORE    ?= /mnt/${CNCF_REGISTRY_HOST}


##############################################################################
## HAProxy/Keepalived : HA Network Load Balancer (HANLB)
## (See project at github.com/sempernow/halb)

export HALB_DOMAIN       ?= lime.lan
export HALB_FQDN         ?= kube.${HALB_DOMAIN}
export HALB_FQDN_1       ?= a1.${HALB_DOMAIN}
export HALB_FQDN_2       ?= a2.${HALB_DOMAIN}
export HALB_FQDN_3       ?= a3.${HALB_DOMAIN}
export HALB_MASK         ?= 24
export HALB_MASK6        ?= 64
export HALB_DOMAIN_CIDR  ?= 192.168.11.0/${HALB_MASK}
export HALB_DOMAIN_CIDR6 ?= fd00:11::/${HALB_MASK6}
export HALB_VIP          ?= 192.168.11.11
export HALB_VIP6         ?= fd00:11::100
export HALB_CIDR         ?= ${HALB_VIP}/${HALB_MASK}
export HALB_CIDR6        ?= ${HALB_VIP6}/${HALB_MASK6}
export HALB_DEVICE       ?= eth0
export HALB_PORT_STATS   ?= 8404
export HALB_PORT_K8S     ?= 8443
export HALB_PORT_HTTP    ?= 30080
export HALB_PORT_HTTPS   ?= 30443


##############################################################################
## Cluster

## Configurations : https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/
## K8s RELEASEs https://kubernetes.io/releases/
export K8S_CLUSTER_NAME       ?= lime
#export K8S_VERSION            ?= $(shell curl -sSL https://dl.k8s.io/release/stable.txt)
export K8S_VERSION            ?= v1.29.6
#export K8S_VERSION            ?= v1.29.15
#export K8S_VERSION            ?= v1.33.2
export K8S_PROVISIONER        ?= ${ADMIN_USER}
export K8S_PROVISIONER_KEY    ?= ${ADMIN_KEY}
#export K8S_REGISTRY           ?= ${CNCF_REGISTRY_ENDPOINT}
export K8S_REGISTRY           ?= registry.k8s.io
export K8S_VERBOSITY          ?= 5
export K8S_NODE_INIT          ?= a1
export K8S_NODES_CONTROL      ?= ${K8S_NODE_INIT} a2 a3
export K8S_NODES_WORKER       ?=
export K8S_NODES              ?= ${K8S_NODES_CONTROL} ${K8S_NODES_WORKER}
export K8S_NODES_JOIN         ?= $(shell echo ${K8S_NODES_CONTROL} |awk '{for (i=2; i<NF; i++) printf $$i " "; print $$NF}')
export K8S_KUBEADM_CONF_INIT  ?= kubeadm-config-init.yaml
export K8S_KUBEADM_CONF_JOIN  ?= kubeadm-config-join.yaml
export K8S_JOIN_KUBECONFIG    ?= discovery.yaml
#export K8S_CONTROL_PLANE_IP   ?= 192.168.11.101
#export K8S_CONTROL_PLANE_PORT ?= 6443
export K8S_CONTROL_PLANE_IP   ?= ${HALB_VIP}
export K8S_CONTROL_PLANE_PORT ?= ${HALB_PORT_K8S}
export K8S_NETWORK_DEVICE     ?= ${HALB_DEVICE}
export K8S_ENDPOINT           ?= ${K8S_CONTROL_PLANE_IP}:${K8S_CONTROL_PLANE_PORT}
export K8S_FQDN               ?= kube.${HALB_DOMAIN}
## Pod and Service CIDRs : Set to Private Address space (RFC 1918) that is SLAAC-compliant .
export K8S_HOST_CIDR          ?= ${HALB_DOMAIN_CIDR}
export K8S_HOST_CIDR6         ?= ${HALB_DOMAIN_CIDR6}
export K8S_SERVICE_CIDR       ?= 10.96.0.0/12
export K8S_SERVICE_CIDR6      ?= fd00:96::/48
export K8S_POD_CIDR           ?= 10.244.0.0/16
export K8S_POD_CIDR6          ?= fd00:244::/64
export K8S_PEERS              ?= 192.168.11.101 192.168.11.102 192.168.11.103
export K8S_FW_ZONE_EXTERNAL   ?= k8s-external
export K8S_FW_ZONE_INTERNAL   ?= k8s-internal
# @ Cilium eBPF mode
#export K8S_POD_CIDR           ?= 10.0.0.0/8
export K8S_NODE_CIDR_MASK     ?= 24
export K8S_NODE_CIDR6_MASK    ?= 64
export K8S_CRI_SOCKET         ?= unix:///var/run/containerd/containerd.sock
export K8S_CGROUP_DRIVER      ?= systemd
## PKI : See Makefile.settings
export DOMAIN_CA_CERT := ${PRJ_ROOT}/ingress/tls/lime-DC1-CA.cer


##############################################################################
## ansibash

## Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER            ?= $(shell id -un)
export ADMIN_USER            ?= u2
export ADMIN_KEY             ?= ${HOME}/.ssh/vm_lime
export ADMIN_HOST            ?= a0
#export ADMIN_TARGET_LIST     ?= ${K8S_NODES_CONTROL} ${K8S_NODES_WORKER}
export ADMIN_TARGET_LIST     ?= ${K8S_NODES_CONTROL}
export ADMIN_SRC_DIR         ?= $(shell pwd)
#export ADMIN_DST_DIR         ?= ${ADMIN_SRC_DIR}
export ADMIN_DST_DIR         ?= /tmp/$(shell basename "${ADMIN_SRC_DIR}")

export ANSIBASH_TARGET_LIST  ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER         ?= ${ADMIN_USER}
export ADMIN_FW_LOG_SINCE    ?= 15 minute ago


##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Install K8s onto all target hosts : RHEL9 is expected'
	@echo "upgrade      : dnf upgrade all targets"
	@echo "reboot       : Reboot all (K8S_NODES) : ${K8S_NODES}"
	@echo "  -soft      : drain ➔  reboot ➔  uncordon"
	@echo "  -hard      : reboot ${K8S_NODES}"
	@echo "conf         : kernel selinux swap : See scripts/configure-*"
	@echo "  -kernel    : Configure kernel for K8s/CNI/CRI : load modules and set runtime params"
	@echo "  -selinux   : Configure targets' SELinux"
	@echo "  -swap      : Configure targets' swap : Disable all swap devices"
	@echo "installs     : Install K8s and all deps"
	@echo "  -rpms      : Install host tools and K8s dep (conntrack)"
	@echo "  -cni       : Install K8s CNI Pod network providers"
	@echo "  -cri       : Install K8s CRI and all deps, and tools"
	@echo "  -k8s       : Install K8s and CNI plugins"
	@echo "rootca       : Create PKI for a Root CA"
	@echo "============== "
	@echo "fw           : Configure Linux firewall for the Kubernetes cluster"
	@echo "  -k8s       : Configure firewalld and NetworkManager for K8s control and worker nodes"
	@echo "   -external : firewall-cmd --list-all --zone=${K8S_FW_ZONE_EXTERNAL} (zone bound to ${HALB_DEVICE})"
	@echo "   -internal : firewall-cmd --list-all --zone=${K8S_FW_ZONE_INTERNAL} (default zone)"
	@echo "  -calico    : Configure firewalld for Calico CNI"
	@echo "  -list      : firewall-cmd --list-all : both k8s zones : ${K8S_FW_ZONE_EXTERNAL} and ${K8S_FW_ZONE_INTERNAL}"
	@echo "  -get       : firewall-cmd --info-service={} (each service) and --direct --get-all-rules"
	@echo "  -zones     : firewall-cmd : Verify zones : active (${K8S_FW_ZONE_EXTERNAL}) and default (${K8S_FW_ZONE_INTERNAL})"
	@echo "  -log       : Recently DROPped packets : journalctl --since='${ADMIN_FW_LOG_SINCE}' |grep DROP"
	@echo "============== "
	@echo "init         : Create 1st control node of the cluster"
	@echo "  -purge     : Purge Makefile.settings of stale PKI params"
	@echo "  -gen       : Generate ${K8S_KUBEADM_CONF_INIT} from template (.yaml.tpl)"
	@echo "  -push      : Upload ${K8S_KUBEADM_CONF_INIT} to all nodes"
	@echo "  -images    : kubeadm config images pull …"
	@echo "  -pki       : Generate cluster PKI (once)"
	@echo "  -pre       : kubeadm init phase preflight …"
	@echo "  -certs     : kubeadm init phase upload certs …"
	@echo "  -now       : kubeadm init … : at 1st node (${ADMIN_USER}@${K8S_NODE_INIT})"
	@echo "============== "
	@echo "kubeconfig   : Configure the client"
	@echo "============== "
	@echo "cilium       : Install Cilium"
	@echo "calico       : Install Calico"
	@echo "  -status    : kubectl get …"
	@echo "  -teardown  : Teardown Calico"
	@echo "calicoctl    : Reports of calicoctl via K8s plugin : kubectl calico …"
	@echo "kuberouter   : Install Kube Router"
	@echo "  -teardown  : Teardown Kuberoute"
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
	@echo "healthz      : GET /healthz?verbose"
	@echo "version      : GET /version"
	@echo "iperf        : Bandwidth tests of the Cluster (Pod) Network"
	@echo "watch        : kubectl get pods -A -o wide -w"
	@echo "psk          : ps of K8s processes"
	@echo "nodes        : K8s Node(s) status"
	@echo "psrss        : ps sorted by RSS usage"
	@echo "crictl       : containerd status"
	@echo "  -images    : Images in containerd cache"
	@echo "  -pods      : Pods of containerd"
	@echo "  -ps        : Containers of containerd"
	@echo "crictl-ready : Delete all containerd Pods in 'NotReady' status"
	@echo "prune        : Delete all problemed Pods of certain Status values"
	@echo "dump         : kubectl cluster-info dump |grep -i error"
	@echo "etcd         : Certain endpoints"
	@echo "journal      : Recent kubelet logs … --since='${ADMIN_FW_LOG_SINCE}'"
	@echo "============== "
	@echo "ingress-nginx: Ingress NGINX Controller"
	@echo "  -status    : kubectl get "
	@echo "  -up        : Install"
	@echo "  -secret    : Create K8s Secret for default TLS certificate"
	@echo "    -parse   : Parse the TLS certificate of K8s Secret"
	@echo "  -down      : Teardown"
	@echo "  -e2e       : End-to-end HTTP  test : curl -s http://\$$host:\$$nodePort/{foo,bar}/hostname"
	@echo "  -e2e-tls   : End-to-end HTTPS test : curl -s https://e2e.${K8S_FQDN}/{foo,bar}/hostname"
	@echo "============== "
	@echo "metrics      : Install metrics-server, enabling: kubectl top …"
	@echo "dashboard    : Install K8s Dashboard : Web UI for K8s API"
	@echo "trivy        : Install Trivy Operator by Helm"
	@echo "============== "
	@echo "csi-local    : Install local-path-provisioner"
	@echo "csi-nfs      : Install nfs-subdir-external-provisioner"
	@echo "csi-rook-up  : Install Rook Operator / Ceph "
	@echo "csi-rook-down: Teardown Rook Operator / Ceph "
	@echo "============== "
	@echo "efk-apply    : Install EFK stack"
	@echo "efk-delete   : Teardown EFK stack"
	@echo "efk-verify   : GET request to Kibana"
	@echo "loki-install : Install Grafana Loki chart"
	@echo "loki-delete  : Uninstall Grafana Loki chart"
	@echo "============== "
	@echo "prom-install : Install kube-prometheus-stack chart"
	@echo "prom-access  : Forward Grafana port for local access (Remove: pkill kubectl)"
	@echo "prom-delete  : Delete kube-prometheus-stack chart"
	@echo "============== "
	@echo "teardown     : kubeadm reset and cleanup at target node(s)"
	@echo "============== "
	@echo "status       : Print targets' status"
	@echo "sealert      : sealert -l '*'"
	@echo "net          : Interfaces' info"
	@echo "ruleset      : nftables rulesets"
	@echo "iptables     : iptables"
	@echo "podcidr      : PodCIDR and per node"
	@echo "psrss        : Print targets' top memory usage : RSS [MiB]"
	@echo "userrc       : Configure targets' bash shell using latest @ github.com/sempernow/userrc.git"
	@echo "============== "
	@echo "env          : Print the make environment"
	@echo "mode         : Fix folder and file modes of this project"
	@echo "eol          : Fix line endings : Convert all CRLF to LF"
	@echo "html         : Process all markdown (MD) to HTML"
	@echo "commit       : Commit and push this source"

env :
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep K8S_
	@env |grep ADMIN_
	@env |grep DOMAIN_
	@env |grep HALB_

eol :
	find . -type f ! -path '*/.git/*' -exec dos2unix {} \+
mode :
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \;
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \;
#	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \;
tree :
	tree -d |tee tree-d
html :
	find . -type f ! -path './.git/*' -name '*.md' -exec md2html.exe "{}" \;
commit push : html mode
	gc && git push && gl && gs


##############################################################################
## Recipes : Cluster

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	sudo nmap -sn ${HALB_CIDR} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.nmap.${UTC}.log
#	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
#	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.arp-scan.${UTC}.log

status hello :
	@ansibash 'printf "%12s: %s\n" SELinux $$(getenforce) \
	    && printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
	    && printf "%12s: %s\n" containerd $$(systemctl is-active containerd) \
	    && printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
	    && printf "%12s: %s\n" Kernel $$(uname -r) \
	    && printf "%12s:%s\n" uptime "$$(uptime)" \
	'
sealert :
	ansibash 'sudo sealert -l "*" |grep -e == -e "Source Path" -e "Last Seen" |grep -v 2024 |grep -B1 -e == -e "Last Seen"'
net:
	ansibash '\
	    sudo nmcli dev status; \
	    ip -brief addr; \
	  '
ruleset:
	ansibash sudo nft list ruleset
iptables:
	ansibash sudo iptables -L -n -v
psrss :
	ansibash -s scripts/psrss.sh

podcidr :
	kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
	@echo "PodCIDR ${K8S_POD_CIDR}"

# Configure bash shell of target hosts using the declared Git project
userrc :
	ansibash 'git clone https://github.com/sempernow/userrc 2>/dev/null || echo ok'
	ansibash 'pushd userrc && git pull && make sync-user && make user'

reboot : reboot-soft
reboot-hard :
	@echo -e "  ⚠️ : HARD reboot of hosts: ${ADMIN_TARGET_LIST}"
	ansibash sudo reboot
reboot-soft :
	bash make.recipes.sh rebootSoft ${K8S_NODES}
upgrade :
	ansibash 'sudo dnf makecache || echo "⚠️  ERR : $$?"' \
	ansibash 'sudo dnf -y --color=never upgrade || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.upgrade.${UTC}.log

rootca :
	bash make.recipes.sh rootCA

conf-sudoer :
	bash make.recipes.sh sudoer \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-sudoer.${UTC}.log

conf : conf-kernel conf-selinux conf-swap reboot
conf-kernel :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/configure-kernel.sh
	ansibash 'sudo bash configure-kernel.sh || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-kernel.${UTC}.log
conf-selinux :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/configure-selinux.sh
	ansibash 'sudo bash configure-selinux.sh enforcing || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-selinux.${UTC}.log
conf-swap :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/configure-swap.sh
	ansibash 'sudo bash configure-swap.sh || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-swap.${UTC}.log

install installs : install-rpms install-cni install-cri install-k8s
install-rpms:
	ansibash -u ${ADMIN_SRC_DIR}/scripts/install-rpms.sh
	ansibash 'sudo bash install-rpms.sh || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.install-rpms.${UTC}.log
install-cni :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/install-cni.sh \
	ansibash 'sudo bash install-cni.sh eBPF || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.install-cni.${UTC}.log
install-cri :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/install-cri.sh \
	ansibash 'sudo bash install-cri.sh || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.install-cri.${UTC}.log
install-k8s :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/install-k8s.sh
	ansibash 'sudo bash install-k8s.sh ${K8S_VERSION} ${K8S_REGISTRY} || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.install-k8s.${UTC}.log

fw : fw-k8s fw-calico
fw-k8s : fw-k8s-external fw-k8s-internal
fw-k8s-down : fw-k8s-external-down fw-k8s-internal-down
fw-k8s-external :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/firewall-k8s-external.sh
	ansibash 'sudo bash firewall-k8s-external.sh ${HALB_DEVICE} ${K8S_FW_ZONE_EXTERNAL} || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.fw-k8s-external.${UTC}.log
fw-k8s-internal :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/firewall-k8s-internal.sh
	ansibash 'sudo bash firewall-k8s-internal.sh \
	    ${K8S_FW_ZONE_INTERNAL} "${K8S_POD_CIDR}" "${K8S_SERVICE_CIDR}" "${K8S_HOST_CIDR}" || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.fw-k8s-internal.${UTC}.log
fw-calico :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/firewall-calico.sh
	ansibash 'sudo bash firewall-calico.sh ${HALB_DEVICE} ${K8S_FW_ZONE_EXTERNAL} "${K8S_PEERS}" || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-calico.${UTC}.log
fw-k8s-external-down :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/firewall-k8s-external.sh
	ansibash 'sudo bash firewall-k8s-external.sh ${HALB_DEVICE} ${K8S_FW_ZONE_EXTERNAL} x || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-k8s-external-down.${UTC}.log
fw-k8s-internal-down :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/firewall-k8s-internal.sh
	ansibash 'sudo bash firewall-k8s-internal.sh \
	    ${K8S_FW_ZONE_INTERNAL} "${K8S_POD_CIDR}" "${K8S_SERVICE_CIDR}" "${K8S_HOST_CIDR}" x || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-k8s-internal-down.${UTC}.log
fw-list : fw-list-external fw-list-internal
fw-get :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/firewall-get.sh
	ansibash 'sudo bash firewall-get.sh || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-get.${UTC}.log
fw-list-external :
	ansibash 'sudo firewall-cmd --list-all --zone=${K8S_FW_ZONE_EXTERNAL}' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-list-external.log
fw-list-internal :
	ansibash 'sudo firewall-cmd --list-all --zone=${K8S_FW_ZONE_INTERNAL}' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-list-internal.log
fw-zone fw-zones :
	ansibash 'sudo firewall-cmd --get-active-zones'
	ansibash 'sudo firewall-cmd --get-default-zone'
fw-log fw-logs :
	ansibash "sudo journalctl --since='${ADMIN_FW_LOG_SINCE}' |grep DROP;echo All recent DROP logs from \'${ADMIN_FW_LOG_SINCE}\' until $$(date -Is)" \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.firewall-stat.log

init-imperative :
	ssh -t ${ADMIN_USER}@${K8S_NODE_INIT} \
	    sudo kubeadm init --control-plane-endpoint "${K8S_ENDPOINT}" \
	        --kubernetes-version ${K8S_VERSION} \
	        --upload-certs \
	        --pod-network-cidr "${K8S_POD_CIDR}" \
	        --service-cidr "${K8S_SERVICE_CIDR}" \
	        --apiserver-advertise-address ${K8S_CONTROL_PLANE_IP} \
	        --node-name ${K8S_NODE_INIT} \
	        --cri-socket "${K8S_CRI_SOCKET}" \
	        |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.kubeadm.init-imperative.${UTC}.log

# @ init-certs phase : config (K8S_KUBEADM_CONF_INIT) must not have PKI
# @ final init phase : config (K8S_KUBEADM_CONF_INIT) may have PKI, but ours does not.

init : init-purge init-gen init-push init-images init-pki init-pre init-now kubeconfig
init-purge :
	bash make.recipes.sh settings_purge
	rm -f logs/*init*.log logs/*join*.log
init-gen :
	bash make.recipes.sh settings_inject ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_INIT} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-gen.${UTC}.log
init-push :
	ANSIBASH_TARGET_LIST='${K8S_NODES_CONTROL}' \
	    ansibash -u ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_INIT} \
	        |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-push.${UTC}.log
init-images :
	ANSIBASH_TARGET_LIST='${K8S_NODES_CONTROL}' \
	    ansibash sudo kubeadm config images pull -v${K8S_VERBOSITY} \
	        --config ${K8S_KUBEADM_CONF_INIT} \
	        |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-images.${UTC}.log
## Generate cluster PKI (if not exist) : Cleanup old settings
## This K8S_KUBEADM_CONF_INIT must NOT have PKI (key, hash, token)
init-pki :
	scp -p ${ADMIN_SRC_DIR}/scripts/kubeadm-init-pki.sh ${K8S_NODE_INIT}:. \
	    && ssh -t ${ADMIN_USER}@${K8S_NODE_INIT} sudo bash kubeadm-init-pki.sh ${K8S_KUBEADM_CONF_INIT} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-pki.${UTC}.log
init-pre :
	ANSIBASH_TARGET_LIST='${K8S_NODES_CONTROL}' \
	    ansibash sudo kubeadm init phase preflight -v${K8S_VERBOSITY} \
	        --config ${K8S_KUBEADM_CONF_INIT} \
	        |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-pre.${UTC}.log
init-now :
	ssh -t ${ADMIN_USER}@${K8S_NODE_INIT} \
	    sudo kubeadm init -v${K8S_VERBOSITY} \
	        --upload-certs \
	        --config ${K8S_KUBEADM_CONF_INIT} \
	        |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-now.${UTC}.log

static-stop :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/static-rotate.sh
	ansibash sudo bash static-rotate.sh stop
static-start :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/static-rotate.sh
	ansibash sudo bash static-rotate.sh start

kubeconfig :
	bash make.recipes.sh kubeconfig

## init-certs is RUN ONLY IF the (bootstrap) certificate KEY HAS EXPIRED.
## Run prior to running the join-control recipe, only if key has expired.
init-certs :
	scp -p ${ADMIN_SRC_DIR}/scripts/kubeadm-init-certs.sh ${ADMIN_USER}@${K8S_NODE_INIT}:. \
	    && ssh -t ${ADMIN_USER}@${K8S_NODE_INIT} sudo bash kubeadm-init-certs.sh ${K8S_KUBEADM_CONF_INIT} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.init-certs.${UTC}.log
	scp -p ${ADMIN_USER}@${K8S_NODE_INIT}:Makefile.settings Makefile.${K8S_NODE_INIT}.settings
join-control : join-prep join-now
join-prep : join-gen join-push
## K8S_CERTIFICATE_KEY must be set PRIOR TO RUNNING join-gen
join-gen :
	bash make.recipes.sh settings_inject ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_JOIN} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.join-gen.${UTC}.log
join-push :
	ANSIBASH_TARGET_LIST='${K8S_NODES_JOIN}' \
	    ansibash -u ${ADMIN_SRC_DIR}/scripts/join-control.sh
	ANSIBASH_TARGET_LIST='${K8S_NODES_JOIN}' \
	    ansibash -u ${ADMIN_SRC_DIR}/scripts/${K8S_KUBEADM_CONF_JOIN}
	ANSIBASH_TARGET_LIST='${K8S_NODES_JOIN}' \
	    ansibash -u ~/.kube/config discovery.yaml
join-now :
	ANSIBASH_TARGET_LIST='${K8S_NODES_JOIN}' \
	    ansibash sudo bash join-control.sh ${K8S_NETWORK_DEVICE} ${K8S_KUBEADM_CONF_JOIN} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.join-control.${UTC}.log
# Print command to join a node into CONTROL PLANE; same cert key/hash; new token
# join-token :
# 	@sudo kubeadm token list |awk '{printf "%25s\t%s\t%s\n",$$1,$$2,$$4}'
join-command :
	ssh -t ${ADMIN_USER}@${K8S_NODE_INIT} \
	    sudo kubeadm token create --print-join-command \
	        --certificate-key ${K8S_CERTIFICATE_KEY} \
	        |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.print-join-command.${UTC}.log

## _install [replace_kube_proxy|pod_ntwk_only] : Default is replace else pod on fail
kuberouter kuberouter-install :
	bash ${ADMIN_SRC_DIR}/cni/kube-router/kube-router.sh _install replace_kube_proxy \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.kuberouter-install.${UTC}.log
	kubectl get pod -A -o wide -w
kuberouter-teardown :
	bash ${ADMIN_SRC_DIR}/cni/kube-router/kube-router.sh _teardown \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.kuberouter-teardown.${UTC}.log

#cilium : cilium-gen cilium-helm
export cilium_values := values-bpf.yaml
cilium : cilium-gen cilium-cli
cilium-cli :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium.sh install_by_cli \
	    ${cilium_values} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.cilium-cli.${UTC}.log
cilium-gen :
	bash make.recipes.sh settings_inject \
	    ${ADMIN_SRC_DIR}/cni/cilium/${cilium_values} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.cilium-gen.${UTC}.log
cilium-helm :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium.sh install_by_helm \
	    ${cilium_values} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.cilium-helm.${UTC}.log
cilium-teardown :
	bash ${ADMIN_SRC_DIR}/cni/cilium/cilium.sh teardown \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.cilium-teardown.${UTC}.log

calico_manifest := calico.v3.29.3.yaml
calico_operator := custom-resources-bpf-bgp.yaml
calico-pull :
	bash cni/calico/calico-pull.sh
#calico : calico-operator
calico : calico-manifest
calicoctl :
	ansibash sudo /usr/local/bin/calicoctl node status \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log
	kubectl calico get ippool \
	    |tee -a ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log
	kubectl calico ipam check \
	    |tee -a ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log
	kubectl calico ipam show --show-blocks \
	    |tee -a ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log
	kubectl calico ipam show --show-configuration \
	    |tee -a ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log
	kubectl calico ipam show --ip=${K8S_CONTROL_PLANE_IP} \
	    |tee -a ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log
	kubectl get tigerastatuses 2>/dev/null && kubectl get tigerastatuses \
	    |tee -a ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.callico-status.log || echo
calico-restart :
	kubectl -n kube-system rollout restart ds/calico-node
	kubectl -n kube-system rollout status  ds/calico-node
	kubectl -n kube-system rollout restart deploy/calico-kube-controllers
	kubectl -n kube-system rollout status deploy/calico-kube-controllers
calico-status :
	@kubectl get pod,ds,deploy,cm -A |grep -e calico -e NAME |sed 's/NAMESPACE/\nNAMESPACE/'
calico-manifest :
	kubectl apply -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/${calico_manifest} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.calico-manifest.${UTC}.log
calico-operator : calico-operator-gen
	bash ${ADMIN_SRC_DIR}/cni/calico/operator-method/calico-operator.sh apply ${calico_operator}
calico-operator-gen :
	bash make.recipes.sh settings_inject \
	    ${ADMIN_SRC_DIR}/cni/calico/operator-method/${calico_operator} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.calico-operator-gen.${UTC}.log
calico-teardown :
	bash ${ADMIN_SRC_DIR}/cni/calico/operator-method/calico-operator.sh teardown ${calico_operator} || echo
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/calico.yaml || echo
	kubectl delete -f ${ADMIN_SRC_DIR}/cni/calico/manifest-method/crds.yaml || echo

export selector := non-cni
kubeproxy-cleanup :
	kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"${selector}": "true"}}}}}' || echo
	ansibash -u scripts/kube-proxy-cleanup.sh
	ansibash sudo bash kube-proxy-cleanup.sh
kubeproxy-restore :
	kubectl patch ds -n kube-system kube-proxy \
	    --type=json \
	    -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/${selector}"}]'

healthz :
	#kubectl get --raw /healthz?verbose || echo "ERR : $$?"
	curl -fksSIX GET https://${K8S_ENDPOINT}/healthz |grep HTTP || echo "ERR : $$?"
	curl -ksS https://${K8S_FQDN}:${HALB_PORT_K8S}/healthz?verbose || echo "ERR : $$?"
version :
	type jq >/dev/null 2>&1 \
	    && curl -fksS https://${K8S_FQDN}:8443/version |jq . \
	    || curl -fksS https://${K8S_ENDPOINT}/version \
	    || echo "ERR : $$?"

export port := 5551
iperf :
	bash ${ADMIN_SRC_DIR}/observability/metrics/iperf3/k8s-iperf.sh ${port} || echo
watch :
	kubectl get pod -A -o wide -w
nodes node no :
	@kubectl get node && echo
	@type yq >/dev/null 2>&1 \
	    && kubectl get node -o yaml \
	        |yq '.items[]? | [{"name": .metadata.name, "trueConditions": (.status.conditions[] | select(.status == "True")), "nodeInfo": .status.nodeInfo}]' \
	            || echo REQUIREs yq
psk :
	ansibash psk
crictl : crictl-images crictl-ps crictl-pods
crictl-ps crictl-ctnr crictl-container crictl-containers :
	ansibash sudo crictl ps
crictl-pods crictl-pod :
	ansibash sudo crictl pods
crictl-images :
	ansibash sudo crictl images
images :
	kubectl get po -A -o jsonpath='{range .items[*]}{.spec.initContainers[].image}{"\n"}{.spec.containers[*].image}{"\n"}{end}' |sort -u
crictl-ready crictl-pods-ready crictl-pod-ready :
	ansibash 'sudo crictl pods |grep NotReady |cut -d" " -f1 |xargs -n1 sudo crictl stopp'
	ansibash 'sudo crictl pods |grep NotReady |cut -d" " -f1 |xargs -n1 sudo crictl rmp'
prune :
	bash make.recipes.sh prune
#	bash scripts/kubectl-mass-delete-pods.sh StatusUnk
dump :
	kubectl cluster-info dump |grep -i error
journal journald journalctl :
	ansibash "sudo journalctl --no-pager -u kubelet --since='${ADMIN_FW_LOG_SINCE}' |grep -i error"
etcd :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/etcd.sh
	ansibash 'sudo bash etcd.sh status || echo "⚠️  ERR : $$?"' \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.etcd.${UTC}.log

metrics metrics-up :
	bash ${ADMIN_SRC_DIR}/observability/metrics/metrics-server/metrics-server.sh apply
metrics-down:
	bash ${ADMIN_SRC_DIR}/observability/metrics/metrics-server/metrics-server.sh delete
dashboard :
	bash ${ADMIN_SRC_DIR}/observability/metrics/dashboard/dashboard.sh

# k apply -f observability/metrics/dashboard/recommended.yaml
# k -n kubernetes-dashboard create token kubernetes-dashboard
# printf "\n  %s\n" Access @ http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
# k proxy

ingress := ingress/ingress-nginx/ingress-nginx.sh
## Unset HALB unless the Ingress is configured for it.
export HALB ?= yes
ingress-nginx :
	@echo "  Recipes for ingress-nginx-* : up down get values secret secret-parse template manifest diff e2e e2e-tls"
ingress-nginx-up : ingress-nginx-values ingress-nginx-secret
#	bash ${ADMIN_SRC_DIR}/${ingress} upManifest
	bash ${ADMIN_SRC_DIR}/${ingress} upChart
ingress-nginx-get ingress-nginx-status :
	bash ${ADMIN_SRC_DIR}/${ingress} get
ingress-nginx-values :
	bash ${ADMIN_SRC_DIR}/${ingress} values
ingress-nginx-secret :
	bash ${ADMIN_SRC_DIR}/${ingress} secret
ingress-nginx-secret-parse ingress-nginx-parse :
	bash ${ADMIN_SRC_DIR}/${ingress} parse
ingress-nginx-diff :
	bash ${ADMIN_SRC_DIR}/${ingress} diff
ingress-nginx-template :
	bash ${ADMIN_SRC_DIR}/${ingress} template
ingress-nginx-manifest :
	bash ${ADMIN_SRC_DIR}/${ingress} manifest
ingress-nginx-e2e :
	bash ${ADMIN_SRC_DIR}/ingress/ingress-nginx/e2e/test-ingress.sh e2e http https || echo ERR $$?
ingress-nginx-e2e-tls :
	bash ${ADMIN_SRC_DIR}/ingress/ingress-nginx/e2e/test-ingress.sh e2e https || echo ERR $$?
ingress-nginx-e2e-down ingress-nginx-e2e-tls-down ingress-nginx-e2e-teardown :
	bash ${ADMIN_SRC_DIR}/ingress/ingress-nginx/e2e/test-ingress.sh teardown || echo ERR $$?
ingress-nginx-down ingress-nginx-teardown :
	bash ${ADMIN_SRC_DIR}/${ingress} teardown

trivy :
	bash ${ADMIN_SRC_DIR}/security/trivy/trivy-operator-install.sh

csi-nfs :
	pushd csi/nfs/nfs-subdir-external-provisioner \
	    && bash nfs-subdir-provisioner.sh
csi-local :
	bash ${ADMIN_SRC_DIR}/csi/local-path-provisioner/local-path-provisioner.sh
csi-rook-up :
	bash ${ADMIN_SRC_DIR}/csi/rook/rook.sh up
rbd := sdb__VERIFY_THIS__
## Reboot after rook teardown
csi-rook-down :
	bash ${ADMIN_SRC_DIR}/csi/rook/rook.sh down
	ansibash -u ${ADMIN_SRC_DIR}/csi/rook/rook.sh
	ansibash sudo bash ./rook.sh host_teardown
	ansibash 'sudo wipefs --all /dev/${rbd} && sudo dd if=/dev/zero of=/dev/${rbd} bs=1M count=10'

efk := logging/elastic/efk-chatgpt/stack.sh
efk-apply :
	bash ${ADMIN_SRC_DIR}/${efk} apply
efk-forward :
	bash ${ADMIN_SRC_DIR}/${efk} forward
efk-delete :
	bash ${ADMIN_SRC_DIR}/${efk} delete
efk-verify :
	bash ${ADMIN_SRC_DIR}/${efk} verify

loki := logging/loki/stack.sh
loki-install :
	bash ${ADMIN_SRC_DIR}/${loki} upgrade
loki-delete :
	bash ${ADMIN_SRC_DIR}/${loki} uninstall

kps :=observability/metrics/prometheus-grafana/kps/stack.sh
prom-install prom-apply :
	bash ${ADMIN_SRC_DIR}/${kps} install
prom-access :
	bash ${ADMIN_SRC_DIR}/${kps} access
prom-delete prom-uninstall:
	pkill kubectl \
	    && echo "ℹ️ : Killing all kubectl processes" \
	    || echo "ℹ️ : No kubectl processes were running"
	bash ${ADMIN_SRC_DIR}/${kps} delete

#teardown : calico-teardown cilium-teardown kuberouter-teardown
teardown :
	ansibash -u ${ADMIN_SRC_DIR}/scripts/teardown.sh
	ansibash sudo bash teardown.sh
