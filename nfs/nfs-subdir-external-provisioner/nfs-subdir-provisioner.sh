#!/usr/bin/env bash
# NFS Subdir External Provisioner
# An NFS client requiring an existing NFS server.
# Dynamically provisions a PersistentVolume (pv) per PersistentVolumeClaim (pvc):
# @ SERVER:MOUNT/${namespace}-${pvcName}-${pvName}
# https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner
type -t helm || exit 111

# Add the provisioner's Helm repo to local helm 
chart=nfs-subdir-external-provisioner
origin=https://kubernetes-sigs.github.io
helm repo add $chart $origin/$chart
helm repo update $chart

# Configure the release
nfs_server_ip=192.168.11.104
nfs_export=/srv/nfs/k8s
release=nfs-provisioner
ns=kube-system
manifest=helm.template.$release.yaml

# Generate the manifest locally
helm template $release $chart/$chart \
    --set nfs.server=$nfs_server_ip \
    --set nfs.path=$nfs_export \
    --set storageClass.name=nfs-client \
    --set storageClass.defaultClass=true \
    --set provisioner=cluster.local/$release \
    --set serviceAccount.name=$release \
    --namespace $ns \
    |tee $manifest

# Same, but declarative (values.yaml) v. imperative (--set *) method 
helm template $release $chart/$chart \
    --values values.yaml \
    --namespace $ns \
    |tee ${manifest/$release/$release@values}

# Install the provisioner
#kubectl apply -f $manifest
# helm install $release $chart/$chart \
#     --set nfs.server=$nfs_server_ip \
#     --set nfs.path=$nfs_export \
#     --set storageClass.name=nfs-client \
#     --set storageClass.defaultClass=true \
#     --set provisioner=cluster.local/$release \
#     --namespace $ns \
#     --wait |tee helm.install.$release.log

# Install by declarative upgrade method
helm upgrade $release $chart/$chart \
    --install \
    --values values.yaml \
    --namespace $ns \
    --wait |tee helm.upgrade.$release.log

# Capture the running manifest 
helm -n $ns get manifest $release |tee helm.get.manifest.$release.yaml

# Inspect the difference (delcared v. running)
# Want no difference
diff helm.get.manifest.$release.yaml $manifest 

# Test dynamic provisioning : Create a claim (pvc) and a pod having a mount that refernces it.
# Want PersistentVolume (pv) and its physical/host store (subdir) to be created dynamically.
base=https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy
pvc=test-claim.yaml
pod=test-pod.yaml 
curl -fsSLO $base/$pvc && echo ok || echo ERR: $?
curl -fsSLO $base/$pod && echo ok || echo ERR: $?
kubectl apply -f $pvc --wait 
kubectl apply -f $pod --wait

# Attempts to modify default UID:GID and/or MODE at StorageClass have no affect. 
# Must declare at NFS-server /etc/exports
# If NFSv3, then config is simple. If NFSv4, then it's more complicated.
# 
# sc=nfs-client
# Patch is forbidden:
#kubectl patch storageclass $sc -p '{"parameters": {"mountOptions": "dir_mode=0770,file_mode=0660"}}'
# So, capture/delete/edit/create:
# kubectl get sc $sc -o yaml |tee sc.$sc.yaml
# vi sc.$sc.yaml 
# kubectl create -f sc.$sc.yaml