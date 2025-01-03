#!/usr/bin/env bash
#####################################################################
# JoinConfiguration creds
# 
# - Run this script on EXITING CONTROL NODE only.
# - This script creates new certificate key, 
#   which invalidates prior key.
# 
# ARGs: K8S_KUBEADM_CONF_INIT
#####################################################################
[[ -r $1 ]] || exit 11

# Certificate Key of Init/Join (ephemeral; default 2hr)
key=${K8S_CERTIFICATE_KEY}
[[ $key ]] || {
    # Create a certificate-key for use on init/join
    # - INVALIDATEs any prior key
    # - config file must NOT contain PKI params
    [[ $(cat $1 |grep certificateKey) ]] && exit 11
    key="$(
        sudo kubeadm init phase upload-certs \
            --upload-certs \
            --config $1 \
            |tail -n1
    )"
}
# Get hash of ca.crt key
hash="$(
    openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
        |openssl rsa -pubin -outform der 2>/dev/null \
        |openssl dgst -sha256 -hex \
        |sed 's/^.* //' \
)"
# Create (another) bootstrap tkn for join : "[a-z0-9]{6}.[a-z0-9]{16}"
# - Ignores any PKI in config
# - Unlike `kubeadm token generate`, "create" pushes the token to control-plane store.
# - Use `sudo kubeadm token delete $tkn` to delete other(s)
tkn=${K8S_BOOTSTRAP_TOKEN}
#tkn="$(sudo kubeadm token create --config $conf || kubeadm token generate)"
[[ $tkn ]] || tkn="$(sudo kubeadm token create --config $1)"

target=Makefile.settings
[[ $tkn ]] || {
    echo |tee $target
    exit 11
}
cat <<-EOH |tee $target
## This file is DYNAMICALLY GENERATED by make recipe 
export K8S_CERTIFICATE_KEY := $key
export K8S_CA_CERT_HASH    := $hash
export K8S_BOOTSTRAP_TOKEN := $tkn
EOH

#kubectl get secrets -n kube-system |grep bootstrap-token
#sudo kubeadm token list -o json |jq -Mr .token,.expires,.usages
#sudo kubeadm token list -o jsonpath='{.token}{"\t"}{.expires}{"\t"}{.usages}{"\n"}'
sudo kubeadm token list |awk '{printf "%25s\t%s\t%s\n",$1,$2,$4}'
