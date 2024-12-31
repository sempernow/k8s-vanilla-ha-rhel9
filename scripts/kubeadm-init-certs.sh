#!/usr/bin/env bash
#####################################################################
# PKI : kubeadm init phase certs all + ephemeral bootstrap creds
# 
# - Generate PKI once; set fresh creds per.
# - Run this script on the init node *only*.
# - Idempotent
# 
# ARGs: K8S_KUBEADM_CONF_INIT
#####################################################################
[[ -r $1 ]] || exit 11

[[ -d /etc/kubernetes/pki/etcd ]] ||
    sudo kubeadm init phase certs all -v5 --config $1
