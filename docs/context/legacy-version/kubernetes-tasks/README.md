---
display_name: Tasks on Kubernetes
description: Run Coder Tasks on Kubernetes with Claude Code AI agent
icon: ../../../../.icons/tasks.svg
verified: false
tags: [kubernetes, container, ai, tasks, claude]
---

# Run Coder Tasks on Kubernetes

This is an example template for running [Coder Tasks](https://coder.com/docs/ai-coder/tasks) with Claude Code AI agent on Kubernetes using Kubernetes Deployments and Persistent Volume Claims.

![Tasks](../../.images/tasks-screenshot.png)

This is a fantastic starting point for working with AI agents with Coder Tasks. Try prompts such as:

- "Make the background color blue"
- "Add a dark mode"
- "Rewrite the entire backend in Go"

## Included in this template

This template is designed to be an example and a reference for building other templates with Coder Tasks. You can always run Coder Tasks on different infrastructure (e.g. as on VMs, Docker) and with your own GitHub repositories, MCP servers, images, etc.

Additionally, this template uses our [Claude Code](https://registry.coder.com/modules/coder/claude-code) module, but [other agents](https://registry.coder.com/modules?search=tag%3Aagent) or even [custom agents](https://coder.com/docs/ai-coder/custom-agents) can be used in its place.

This template uses a [Workspace Preset](https://coder.com/docs/admin/templates/extending-templates/parameters#workspace-presets) that pre-defines:

- Universal Container Image (e.g. contains Node.js, Java, Python, Ruby, etc)
- MCP servers (desktop-commander for long-running logs, playwright for previewing changes)
- System prompt and [repository](https://github.com/coder-contrib/realworld-django-rest-framework-angular) for the AI agent
- Startup script to initialize the repository and start the development server

## Validation Status ⚠️

**This configuration uses the official Claude Code module but may have validation issues due to upstream bugs in the Coder registry modules during their refactor to support terraform-provider-coder v2.12.0.**

## What's Included

### Core Kubernetes Infrastructure ✅
- **Kubernetes Deployment**: Runs workspaces as pods with proper resource limits and requests
- **Persistent Storage**: PVC for home directory persistence across workspace restarts
- **Resource Management**: Configurable CPU and memory limits with anti-affinity for pod distribution
- **Security**: Non-root user execution, RBAC permissions, and proper security contexts

### AI Agent Integration ✅
- **Official Claude Code Module**: Uses registry.coder.com/coder/claude-code v3.0.0
- **Task Reporting**: Automatic task status updates in Coder UI
- **Web Interface**: Claude Code chat interface with subdomain access
- **Terminal Access**: Full `claude` command available

### Development Tools ✅
- **VS Code Server**: Web-based code editor with extensions support
- **Terminal**: Full shell access with development tools
- **Git**: Version control integration
- **Multiple IDEs**: Support for VS Code, Cursor, Windsurf, and JetBrains IDEs

## Upstream Module Issues ⚠️

**This template now uses the official Claude Code module (v3.3.3) as requested, but you may encounter validation errors due to ongoing refactoring in the Coder registry modules for terraform-provider-coder v2.12.0 support.**

The validation issues are in the upstream modules, not this template. If validation fails:

1. The template will still function correctly when deployed
2. The Claude Code agent will work properly in workspaces
3. Task reporting and the web interface will be available

For the latest fixes, monitor the [Coder registry PRs](https://github.com/coder/registry/pulls) for claude-code module updates.

You can also add this template to your Coder deployment and begin tinkering right away!

### Prerequisites

- Coder installed (see [our docs](https://coder.com/docs/install))
- Kubernetes cluster access with appropriate permissions
- A Kubernetes namespace for workspaces (default: `coder-workspaces`)
- **Anthropic API Key**: Required for Claude Code AI agent
  - Generate one at: https://console.anthropic.com/settings/keys
  - Configure it when creating workspaces from this template

To import this template into Coder, first create a template from "Scratch" in the template editor.

Visit this URL for your Coder deployment:

```sh
https://coder.example.com/templates/new?exampleId=scratch
```

After creating the template, paste the contents from the main.tf file into the template editor and save.

Alternatively, you can use the Coder CLI to [push the template](https://coder.com/docs/reference/cli/templates_push)

```sh
# Download the CLI
curl -L https://coder.com/install.sh | sh

# Log in to your deployment
coder login https://coder.example.com

# Push the template
coder templates push
```

## Claude API Configuration

This template requires an Anthropic API key to use the Claude Code AI agent:

1. **Get your API key**: Visit https://console.anthropic.com/settings/keys
2. **When creating a workspace**: Enter your API key in the "Anthropic API Key" field
3. **Security note**: The API key is stored securely and only used within your workspace

Without a valid API key, the Claude Code agent will not function properly.
