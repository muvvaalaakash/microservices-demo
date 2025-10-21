#!/bin/bash
set -e

echo "===== SETTING UP NGINX INGRESS CONTROLLER ====="

# Step 1: Create namespace
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Add Helm repository
echo "Adding NGINX Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Step 3: Install NGINX Ingress
echo "Installing NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-name"=a645040ad6e0245e3a77ffb3058e4316 \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.service.type=LoadBalancer \
  --atomic --timeout 10m

# Step 4: Wait for deployment
echo "Waiting for NGINX Ingress to be ready..."
sleep 30
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=600s

# Step 5: Display status
echo "===== DEPLOYMENT STATUS ====="
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

echo "===== NGINX INGRESS CONTROLLER READY ====="
