#!/usr/bin/env bash
####################################
# etcd : Hit certain endpoints 
####################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠️  ERR : MUST run as root" >&2

    exit 11
}

etcd(){
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        --endpoints=https://127.0.0.1:2379 "$@" 
}
export -f etcd

status(){
    for cmd in 'endpoint status' 'endpoint health --cluster' 'member list';do
        etcd $cmd --write-out=table
    done
}
defrag(){
    etcd defrag
}
snapshot(){
    to="$@"
    [[ -d "${to%/*}" ]] || return 11
    etcd snapshot save "$to" || return 22
}
restore(){
    echo "⚠️  NOT IMPLEMENTED" >&2
    return 
    ETCDCTL_API=3 etcdctl snapshot restore /path/to/backup.db \
        --name a3 \
        --initial-cluster a1=https://a1:2380,a2=https://a2:2380,a3=https://a3:2380 \
        --initial-cluster-token etcd-cluster-1 \
        --initial-advertise-peer-urls https://a3:2380 \
}

"$@"
