#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ============================
# Configuration Variables
# ============================
ADMIN_USER="ubuntu"
REPO="https://github.com/Msocial123/microservices-demo.git"
BRANCH="new-elk"
K8S_MANIFEST_DIR="kubernetes-manifests"
REPO_DIR="microservices-demo"

# ============================
# Clone or Update Repository
# ============================
echo "---- Preparing microservices demo repository ----"

if [ -d "${REPO_DIR}" ]; then
    echo "Repository already exists. Pulling latest changes from ${BRANCH}..."
    cd "${REPO_DIR}" || { echo "Directory ${REPO_DIR} not found"; exit 1; }
    git fetch origin "${BRANCH}" || { echo "Git fetch failed"; exit 1; }
    git reset --hard "origin/${BRANCH}" || { echo "Git reset failed"; exit 1; }
else
    echo "Cloning repository from ${BRANCH}..."
    git clone --branch "${BRANCH}" "${REPO}" || { echo "Git clone failed"; exit 1; }
    cd "${REPO_DIR}" || { echo "Directory ${REPO_DIR} not found"; exit 1; }
fi

# ============================
# Apply Kubernetes Manifests
# ============================
if [ -d "${K8S_MANIFEST_DIR}" ]; then
    echo "---- Applying Kubernetes manifests ----"
    kubectl apply -k "${K8S_MANIFEST_DIR}/"
else
    echo "Warning: ${K8S_MANIFEST_DIR} not found; skipping manifests apply"
fi

echo "---- Script completed successfully ----"

