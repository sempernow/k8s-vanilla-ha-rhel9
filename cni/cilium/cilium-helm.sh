#!/usr/bin/env bash
APP=cilium

_install(){

    pushd "${BASH_SOURCE%/*}"
    ver=1.16.4
    values=values.yaml

    tar -xaf ${APP}-$ver.tgz &&
        helm upgrade --install -f $values $APP $APP/ &&
            rm -rf $APP

    code=$?
    popd
    return $code
}

_teardown(){
    helm uninstall $APP
}

"$@"
