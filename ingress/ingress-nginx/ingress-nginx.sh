#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Idempotent:
# - Apply ingress-nginx Ingress Controller configured for kind cluster.
# - Apply E2E test of Ingress/App
#
# ARGs: FUNCTION  MANIFEST
# -----------------------------------------------------------------------------
v=4.12.3
chart=ingress-nginx # Folder name on chart archive extract
repo=https://kubernetes.github.io/$chart
localrepo=$chart
release=$chart
ns=$release

values=values.diff.yaml
template=helm.template.yaml
manifest=helm.manifest.yaml

http="${HALB_PORT_HTTP:-31080}"
https="${HALB_PORT_HTTPS:-31443}"
proxy_real_ip_cidr="${HALB_DOMAIN_CIDR}"
tls=default-tls-cert
cn=${K8S_FQDN:-example.local}
crt=../tls/$cn/$cn.crt
key=../tls/$cn/$cn.key

# Add/Update repo
repo(){
    helm repo add $chart $repo &&
    helm repo update $chart ||
        echo "⚠️  ERR on helm repo add/update : $repo"
}
pull(){
    repo 
    helm pull $chart/$chart --version $v
}
values(){
    # Generate the values file (diff) from its template
    cat $values.tpl \
        |sed "s/HALB_PORT_HTTPS/$HALB_PORT_HTTPS/" \
        |sed "s/HALB_PORT_HTTP/$HALB_PORT_HTTP/" \
        |sed "s/NAMESPACE/$ns/" \
        |sed "s/DEFAULT_SSL_CERTIFICATE/$tls/" \
        |sed "s,HALB_DOMAIN_CIDR,$HALB_DOMAIN_CIDR," \
        |tee $values
    
    [[ -f $values ]] || return 1
}
secret(){
    ## Use for manifest method (upManifest) only. 
    ## Do *not* create this Secret if installing by Helm (upChart).
    kubectl create ns $ns ||
        kubectl -n $ns delete secret tls $tls --ignore-not-found
    kubectl create secret tls $tls \
        --namespace=$ns \
        --cert=$crt \
        --key=$key # --dry-run=client -o yaml |tee secret.$tls.yaml
    kubectl -n $ns get secret $tls -o yaml |tee secret.$tls.yaml
}
parse(){
    x509v3='subjectAltName,issuerAltName,basicConstraints,keyUsage,extendedKeyUsage,authorityInfoAccess,subjectKeyIdentifier,authorityKeyIdentifier,crlDistributionPoints,issuingDistributionPoints,policyConstraints,nameConstraints'
    yq '.data.["tls.crt"]' <(kubectl -n $ns get secret $tls -o yaml) \
        |base64 -d \
        |openssl x509 -noout -subject -issuer -startdate -enddate -serial -ext "$x509v3" 
}

helmAction(){
    ## ARGs: template|upgrade|install
    [[ $1 ]] || return 1
    [[ -f $values ]] || return 2
    [[ $1 == 'upgrade' ]] && install='--install'
    helm $1 $release $chart \
        $install \
        --repo $repo \
        --version $v \
        --namespace $ns \
        --create-namespace \
        --values $values

        # --set controller.kind=DaemonSet \
        # --set controller.allowSnippetAnnotations="true" \
        # --set controller.service.externalTrafficPolicy=Local \
        # --set controller.service.type=NodePort \
        # --set controller.service.nodePorts.http="$http" \
        # --set controller.service.nodePorts.https="$https" \
        # --set controller.extraArgs.default-ssl-certificate="$ns/$tls" \
        # --set controller.config.use-proxy-protocol="true" \
        # --set controller.config.enable-real-ip="true" \
        # --set controller.config.forwarded-for-header=X-Forwarded-For \
        # --set controller.config.proxy-real-ip-cidr="$proxy_real_ip_cidr"


    # --set controller.proxySetHeaders.use-proxy-protocol="true" \
    # --set controller.proxySetHeaders.enable-real-ip="true" \
    # --set controller.proxySetHeaders.forwarded-for-header=X-Forwarded-For \
    # --set controller.proxySetHeaders.proxy-real-ip-cidr="$proxy_real_ip_cidr"

    ## BUG @ proxySetHeaders : ConfigMap requires string values, yet ...
    ## Want:
    # enable-real-ip: "true"
    # forwarded-for-header: X-Forwarded-For
    # proxy-real-ip-cidr: 192.168.11.0/24
    # use-proxy-protocol: "true"
    ## Got:
    # enable-real-ip: true
    # forwarded-for-header: X-Forwarded-For
    # proxy-real-ip-cidr: 192.168.11.0/24
    # use-proxy-protocol: true
}
template(){
    helmAction template |tee $template
}
manifest(){
    ## Capture K8s manifest of the running state of this helm release.
    helm -n $ns get manifest $release |tee $manifest
}
diff(){
    for kind in $(yq .kind $template |grep -v -- '---')
    do 
        [[ $kind == 'null' ]] && continue
        echo 🔍  kind: $kind
        command diff <(yq .$kind $template) <(yq .$kind $manifest) \
            |grep -v -- '---' \
            |grep -v 'null'
    done
}
upChart(){
    helmAction upgrade
}
upManifest(){
    ## Manifest *method* of deployment uses helm-generated *template*.
    secret && kubectl -n $ns apply -f $template
}
get(){
    kubectl -n $ns get ds,pod,cm,secret,svc,ep
}
teardown(){
    kubectl config set-context --current --namespace default

    helm uninstall -n $ns $release ||
        kubectl delete -f $template

    kubectl delete ns $ns 2>/dev/null ||
        echo ok
}

pushd ${BASH_SOURCE%/*} 2>/dev/null || push . || exit 
"$@"
popd