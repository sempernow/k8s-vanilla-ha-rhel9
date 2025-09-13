#!/usr/bin/env bash
###################################################################
# Install helm : Releases https://github.com/helm/helm/releases
###################################################################

ok(){
    # Helm : https://github.com/helm/helm/releases
    v=v3.18.6
    platform=linux-amd64
    base=https://get.helm.sh/
    archive=helm-$v-$platform.tar.gz
    
    helm version |grep $v &&
        return 0
    
    curl -fsSLO $base/$archive &&
        tar -xvf $archive &&
            install $platform/helm /usr/local/bin/
}
ok || exit $?
