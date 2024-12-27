#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#  https://github.com/rancher/local-path-provisioner
# -----------------------------------------------------------------------------
v=v0.0.30
base=https://raw.githubusercontent.com/rancher/local-path-provisioner/$v/deploy
manifest=local-path-storage.yaml
[[ -r $manifest ]] || curl -sSLO $base/$manifest 
[[ -r $manifest ]] && kubectl apply -f $manifest 

exit 
####

# Usage

kubectl create -f $base/master/examples/pvc/pvc.yaml
kubectl create -f $base/master/examples/pod/pod.yaml