#!/usr/bin/env bash
#################################################################
# See recipes of Makefile
#################################################################
vm_ip(){
    # Print IPv4 address of an ssh-configured Host ($1). 
    [[ $1 ]] || return 99
    echo $(cat ~/.ssh/config |grep -A4 -B2 $1 |grep Hostname |head -n 1 |cut -d' ' -f2)
}
settings_inject(){
    [[ -r $1.tpl ]] || return 11
    [[ $(echo "$1" |grep 'join') ]] && {
        [[ ${K8S_CERTIFICATE_KEY} ]] || return 22
    }
    cat $1.tpl \
        |sed "s,K8S_VERSION,${K8S_VERSION/v/},g" \
        |sed "s,K8S_VERBOSITY,${K8S_VERBOSITY},g" \
        |sed "s,K8S_CLUSTER_NAME,${K8S_CLUSTER_NAME},g" \
        |sed "s,K8S_INIT_NODE,${K8S_INIT_NODE},g" \
        |sed "s,K8S_REGISTRY,${K8S_REGISTRY},g" \
        |sed "s,K8S_CONTROL_PLANE_IP,${K8S_CONTROL_PLANE_IP},g" \
        |sed "s,K8S_CONTROL_PLANE_PORT,${K8S_CONTROL_PLANE_PORT},g" \
        |sed "s,K8S_ENDPOINT,${K8S_ENDPOINT},g" \
        |sed "s,K8S_SERVICE_CIDR,${K8S_SERVICE_CIDR},g" \
        |sed "s,K8S_NODE_CIDR6_MASK,${K8S_NODE_CIDR6_MASK},g" \
        |sed "s,K8S_NODE_CIDR_MASK,${K8S_NODE_CIDR_MASK},g" \
        |sed "s,K8S_POD_CIDR6,${K8S_POD_CIDR6},g" \
        |sed "s,K8S_POD_CIDR,${K8S_POD_CIDR},g" \
        |sed "s,K8S_CRI_SOCKET,${K8S_CRI_SOCKET},g" \
        |sed "s,K8S_CGROUP_DRIVER,${K8S_CGROUP_DRIVER},g" \
        |sed "s,K8S_BOOTSTRAP_TOKEN,${K8S_BOOTSTRAP_TOKEN},g" \
        |sed "s,K8S_CERTIFICATE_KEY,${K8S_CERTIFICATE_KEY},g" \
        |sed "s,K8S_CA_CERT_HASH,${K8S_CA_CERT_HASH},g" \
        |sed "s,K8S_JOIN_KUBECONFIG,${K8S_JOIN_KUBECONFIG},g" \
        |sed "/^ *,/d" |sed "/^\s*$/d" |sed '/^[[:space:]]*#/d' \
        |tee $1
}
settings_purge(){
	cat <<-EOH |tee Makefile.settings
	## This file is DYNAMICALLY GENERATED at make recipes
	export K8S_CERTIFICATE_KEY ?=
	export K8S_CA_CERT_HASH    ?=
	export K8S_BOOTSTRAP_TOKEN ?=
	EOH
}
halb(){
    # Function halb generates the configuration for a 2-node 
    # Highly Available Load Balancer (HALB) built of HAProxy and Keepalived.
    # Configuration files, haproxy.cfg (LB) and keepalived-*.conf (HA; node failover),
    # are generated from their respective template file (*.tpl).
    pushd halb || return 111
    # VIP must be static and not assignable by the subnet's DHCP server.
    vip='192.168.0.100' 
    vip6='::ffff:c0a8:64'
    device='eth0' # Network device common to all LB nodes
    # Set FQDN
    lb_1_fqdn='a0.local'
    lb_2_fqdn='a1.local'
    # Get/Set IP address of each LB node from ~/.ssh/config
    lb_1_ipv4=$(vm_ip ${lb_1_fqdn%%.*})
    lb_2_ipv4=$(vm_ip ${lb_2_fqdn%%.*})
    # Smoke test these gotten node-IP values : Abort on fail
    [[ $lb_1_ipv4 ]] || { echo 'ERR : @ lb_1_ipv4';return 22; }
    [[ $lb_2_ipv4 ]] || { echo 'ERR : @ lb_2_ipv4';return 23; }

    target=keepalived-check_apiserver.sh
    cp ${target}.tpl $target
    sed -i "s/SET_VIP/$vip/" $target

    # Generate a password common to all LB nodes
    pass="$(cat /proc/sys/kernel/random/uuid)" 
    
    target=keepalived.conf
    cp ${target}.tpl $target
    sed -i "s/SET_DEVICE/$device/" $target
    sed -i "s/SET_PASS/$pass/" $target
    sed -i "s/SET_VIP/$vip/" $target
    # Keepalived requires a unique configuration file 
    # (keepalived-*.conf) at each HAProxy-LB node on which it runs.
    # These *.conf files are identical except that "priority VAL" 
    # of each SLAVE must be unique and lower than that of MASTER.
    cp $target keepalived-$lb_1_fqdn.conf
    cp $target keepalived-$lb_2_fqdn.conf
    rm $target
    target=keepalived-$lb_2_fqdn.conf
    sed -i "s/state MASTER/state SLAVE/"  $target
    sed -i "s/priority 255/priority 254/" $target

    # Replace pattern "LB_?_FQDN LB_?_IPV4" with declared values.
    target=haproxy.cfg
    cp ${target}.tpl $target
    sed -i "s/LB_1_FQDN[[:space:]]LB_1_IPV4/$lb_1_fqdn $lb_1_ipv4/" $target
    sed -i "s/LB_2_FQDN[[:space:]]LB_2_IPV4/$lb_2_fqdn $lb_2_ipv4/" $target

    chmod +x *.sh

    ls -hlrtgG --time-style=long-iso

    popd
}
kubeconfig(){
    [[ $K8S_INIT_NODE ]] || { echo 'ERR : K8S_INIT_NODE is UNSET'; return; }
    ssh -T ${ADMIN_USER}@${K8S_INIT_NODE} \
        'sudo cp -p /etc/kubernetes/admin.conf . && sudo chown $(id -u):$(id -g) admin.conf'
    mkdir -p ~/.kube

    scp -p $K8S_INIT_NODE:admin.conf ~/.kube/ && {

        target=~/.kube/config
        [[ -f $target ]] &&
            mv $target $target.$(date '+%F.%T' |sed s,:,.,g)

        mv ~/.kube/admin.conf $target
        [[ -d ~/.kube/cache ]] && sudo rm -rf ~/.kube/cache
        chmod 600 ~/.kube/conf*

        kubectl config set-context --current --namespace kube-system
        kubectl get no -o wide &&
            kubectl get po -o wide -A

    } || echo 'ERR : Failed to pull kubeconfig'
}

"$@"