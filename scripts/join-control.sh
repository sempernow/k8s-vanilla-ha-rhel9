#!/usr/bin/env bash
#############################################################
# Join THIS HOST into cluster as control node declared 
# at JoinConfiguration (YAML) at KUBEADM_CONFIG_PATH
#
# ARGs: THIS_NODE_INTERFACE  KUBEADM_CONFIG_PATH
#############################################################
[[ $2 ]] || exit 1

# Must run `kubeadm join` as root 
[[ "$(whoami)" == 'root' ]] || exit 11

# See JoinConfiguration.controlPlane.localAPIEndpoint (set per node)
ip="$(command ip -4 -brief addr show dev $1 |awk '{print $3}' |cut -d'/' -f1)"
[[ $ip ]] && sed -i "s,THIS_NODE_IP,$ip,g" $2 || exit 22

[[ -r $2 ]] || exit 99

cat $2

# Join requires valid (ephemeral) PKI.
kubeadm join -v5 --config $2

