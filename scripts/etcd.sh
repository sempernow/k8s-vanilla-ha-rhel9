#!/usr/bin/env bash
##############################################
# etcd : Run as root on any K8s node.
#
# ARGs: METHOD [/path/to/backup/if/snapshot]
##############################################
[[ "$(id -u)" != "0" ]] && {
    echo "❌ ERR : MUST run as root" >&2

    exit 1
}

_etcdctl(){
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        --endpoints=https://127.0.0.1:2379 "$@" 
}
export -f _etcdctl

status(){
    for cmd in 'endpoint status' 'endpoint health --cluster' 'member list'; do
        _etcdctl $cmd --write-out=table
    done
}
defrag(){
    _etcdctl defrag
}
snapshot(){
    [[ $1 ]] && to="$1" || {
        mkdir -p /opt/backup/etcd
        cp --preserve=mode,timestamps etcd.sh /opt/backup/etcd/
        to="/opt/backup/etcd/etcd.snapshot.$(hostname).$(date -Id)"
    }
    _etcdctl snapshot save "$to" || return 11
    [[ -f $to ]] || return 22
    etcdutl snapshot status "$to" |tee "$to.status" || return 33
}
restore(){
    echo "⚠️ Method NOT IMPLEMENTED" >&2

    return 99

    ETCDCTL_API=3 etcdctl snapshot restore /path/to/backup.db \
        --name a3 \
        --initial-cluster 'a1=https://a1:2380,a2=https://a2:2380,a3=https://a3:2380' \
        --initial-cluster-token etcd-cluster-1 \
        --initial-advertise-peer-urls 'https://a3:2380'
}

"$@"
