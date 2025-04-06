##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings

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
## Cluster
export NFS_DOMAIN            ?= lime.lan
export NFS_CIDR              ?= 192.168.11.0/24
export NFS_DC_HOST           ?= dc1
export NFS_SERVER_HOST       ?= a0
export NFS_CLIENT_HOSTS      ?= a1 a2 a3
export NFS_EXPORT_PATH       ?= /mnt/nfs_01

## ansibash 
### Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER          ?= $(shell id -un)
export ADMIN_USER          ?= u2
export ADMIN_KEY           ?= ${HOME}/.ssh/vm_lime
export ADMIN_HOST          ?= a0
export ADMIN_TARGET_LIST   ?= ${NFS_CLIENT_HOSTS} ${NFS_SERVER_HOST}
export ADMIN_SRC_DIR       ?= $(shell pwd)

export ANSIBASH_TARGET_LIST ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER        ?= ${ADMIN_USER}

##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Provision NFS Server/Clients on RHEL9 integrated with AD and Kerberos'
	@echo "env          : Print Makefile environment"
	@echo "mode         : Fix file mode of this source"
	@echo "html         : Process all MD files to HTML"
	@echo "============== "
	@echo "nfs          : Provision NFS Server/Clients on RHEL9 integrated with AD and Kerberos"
	@echo "  -common    : Provision common elements of NFS"
	@echo "  -server    : Provision NFS Server on host ${NFS_SERVER_HOST}"
	@echo "  -client    : Provision NFS Client on host ${NFS_CLIENT_HOSTS}"
	@echo "============== "
	@echo "server       : Show NFS server"
	@echo "client       : Show NFS client"
	@echo "============== "
	@echo "k8s-nfs      : Install nfs-client provisioner"

env : 
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep ADMIN_ 
	@env |grep NFS_ 

perms mode : html
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \;
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \;

html :
	find . -type f ! -path './.git/*' -name '*.md' -exec md2html.exe "{}" \;


##############################################################################
## Recipes : NFS

nfs : nfs-common nfs-server nfs-clients

nfs-common :
	ansibash -u ${PRJ_ROOT}/kerberos/etc.krb5.conf
	ansibash -u ${PRJ_ROOT}/kerberos/etc.sssd.conf
	ansibash -u ${PRJ_ROOT}/etc.chrony.conf
	ansibash 'sudo cp -p etc.chrony.conf /etc/chrony.conf \
	    && sudo chown root:chrony /etc/chrony.conf \
	'
	ansibash 'sudo cp -p etc.krb5.conf /etc/krb5.conf \
	    && sudo chown root:root /etc/krb5.conf \
	'
	ansibash 'sudo cp -p etc.sssd.conf /etc/sssd/sssd.conf \
	    && sudo chown root:root /etc/sssd/sssd.conf \
	    && sudo chmod 600 /etc/sssd/sssd.conf \
	'

nfs-server :
	scp -p ${PRJ_ROOT}/install-nfs-server.sh ${ADMIN_USER}@${ADMIN_HOST}:.
	ansibash sudo systemctl disable --now nfs-server
	ssh ${ADMIN_USER}@${NFS_SERVER_HOST} sudo bash install-nfs-server.sh \
	    ${NFS_EXPORT_PATH} ${NFS_CIDR} ${NFS_DC_HOST}.${NFS_DOMAIN}

nfs-clients nfs-client :
	ANSIBASH_TARGET_LIST="${NFS_CLIENT_HOSTS}" \
		&& ansibash -u ${PRJ_ROOT}/install-nfs-client.sh
	ANSIBASH_TARGET_LIST="${NFS_CLIENT_HOSTS}" \
	    && ansibash sudo systemctl disable --now nfs-client.target
	ANSIBASH_TARGET_LIST="${NFS_CLIENT_HOSTS}" \
	    && ansibash sudo bash install-nfs-client.sh \
	        ${NFS_SERVER_HOST}.${NFS_DOMAIN} ${NFS_EXPORT_PATH} ${NFS_EXPORT_PATH} ${NFS_DC_HOST}.${NFS_DOMAIN}

server :
	ssh ${ADMIN_USER}@${NFS_SERVER_HOST} 'sudo journalctl -eu nfs-server && showmount -e localhost && sudo exportfs -v && klist'

file := $(shell date '+%F_%H.%M.%S')
client :
	ANSIBASH_TARGET_LIST="${NFS_CLIENT_HOSTS}" && ansibash '\
	    df -hT |grep nfs \
		    && mount |grep nfs \
	        && ls -hl /mnt \
	        && ls -hl ${NFS_EXPORT_PATH} \
	        && touch ${NFS_EXPORT_PATH}/${file} \
	        && ls -hl ${NFS_EXPORT_PATH}/${file} \
	        && rm ${NFS_EXPORT_PATH}/${file} \
	'

k8s-nfs :
	bash nfs-subdir-provisioner.sh