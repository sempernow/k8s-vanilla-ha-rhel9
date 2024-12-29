#!/usr/bin/env bash

[[ -d $ADMIN_SRC_DIR ]] || exit 1

cat ${ADMIN_SRC_DIR}/scripts/${1}.tpl \
    |sed "s,K8S_VERSION,${K8S_VERSION},g" \
    |sed "s,K8S_VERBOSITY,${K8S_VERBOSITY},g" \
    |sed "s,K8S_CLUSTER_NAME,${K8S_CLUSTER_NAME},g" \
    |sed "s,K8S_INIT_NODE,${K8S_INIT_NODE},g" \
    |sed "s,K8S_REGISTRY,${K8S_REGISTRY},g" \
    |sed "s,K8S_CONTROL_PLANE_IP,${K8S_CONTROL_PLANE_IP},g" \
    |sed "s,K8S_CONTROL_PLANE_PORT,${K8S_CONTROL_PLANE_PORT},g" \
    |sed "s,K8S_ENDPOINT,${K8S_ENDPOINT},g" \
    |sed "s,K8S_SERVICE_CIDR,${K8S_SERVICE_CIDR},g" \
    |sed "s,K8S_POD_CIDR,${K8S_POD_CIDR},g" \
    |sed "s,K8S_CRI_SOCKET,${K8S_CRI_SOCKET},g" \
    |sed "s,K8S_CGROUP_DRIVER,${K8S_CGROUP_DRIVER},g" \
    |sed "s,K8S_BOOTSTRAP_TOKEN,${K8S_BOOTSTRAP_TOKEN},g" \
    |sed "s,K8S_CERTIFICATE_KEY,${K8S_CERTIFICATE_KEY},g" \
    |sed "s,K8S_CA_CERT_HASH,${K8S_CA_CERT_HASH},g" \
    |sed "s,K8S_JOIN_KUBECONFIG,${K8S_JOIN_KUBECONFIG},g" \
    |sed "/^ *,/d" |sed "/^\s*$/d" |sed '/^[[:space:]]*#/d' \
    |tee ${ADMIN_SRC_DIR}/scripts/${1}