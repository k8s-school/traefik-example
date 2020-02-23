#!/bin/bash

# Pre-requisite: set up k8s cluster and set KUBECONFIG

set -euxo pipefail

echo "WARN: run on docker host, not inside kubectl"

DIR=$(cd "$(dirname "$0")"; pwd -P)

kubectl apply -f "$DIR/manifest/crd.yaml
kubectl apply -f "$DIR/manifest/service.yaml
kubectl apply -f "$DIR/manifest/deployments.yaml

sudo kubectl port-forward --address 0.0.0.0 service/traefik 8000:8000 8080:8080 443:4443 -n default

curl -k https://your.domain.com/tls
curl -k http://your.domain.com:8000/notls
