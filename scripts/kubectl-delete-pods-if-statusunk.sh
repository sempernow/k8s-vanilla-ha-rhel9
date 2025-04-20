#!/usr/bin/env bash

kubectl get pod -A -o wide |grep StatusUnk |cut -d' ' -f1,5 |xargs -n2 /bin/bash -c 'kubectl -n  delete pod ' _
