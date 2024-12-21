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

# Create (another) bootstrap tkn for join : "[a-z0-9]{6}.[a-z0-9]{16}"
# Unlike `kubeadm token generate`, "create" pushes the token to control-plane store.
#tkn="$(sudo kubeadm token create --config $conf || kubeadm token generate)"
tkn="$(sudo kubeadm token create --config $1)"
target=Makefile.settings
[[ $tkn ]] || {
    echo |tee $target
    exit 
}
# Create a key --INVALIDATING PRIOR KEY --for use on init/join
key=$(sudo kubeadm certs certificate-key)
# Get hash of key
hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
        |openssl rsa -pubin -outform der 2>/dev/null \
        |openssl dgst -sha256 -hex \
        |sed 's/^.* //' \
)
cat <<-EOH |tee $target
## This file is DYNAMICALLY GENERATED by make recipe 
export K8S_CERTIFICATE_KEY := $key
export K8S_CA_CERT_HASH    := sha256:$hash
export K8S_BOOTSTRAP_TOKEN := $tkn
EOH
