#!/usr/bin/env bash
#############################################################
# Join this host into cluster as control node declared 
# at JoinConfiguration doc of KUBEADM_CONFIG_PATH (YAML)
#
# ARGs: THIS_NODE_INTERFACE  KUBEADM_CONFIG_PATH
#############################################################
[[ $2 ]] || exit 1

[[ "$(whoami)" == 'root' ]] || exit 11

# Replace 'THIS_NODE_IP', declared in JoinConfiguration, 
# with the actual IP address of this node
ip="$(command ip -4 -brief addr show dev $1 |awk '{print $3}' |cut -d'/' -f1)"
[[ $ip ]] && sed -i "s,THIS_NODE_IP,$ip,g" $2 || exit 22

# Join this host into the cluster as a control node
kubeadm join -v5 --config $2