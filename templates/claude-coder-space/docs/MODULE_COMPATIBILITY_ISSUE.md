# Module Compatibility Issue Report

**Date:** 2025-11-18
**Issue:** Coder registry modules with agentapi causing parameter conflicts

## Problem

Three Coder registry modules (gemini, copilot, cursor-cli) internally use the `agentapi` submodule which creates `coder_ai_task` resources. These modules have a built-in conflict:

1. They REQUIRE a parameter named exactly "AI Prompt" to exist in the parent template
2. They ALSO internally define their own "AI Prompt" parameter
3. This creates a duplicate parameter name error

**Error Message:**
```
error: template import provision for start: plan resources: coder_parameter names must be unique but "AI Prompt" appears multiple times
```

## Affected Modules

- `gemini` (registry.coder.com/coder-labs/gemini/coder v1.0.0)
- `copilot` (registry.coder.com/coder-labs/copilot/coder v0.2.2)
- `cursor-cli` (registry.coder.com/coder-labs/cursor-cli/coder v0.2.1)

## Workaround Applied

**Removed these 3 problematic modules** to allow template deployment with the remaining 9 working modules.

## Successfully Deployed Modules (9)

### AI Tools (2)
- ✅ **codex** - OpenAI Codex CLI (conditional on API key)
- ✅ **goose** - Goose AI Agent

### Configuration (1)
- ✅ **tmux** - Terminal multiplexer with plugins

### Developer Tools (3)
- ✅ **dotfiles** - Sync personal dotfiles (conditional)
- ✅ **git-clone** - Auto-clone repository (conditional)
- ✅ **github-upload-public-key** - Upload SSH key to GitHub (conditional)

### Optional UI/Tools (3)
- ✅ **filebrowser** - Web-based file manager (toggle)
- ✅ **kasmvnc** - Linux desktop environment (toggle)
- ✅ **archive** - Archive management tool

## Alternative Solutions

If you need these AI tools, consider:

1. **Manual Installation via Bash Script**
   - Keep gemini, copilot, cursor-cli in startup script
   - Already have gemini npm installation commented out

2. **Request Module Fix from Coder**
   - File issue at https://github.com/coder/modules
   - Ask them to fix the agentapi parameter conflict

3. **Fork and Fix Modules**
   - Fork the problematic modules
   - Remove internal "AI Prompt" parameter definition
   - Use your own registry

## Impact

- Template now deploys successfully with 9/12 requested modules
- Lost: Gemini CLI, GitHub Copilot CLI, Cursor CLI integration
- Gained: Working template with other AI tools (Codex, Goose) + all config/dev/UI modules

## Recommendation

Deploy current template (9 modules) and add gemini/copilot/cursor via bash startup script if needed.
