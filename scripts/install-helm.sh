#!/usr/bin/env bash
# https://helm.sh/docs/intro/install/ 
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
bash get_helm.sh

exit 
####

# Releases
# https://github.com/helm/helm/releases
tar -xvf helm-v3.17.2-linux-amd64.tar.gz &&
    sudo install linux-amd64/helm /usr/local/bin/