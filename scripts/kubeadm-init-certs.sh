#!/usr/bin/env bash
#####################################################################
# PKI : kubeadm init phase certs all + ephemeral bootstrap creds
# 
# - Generate PKI once; set fresh creds per.
# - Run this script on the init node *only*.
# - Idempotent
# 
# ARGs: K8S_KUBEADM_CONFIG
#####################################################################

[[ -r $1 ]] || exit 11

# Generate PKI (once) : mTLS certs & keys of control plane
[[ -d /etc/kubernetes/pki/etcd ]] || {
    echo 'Generating NEW cluster PKI @ /etc/kubernetes/pki/'
    sudo kubeadm init phase certs all --config $1
}

target=Makefile.settings
echo |tee $target
