#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

CLUSTER_NAME="demo-eks"
REGION="sa-east-1"
NODEGROUP_NAME="demo-nodegroup"
NODE_TYPE="t3.2xlarge"
NODES=5

echo "---- Creating EKS cluster ----"
eksctl create cluster \
  --name "${CLUSTER_NAME}" \
  --version 1.31 \
  --region "${REGION}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --node-type "${NODE_TYPE}" \
  --nodes "${NODES}" \
  --nodes-min 5 \
  --nodes-max 6 \
  --managed

echo "---- Configuring kubeconfig ----"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo "EKS cluster created and kubeconfig configured."

