# DevContainer Examples

This directory contains example `.devcontainer/devcontainer.json` configurations that users can place in their project repositories for customization.

## Usage

To use a devcontainer configuration in your project:

1. **Copy the example** to your project root:
   ```bash
   mkdir -p /home/coder/projects/your-project/.devcontainer
   cp devcontainer.json /home/coder/projects/your-project/.devcontainer/
   ```

2. **Customize** the configuration for your needs:
   - Add language-specific features
   - Configure VS Code settings and extensions
   - Add post-create commands
   - Forward additional ports

3. **Restart the workspace** to apply changes (if supported in future versions)

## Current Status

**Note:** The current template version uses the TypeScript devcontainer image directly via Envbox. Full devcontainer.json support (using envbuilder) is planned for future versions.

For now, the TypeScript image already includes:
- Node.js and npm
- TypeScript compiler
- Common development tools
- Git and GitHub CLI (via template installation)

## Example Configuration

The provided `devcontainer.json` includes:
- **Base Image:** TypeScript/Node.js devcontainer
- **Features:**
  - Docker-in-Docker (via Envbox in template)
  - kubectl and Helm
  - GitHub CLI
- **VS Code Extensions:**
  - ESLint and Prettier
  - Docker extension
  - Python support
  - GitHub Copilot (if configured)
- **Port Forwarding:** 3000, 8000, 8080
- **Post-Create Command:** Install TypeScript globally

## Future Enhancement

In future versions, you'll be able to:
1. Place `.devcontainer/devcontainer.json` in your git repository
2. The template will detect it and use envbuilder to build a custom image
3. Your customizations will apply automatically on workspace creation

## Learn More

- [DevContainer Specification](https://containers.dev/)
- [DevContainer Features](https://containers.dev/features)
- [Microsoft DevContainer Images](https://github.com/devcontainers/images)
