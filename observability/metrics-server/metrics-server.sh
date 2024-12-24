#!/usr/bin/env bash
# https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/
# https://github.com/kubernetes-sigs/metrics-server

[[ -f components.yaml ]] ||
    curl -sSLO https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# See deploy.metrics-server.yaml : A modified components.yaml
kubectl apply -f deploy.metrics-server.yaml

