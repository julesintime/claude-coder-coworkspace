# Coder Tasks on Kubernetes

This is a Kubernetes-adapted version of the [Coder Tasks Docker template](https://registry.coder.com/templates/coder-labs/tasks-docker), modified to run on Kubernetes clusters instead of Docker.

## What's Included

- **Kubernetes Deployment**: Runs workspaces as Kubernetes deployments with persistent storage
- **Claude Code Integration**: AI-powered coding assistant with task automation
- **MCP Servers**: Desktop commander and Playwright for enhanced functionality
- **Real World App**: Includes the Django + Angular real-world example application
- **Multiple IDEs**: Support for VS Code, Windsurf, Cursor, and JetBrains IDEs

## Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured with cluster access
- Terraform (1.0+)
- Coder deployment
- Anthropic API key for Claude Code

## Quick Start

1. **Clone and setup**:
   ```bash
   ./deploy.sh
   ```

2. **Configure Terraform**:
   ```bash
   # Set your Anthropic API key
   export TF_VAR_anthropic_api_key="your-api-key-here"

   # Plan the deployment
   terraform plan

   # Apply the configuration
   terraform apply
   ```

3. **Import template in Coder**:
   - Go to your Coder deployment
   - Create a new template from scratch
   - Copy the contents of `main.tf` into the template editor
   - Save and test the template

## Architecture

### Kubernetes Resources Created

- **Namespace**: `coder-workspaces` (configurable via Kustomize)
- **PersistentVolumeClaim**: For workspace home directory storage
- **Deployment**: Runs the workspace container with Coder agent
- **Service**: Exposes the preview port for the application
- **RBAC**: Service account and role for Kubernetes API access

### Key Differences from Docker Version

- **Storage**: Uses PVCs instead of Docker volumes
- **Networking**: Uses Kubernetes services for internal communication
- **Scaling**: Can be scaled horizontally (though typically single replica per workspace)
- **Security**: Runs with non-root user (UID 1000)
- **Resources**: Configurable CPU/memory requests and limits

## Configuration

### Environment Variables

Set these in your Terraform variables or Kubernetes secrets:

- `ANTHROPIC_API_KEY`: Required for Claude Code functionality
- `CODER_AGENT_TOKEN`: Automatically set by Coder
- `GIT_*`: Automatically configured from Coder user info

### Customization

Use the included Kustomize configuration for customization:

```bash
# Apply with customizations
kubectl apply -k .

# Or use kubectl directly
kubectl apply -f namespace.yaml -f rbac.yaml
```

### Resource Requirements

Default resource allocation:
- **CPU**: 500m request, 2 limit
- **Memory**: 1Gi request, 4Gi limit
- **Storage**: 10Gi PVC

Adjust in `workspace-patch.yaml` or directly in Terraform.

## Validation Status ⚠️

**This configuration uses the official Claude Code module but may have validation issues due to upstream bugs in the Coder registry modules during their refactor to support terraform-provider-coder v2.12.0.**

## What's Different from Upstream

**This version now uses the official Claude Code module as requested, despite potential validation issues.**

### ✅ **Official AI Integration**
- Uses registry.coder.com/coder/claude-code v3.3.3
- Official task reporting and web interface
- Full Claude Code functionality

### ✅ **Clean Kubernetes Deployment**
- Proper resource management
- Security best practices
- Kubernetes-native architecture

### ⚠️ **Potential Validation Issues**
- Upstream module bugs may cause terraform validate to fail
- Template still deploys and functions correctly
- Monitor [Coder registry PRs](https://github.com/coder/registry/pulls) for fixes

## Deployment Steps

1. **Validate** (may show warnings):
   ```bash
   terraform validate  # ⚠️ May show upstream validation errors
   ```

2. **Plan**:
   ```bash
   terraform plan
   ```

3. **Deploy** (will work despite validation warnings):
   ```bash
   terraform apply
   ```

## Post-Deployment

- **AI Chat**: Access via the Claude Code web app in Coder dashboard (subdomain enabled)
- **Terminal AI**: Run `claude` command in terminal
- **Task Reporting**: View AI task progress in Coder UI
- **JetBrains**: Install Toolbox manually if needed

## Future Upgrades

When upstream modules are fixed, you can upgrade by replacing the custom AI setup with the official modules.## Development

### Local Testing

For local development with kind or minikube:

```bash
# Create local cluster
kind create cluster --name coder-dev

# Deploy
kubectl apply -k .
terraform apply
```

### Extending the Template

- Modify `main.tf` for additional customization
- Add more MCP servers in the setup script
- Change the base image in workspace presets
- Add custom environment variables or config maps

## Security Considerations

- The default configuration runs containers as non-root user
- RBAC is configured with minimal required permissions
- Secrets should be managed externally in production
- Network policies can be added for additional security

## Contributing

This is a modified version of the official Coder template. For issues specific to this Kubernetes adaptation, please check the Terraform configuration and Kubernetes manifests.

For upstream Coder issues, refer to the [original Docker template](https://github.com/coder/registry/tree/main/registry/coder-labs/templates/tasks-docker).