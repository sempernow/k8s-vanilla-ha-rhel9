#!/usr/bin/env bash

# Server
export NFS_SERVER='a0.lime.lan'
export NFS_EXPORT_PATH='/srv/nfs/k8s'

# Client 
repo=https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
chart=csi-driver-nfs
v=4.11.0
release=nfs-csi
ns=kube-system
template=helm.template.yaml
values=values.lime.yaml

prep(){
    # Verify helm CLI else quit
    type -t helm || return 11
    
    # Verify server connectivity else quit
    ping -c1 -w2 "$(nslookup $NFS_SERVER |grep Address |tail -n1 |cut -d' ' -f2)" ||
        return 11
}

repo(){
    # Adds repo metadata to fasciliate all downstream commands
    helm repo add $chart $repo &&
        helm repo update $chart || {
            echo "⚠️  ERR on helm repo add/update : $repo"

            return 22
        }
}

pullChart(){
    # The chart is not required locally unless target environment is air-gap.
    repo &&
        helm pull $chart/$chart --version $v &&
            tar -xaf ${chart}-$v.tgz &&
                cp $chart/values.yaml . &&
                    rm -rf $chart ||
                        return 33
}

pullValues(){
    # Extract the chart's default values.yaml
    curl -fsSL $repo/v$v/${chart}-$v.tgz \
        |tar -xzOf - $chart/values.yaml \
        |tee values.yaml
}

values(){
    # Process the values template file into the values file 
    # used at template, install and uprade.
    envsubst < $values.tpl > $values
    valuesDiff
}

diffValues(){ diff $values values.yaml |grep -- '<'; }

template(){
    # Generate manifest (YAML) file containing all K8s resources 
    # of the chart under this particular set of $values declarations.
    helm template --namespace $ns --values $values $release $chart/$chart \
        |tee $template ||
            return 44
}

install(){
    helm upgrade --install $release $chart/$chart \
        --namespace $ns \
        --version $v \
        --values $values
}

installBySet(){
    helm upgrade --install $release $chart/$chart \
        --namespace $ns \
        --version $v \
        --set externalSnapshotter.enabled=true \
        --set controller.runOnControlPlane=true \
        --set controller.replicas=2
}

manifest(){
    helm -n $ns get manifest $release \
        |tee helm.manifest.yaml
}

diffManifest(){
    # Running v. Declared states
    diff helm.manifest.yaml helm.template.yaml #|grep -- '<'
}

teardown(){
    helm delete $release --namespace $ns
}

"$@"