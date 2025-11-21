#!/usr/bin/env bash
########################################################################
# Kubernetes CSI : CSI Driver SMB : Install by Helm
# - A CSI driver to access SMB Server on both Linux and Windows nodes.
# - Access any SMB/CIFS share : NetApp, Samba, Windows Server, ... .
# - https://github.com/kubernetes-csi/csi-driver-smb 
########################################################################

# 1. Pull the chart and extract values.yaml
base=https://github.com/kubernetes-csi/csi-driver-smb/raw/refs/heads/master/charts
ver=v1.9.0
chart=csi-driver-smb-$ver.tgz
release=csi-driver-smb
ns=smb
download='' # Don't pull
[[ -f $chart ]] || {
    [[ $download ]] && {
        # Get chart
        wget $base/$ver/$chart
        # Extract values.yaml to PWD
        tar -xaf $chart $release/values.yaml &&
            mv $release/values.yaml . &&
                rm -rf $release ||
                    echo "⚠️ values.yaml is *not* extracted."
    }
}
# 2. Generate the K8s-resource manifests (helm template) from chart (local|remote)
template=helm.template
#helm -n $ns template $chart |tee $template.yaml            # Local chart
helm -n $ns template $base/$ver/$chart |tee $template.yaml  # Remote chart

# 3. Extract a list of all images required to install the chart
rm $template.images
for kind in DaemonSet Deployment StatefulSet; do
    yq '
        select(.kind == "'$kind'") 
        |.spec.template.spec.containers[].image
    ' $template.yaml |tee -a $template.images
done


[[ -f $chart ]] || {
    [[ $download ]] || return
    echo here
}

mountCIFS(){ 
    # For access to Windows share from a RHEL host:
    
    # 1. Install CIFS (SMB) utilities
    sudo dnf -y install cifs-utils
    
    # 2. Mount a Windows SMB share (regardless of its local filesystem format)
    realm=LIME
    server=192.168.11.100
    share=/NTFS002share
    mnt=/mnt/100-ntfs002
    user=CIFS_SVC_ACCT_USERNAME
    pass=CIFS_SVC_ACCT_PASSWORD

    sudo mount -t cifs //$server/$share $mnt \
        -o username=$user,password=$pass,vers=3.0,domain=$realm
}

exit 
####