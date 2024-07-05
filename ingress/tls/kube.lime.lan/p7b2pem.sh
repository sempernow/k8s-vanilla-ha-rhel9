#!/usr/bin/env bash
openssl pkcs7 -print_certs -in kube.lime.lan.p7b -out kube.lime.lan.p7b.2..pem
