#!/bin/bash

# Pre-requisite: set up k8s cluster and set KUBECONFIG

set -euxo pipefail

echo "WARN: run on docker host, not inside kubectl"

DIR=$(cd "$(dirname "$0")"; pwd -P)

NODE="kind-worker"
DN="kind"
INGRESS_DN="traefik-ui.$DN"
NS="default"

kubectl apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-ds.yaml
kubectl --namespace=kube-system get pods
kubectl get services --namespace=kube-system

# Ingress to Traefik web ui
kubectl apply -f $DIR/manifest/ui.yaml

# WARN need to be ran on host
NODE_IP=$(kubectl get nodes $NODE -o jsonpath='{ .status.addresses[?(@.type=="InternalIP")].address }')
echo "${NODE_IP} $INGRESS_DN" | sudo tee -a /etc/hosts

kubectl --namespace=kube-system wait --timeout=400s --for=condition=ready pod -l k8s-app=traefik-ingress-lb,name=traefik-ingress-lb

# WARN run on host
# Ingress to traefik-ui is available 
curl http://"$INGRESS_DN"

# TLS support
#
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$INGRESS_DN"
kubectl delete secrets -n kube-system traefik-ui-tls-cert --ignore-not-found=true
kubectl -n kube-system create secret tls traefik-ui-tls-cert --key=tls.key --cert=tls.crt

# use official doc file
kubectl apply -f "$DIR/manifest/tls-ingress.yaml"

# Patch https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-ds.yaml
# add a TLS entrypoint by adding the following args to the container spec:
# --defaultentrypoints=http,https
# --entrypoints=Name:https Address::443 TLS
# --entrypoints=Name:http Address::80
#
# And open hostPort 443
kubectl apply -f "$DIR/manifest/tls-traefik-ds.yaml"
kubectl delete po -n kube-system -l k8s-app=traefik-ingress-lb,name=traefik-ingress-lb


# Password for traefik web ui
#
sudo apt install apache2-utils
htpasswd  -bc ./auth user pass
kubectl delete secret --namespace=kube-system mysecret --ignore-not-found=true
kubectl create secret generic --namespace=kube-system mysecret --from-file auth 
# Patch ingress according to doc: https://docs.traefik.io/user-guide/kubernetes/#creating-the-secret
kubectl apply -f $DIR/manifest/auth-ingress.yaml

# Log in via browser to http://"$INGRESS_DN", and https://"$INGRESS_DN"
# a password is now required

# Name-based routing: https://docs.traefik.io/user-guide/kubernetes/#name-based-routing
#
kubectl apply --namespace="$NS" -f $DIR/manifest/cheese-deployments.yaml
kubectl apply -f $DIR/manifest/cheese-services.yaml
kubectl apply -f $DIR/manifest/cheese-ingress.yaml

echo "${NODE_IP} stilton.$DN cheddar.$DN wensleydale.$DN" | sudo tee -a /etc/hosts

kubectl --namespace="$NS" wait --timeout=400s --for=condition=available deploy --all
# Open in browser
curl http://stilton."$DN"


# Path-based Routing: https://docs.traefik.io/user-guide/kubernetes/#path-based-routing
#
kubectl apply -f $DIR/manifest/cheeses-ingress.yaml

echo "${NODE_IP} cheeses.$DN" | sudo tee -a /etc/hosts

# Open in browser
# WARN: do not forget the final slash
curl http://cheeses."$DN"/stilton/
