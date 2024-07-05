#!/usr/bin/env bash
[[ $1 ]] || exit 11
[[ ${1,,} =~ 'running' ]] && exit 22

kubectl get pod -A -o wide |grep "$1" |awk '{print $1,$2}' |xargs -n2 /bin/bash -c 'kubectl -n $1 delete pod $2' _
