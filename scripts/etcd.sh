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
        "$@" 
}
export -f _etcdctl


status(){
    for cmd in 'endpoint status' 'endpoint health --cluster' 'member list'; do
        _etcdctl --endpoints=https://127.0.0.1:2379 --write-out=table $cmd 
    done
}
defrag(){
    _etcdctl defrag
}
snapshot(){
    ## Source : pod.spec.volumes[].hostPath: /var/lib/etcd
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
    
    # Total restore to a cluster having a single control-node with etcd WIPED beforehand
    db=/tmp/etcd/recovery/etcd.leader.2025-08-11.db
    host=a1
    ip=192.168.11.101
    ETCDCTL_API=3 etcdctl snapshot restore "$db" \
        --name "$host" \
        --data-dir /var/lib/etcd \
        --initial-advertise-peer-urls "https://$ip:2380" \
        --initial-cluster "$host=https://$ip:2380" \
        --initial-cluster-token "etcd-cluster-$host"
}
p99(){
    dir=${1:-/var/lib/etcd}
    file=wal.text
    sudo fio --name=static-etcd-fsync \
        --directory=$dir \
        --size=256m \
        --filename=$file \
        --bs=8k \
        --ioengine=libaio \
        --numjobs=1 \
        --fdatasync=1 \
        --iodepth=1 \
        --rw=write \
        --runtime=120 \
        --time_based=1 \
        --group_reporting=1 \
        --lat_percentiles=1 \
        --percentile_list=99,99.5,99.9 \
        |tee fio.etcd.fsync.p99.log

    sudo rm $dir/$file
}

"$@"

exit

# Confirm cluster has quorum first
# - ERRORS column empty
# - LEADER : 1 true; others false
_etcdctl(){
    sudo etcdctl \
        --cacert /etc/kubernetes/pki/etcd/ca.crt \
        --cert /etc/kubernetes/pki/etcd/server.crt \
        --key /etc/kubernetes/pki/etcd/server.key \
        "$@"
}
export -f _etcdctl 
export eps="https://a1:2379,https://a2:2379,https://a3:2379"
# --endpoints=https://127.0.0.1:2379

_etcdctl --endpoints="$eps" endpoint status -w table

# Verify all endpoints are healthy
_etcdctl --endpoints="$eps" endpoint health -w table

# Verify all voters present (and usually not learners)
_etcdctl --endpoints="$EPS" member list -w table

# IF this node is LEADER, then transfer lead to another
LEADER_EP="https://a1:2379"   # replace with the leader you saw above
TRANSFEREE_ID="1234567890abcdef"  # a healthy follower’s ID

_etcdctl --endpoints="$LEADER_EP" move-leader "$TRANSFEREE_ID"
