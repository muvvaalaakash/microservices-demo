#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

CLUSTER_NAME="demo-eks"
REGION="me-central-1"
NODEGROUP_NAME="demo-nodegroup"
NODE_TYPE="t3.large"
NODES=3

echo "---- Creating EKS cluster ----"
eksctl create cluster \
  --name "${CLUSTER_NAME}" \
  --version 1.31 \
  --region "${REGION}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --node-type "${NODE_TYPE}" \
  --nodes "${NODES}" \
  --nodes-min 3 \
  --nodes-max 5 \
  --managed

echo "---- Configuring kubeconfig ----"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo "EKS cluster created and kubeconfig configured."

