#!/bin/bash

# Coder Tasks on Kubernetes - Deployment Script
# This script helps deploy the Coder workspace template to a Kubernetes cluster

set -e

echo "🚀 Deploying Coder Tasks on Kubernetes"

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Create namespace and RBAC if not using Terraform
echo "📦 Setting up Kubernetes resources..."
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml

echo "✅ Kubernetes resources created"

# Configure Terraform
echo "🔧 Initializing Terraform..."
terraform init

echo "📋 Please ensure you have:"
echo "   - Configured kubectl to access your Kubernetes cluster"
echo "   - Set up the Kubernetes provider in Terraform (if needed)"
echo "   - Set your Anthropic API key"
echo ""
echo "Then run: terraform plan && terraform apply"

echo "🎉 Setup complete! Ready to deploy with Terraform."