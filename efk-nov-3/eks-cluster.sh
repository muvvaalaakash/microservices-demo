#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# === Config (edit if needed) ===
CLUSTER_NAME="demo-clahan-eks"
REGION="ap-southeast-2"
NODEGROUP_NAME="demo-clahan-nodegroup"
NODE_TYPE="t3.medium"
NODES=2
MIN_NODES=2
MAX_NODES=4

# IAM role base name for EBS CSI
EBS_ROLE_BASE="AmazonEKS_EBS_CSI_DriverRole"

log() { echo -e "\n---- $1 ----"; }

# Basic prereq check
command -v eksctl >/dev/null 2>&1 || { echo "eksctl not found in PATH. Install eksctl and retry."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "aws CLI not found in PATH. Install aws CLI and retry."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found in PATH. Install kubectl and retry."; exit 1; }

# === Create EKS cluster (idempotent check) ===
if aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  log "Cluster ${CLUSTER_NAME} already exists in ${REGION} - skipping create"
else
  log "Creating EKS cluster: ${CLUSTER_NAME} in region ${REGION}"
  eksctl create cluster \
    --name "${CLUSTER_NAME}" \
    --version 1.31 \
    --region "${REGION}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --node-type "${NODE_TYPE}" \
    --nodes "${NODES}" \
    --nodes-min "${MIN_NODES}" \
    --nodes-max "${MAX_NODES}" \
    --managed
fi

# === Configure kubeconfig ===
log "Configuring kubeconfig for ${CLUSTER_NAME}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

# === Associate IAM OIDC provider (idempotent) ===
log "Associating IAM OIDC provider with cluster (idempotent)"
eksctl utils associate-iam-oidc-provider \
  --region "${REGION}" \
  --cluster "${CLUSTER_NAME}" \
  --approve || {
    echo "Warning: association command returned non-zero. Check if provider already exists; continuing."
  }

# === Create IAM Role for EBS CSI Driver (avoid collisions) ===
log "Preparing IAM role for EBS CSI Driver"

# Decide role name: use base if not existing, otherwise create a unique name
if aws iam get-role --role-name "${EBS_ROLE_BASE}" >/dev/null 2>&1; then
  ROLE_NAME="${EBS_ROLE_BASE}-$(date +%s)"
  log "Role name ${EBS_ROLE_BASE} already exists; will create role as ${ROLE_NAME}"
else
  ROLE_NAME="${EBS_ROLE_BASE}"
  log "Using role name ${ROLE_NAME}"
fi

log "Creating IAM role for service account (role-only) with name: ${ROLE_NAME}"

set +e
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster "${CLUSTER_NAME}" \
  --role-name "${ROLE_NAME}" \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve
CREATE_STATUS=$?
set -e

if [[ $CREATE_STATUS -ne 0 ]]; then
  echo "ERROR: eksctl failed to create IAM service account / role. Inspect CloudFormation stack and eksctl output."
  echo "CloudFormation stacks (filter for eksctl-${CLUSTER_NAME}):"
  aws cloudformation list-stacks --region "${REGION}" --stack-status-filter CREATE_FAILED ROLLBACK_COMPLETE ROLLBACK_FAILED UPDATE_ROLLBACK_FAILED --query "StackSummaries[?starts_with(StackName, \`eksctl-${CLUSTER_NAME}\`)].StackName" --output text || true
  echo "You can check the failing stack in the CloudFormation console for details."
  exit 1
fi

# === Retrieve Role ARN ===
log "Fetching Role ARN for ${ROLE_NAME}"
ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)
if [[ -z "$ARN" || "$ARN" == "None" ]]; then
  echo "Failed to retrieve role ARN for ${ROLE_NAME}. Exiting."
  exit 1
fi
log "Role ARN: ${ARN}"

# === Install EBS CSI Driver Addon ===
log "Installing AWS EBS CSI Driver Addon using role ARN"
eksctl create addon \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --name aws-ebs-csi-driver \
  --version latest \
  --service-account-role-arn "${ARN}" \
  --force

# Wait a bit and check controller deploy status
log "Waiting for ebs-csi-controller deployment to become ready (timeout 3m)"
set +e
kubectl wait --for=condition=available deployment/ebs-csi-controller -n kube-system --timeout=180s
WAIT_RC=$?
set -e

if [[ $WAIT_RC -ne 0 ]]; then
  echo "ebs-csi-controller deployment not fully available after timeout. Inspect pods and logs:"
  echo "  kubectl get pods -n kube-system | grep ebs"
  echo "  kubectl describe pod -n kube-system <ebs-controller-pod-name>"
  echo "  kubectl logs -n kube-system <ebs-controller-pod-name> -c ebs-plugin"
else
  log "ebs-csi-controller is available."
fi

log "EKS cluster and EBS CSI driver setup complete."

