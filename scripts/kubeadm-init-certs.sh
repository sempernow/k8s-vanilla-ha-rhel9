#!/usr/bin/env bash
#####################################################################
# Certs and related : kubeadm init phase ... 
#  
# - Run this script on ONLY the INIT NODE 
# - Idempotent. 
# 
# ARGs: K8S_INIT_NODE K8S_KUBEADM_CONFIG
#####################################################################

node=$1
conf=${2:-kubeadm-config.yaml}
host=$(hostname)
[[ "${node,,}" == "${host,,}" ]] || return 11

# Generate certs (once)
[[ -d /etc/kubernetes/pki ]] || {
    echo 'Generating NEW cluster PKI @ /etc/kubernetes/pki/'
    sudo kubeadm init phase certs all --config $conf
}

key=$(sudo kubeadm certs certificate-key)
hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
        |openssl rsa -pubin -outform der 2>/dev/null \
        |openssl dgst -sha256 -hex \
        |sed 's/^.* //' \
)
tkn=$(sudo kubeadm token generate)

cat <<-EOH |tee _Makefile.settings
## This file is DYNAMICALLY GENERATED : See ${BASH_SOURCE}
export K8S_CERTIFICATE_KEY ?= $key
export K8S_CA_CERT_HASH    ?= sha256:$hash
export K8S_BOOTSTRAP_TOKEN ?= $tkn
EOH

exit 0 
######
