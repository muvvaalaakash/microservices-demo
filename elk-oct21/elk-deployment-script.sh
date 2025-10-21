#!/bin/bash
set -e

echo "===== Deploying ELK Stack on EKS ====="

# Apply all configurations
kubectl apply -f elk-namespace.yaml
kubectl apply -f storageclass-gp2.yaml
kubectl apply -f elasticsearch-pv.yaml
kubectl apply -f elasticsearch-statefulset.yaml
kubectl apply -f logstash-configmap.yaml
kubectl apply -f logstash-deployment.yaml
kubectl apply -f kibana-deployment.yaml
kubectl apply -f filebeat-serviceaccount.yaml
kubectl apply -f filebeat-configmap.yaml
kubectl apply -f filebeat-daemonset.yaml

# Wait for services to be ready
echo "Waiting for Elasticsearch to be ready..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n elk-stack --timeout=600s

echo "Waiting for Logstash to be ready..."
kubectl wait --for=condition=ready pod -l app=logstash -n elk-stack --timeout=300s

echo "Waiting for Kibana to be ready..."
kubectl wait --for=condition=ready pod -l app=kibana -n elk-stack --timeout=300s

# Deploy Kibana LoadBalancer after everything is ready
kubectl apply -f kibana-loadbalancer.yaml

# Get Kibana LoadBalancer URL
echo "Getting Kibana LoadBalancer URL..."
sleep 30
KIBANA_LB=$(kubectl get svc kibana-loadbalancer -n elk-stack -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Kibana URL: http://$KIBANA_LB"

# Check pod status
echo "===== Pod Status ====="
kubectl get pods -n elk-stack

echo "===== ELK Stack Deployment Completed ====="
