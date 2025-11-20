# Backstage Production Implementation Guide
## UI Customization, GitOps Workflows & Production-Ready Catalog

This comprehensive guide addresses three critical aspects of production Backstage deployment:
1. **UI Customization**: Adapting Backstage's Material-UI to your design system (shadcn/Tailwind aesthetic)
2. **GitOps Architecture**: Version control and CI/CD for multi-service configurations
3. **Production Catalog**: Ready-to-use templates, plugins, and best practices

---

## Table of Contents

1. [UI Customization Strategy](#ui-customization-strategy)
2. [GitOps Architecture for Multi-Service Platform](#gitops-architecture-for-multi-service-platform)
3. [Production-Ready Backstage Catalog](#production-ready-backstage-catalog)
4. [Complete Implementation Examples](#complete-implementation-examples)

---

## UI Customization Strategy

### Current State Analysis

**Your Stack**: shadcn/ui + Tailwind CSS (utility-first, modern aesthetic)
**Backstage Stack**: Material-UI v5 + Emotion CSS-in-JS (component-based, Google Material Design)

**Key Challenge**: Backstage does NOT natively support Tailwind CSS or shadcn/ui components.

### Approach Comparison

| Approach | Effort | Outcome | Recommendation |
|----------|--------|---------|----------------|
| **A. Material-UI Theme Override** | Low | Tailwind-inspired MUI theme | ✅ **Start here** |
| **B. Custom Component Library** | High | Full component replacement | ⚠️ Phase 2 |
| **C. Tailwind CSS Injection** | Medium | Hybrid (not recommended) | ❌ Conflicts |
| **D. Fork Backstage** | Very High | Complete control | ❌ Maintenance nightmare |

---

### ✅ Recommended: Material-UI Theme Override

**Strategy**: Create a Backstage theme that mimics shadcn/ui aesthetic using Material-UI theming API.

#### Step 1: Analyze shadcn/ui Design Tokens

shadcn/ui design tokens (from Tailwind config):
```typescript
// shadcn/ui typical config
const shadcnColors = {
  background: 'hsl(0 0% 100%)',
  foreground: 'hsl(222.2 84% 4.9%)',
  primary: 'hsl(222.2 47.4% 11.2%)',
  primaryForeground: 'hsl(210 40% 98%)',
  secondary: 'hsl(210 40% 96.1%)',
  accent: 'hsl(210 40% 96.1%)',
  border: 'hsl(214.3 31.8% 91.4%)',
  radius: '0.5rem'
};

const shadcnFonts = {
  sans: ['Inter', 'system-ui', 'sans-serif'],
  mono: ['JetBrains Mono', 'monospace']
};
```

#### Step 2: Create Backstage Theme with shadcn Aesthetic

**File**: `packages/app/src/theme/shadcnTheme.ts`

```typescript
import {
  createBaseThemeOptions,
  createUnifiedTheme,
  palettes,
  genPageTheme,
  shapes,
} from '@backstage/theme';

// shadcn-inspired color palette
const shadcnPalette = {
  mode: 'light' as const,
  primary: {
    main: 'hsl(222.2, 47.4%, 11.2%)',      // shadcn primary
    light: 'hsl(222.2, 47.4%, 20%)',
    dark: 'hsl(222.2, 47.4%, 5%)',
    contrastText: 'hsl(210, 40%, 98%)',
  },
  secondary: {
    main: 'hsl(210, 40%, 96.1%)',          // shadcn secondary
    light: 'hsl(210, 40%, 98%)',
    dark: 'hsl(210, 40%, 90%)',
    contrastText: 'hsl(222.2, 84%, 4.9%)',
  },
  background: {
    default: 'hsl(0, 0%, 100%)',           // white
    paper: 'hsl(0, 0%, 100%)',
  },
  text: {
    primary: 'hsl(222.2, 84%, 4.9%)',      // shadcn foreground
    secondary: 'hsl(215.4, 16.3%, 46.9%)', // muted foreground
  },
  divider: 'hsl(214.3, 31.8%, 91.4%)',     // shadcn border
  error: {
    main: 'hsl(0, 84.2%, 60.2%)',          // shadcn destructive
  },
  warning: {
    main: 'hsl(38, 92%, 50%)',
  },
  success: {
    main: 'hsl(142.1, 76.2%, 36.3%)',
  },
  info: {
    main: 'hsl(221.2, 83.2%, 53.3%)',
  },
};

// shadcn-inspired typography
const shadcnTypography = {
  fontFamily: [
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ].join(','),
  fontFamilyMonospace: [
    'JetBrains Mono',
    'ui-monospace',
    'SFMono-Regular',
    'Consolas',
    'monospace',
  ].join(','),
  htmlFontSize: 16,
  fontSize: 14,
  h1: {
    fontSize: '2.25rem',       // 36px - shadcn scroll-m-20 text-4xl
    fontWeight: 800,
    lineHeight: 1.2,
    letterSpacing: '-0.02em',
  },
  h2: {
    fontSize: '1.875rem',      // 30px - shadcn text-3xl
    fontWeight: 700,
    lineHeight: 1.3,
    letterSpacing: '-0.01em',
  },
  h3: {
    fontSize: '1.5rem',        // 24px - shadcn text-2xl
    fontWeight: 600,
    lineHeight: 1.4,
  },
  h4: {
    fontSize: '1.25rem',       // 20px - shadcn text-xl
    fontWeight: 600,
    lineHeight: 1.5,
  },
  body1: {
    fontSize: '0.875rem',      // 14px - shadcn text-sm
    lineHeight: 1.6,
  },
  button: {
    textTransform: 'none' as const,  // shadcn buttons are not uppercase
    fontWeight: 500,
  },
};

export const shadcnTheme = createUnifiedTheme({
  ...createBaseThemeOptions({
    palette: shadcnPalette,
    typography: shadcnTypography,
  }),
  fontFamily: shadcnTypography.fontFamily,
  defaultPageTheme: 'home',

  // Component overrides to match shadcn aesthetics
  components: {
    // Buttons - shadcn style
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: '0.375rem',              // shadcn radius
          textTransform: 'none',
          fontWeight: 500,
          padding: '0.5rem 1rem',
          boxShadow: 'none',
          '&:hover': {
            boxShadow: 'none',
          },
        },
        contained: {
          '&:hover': {
            opacity: 0.9,
          },
        },
        outlined: {
          borderWidth: '1px',
          borderColor: 'hsl(214.3, 31.8%, 91.4%)',
          '&:hover': {
            backgroundColor: 'hsl(210, 40%, 96.1%)',
            borderColor: 'hsl(214.3, 31.8%, 91.4%)',
          },
        },
      },
    },

    // Cards - shadcn card style
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: '0.5rem',                // shadcn radius-lg
          border: '1px solid hsl(214.3, 31.8%, 91.4%)',
          boxShadow: 'none',
          backgroundColor: 'hsl(0, 0%, 100%)',
        },
      },
    },

    // Inputs - shadcn input style
    MuiTextField: {
      styleOverrides: {
        root: {
          '& .MuiOutlinedInput-root': {
            borderRadius: '0.375rem',
            '& fieldset': {
              borderColor: 'hsl(214.3, 31.8%, 91.4%)',
            },
            '&:hover fieldset': {
              borderColor: 'hsl(215.4, 16.3%, 46.9%)',
            },
            '&.Mui-focused fieldset': {
              borderWidth: '1px',
              borderColor: 'hsl(222.2, 47.4%, 11.2%)',
            },
          },
        },
      },
    },

    // Tables - shadcn table style
    MuiTable: {
      styleOverrides: {
        root: {
          borderCollapse: 'separate' as const,
          borderSpacing: 0,
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          borderBottom: '1px solid hsl(214.3, 31.8%, 91.4%)',
          padding: '0.75rem 1rem',
        },
        head: {
          fontWeight: 600,
          color: 'hsl(215.4, 16.3%, 46.9%)',
        },
      },
    },

    // Chips/Badges - shadcn badge style
    MuiChip: {
      styleOverrides: {
        root: {
          borderRadius: '9999px',                // full rounded
          fontSize: '0.75rem',
          height: 'auto',
          padding: '0.125rem 0.625rem',
        },
      },
    },

    // Backstage-specific overrides
    BackstageHeader: {
      styleOverrides: {
        header: ({ theme }) => ({
          backgroundImage: 'none',
          backgroundColor: theme.palette.background.default,
          borderBottom: `1px solid ${theme.palette.divider}`,
          boxShadow: 'none',
        }),
      },
    },
    BackstageSidebar: {
      styleOverrides: {
        drawer: {
          backgroundColor: 'hsl(0, 0%, 100%)',
          borderRight: '1px solid hsl(214.3, 31.8%, 91.4%)',
        },
      },
    },
  },

  // Page themes with shadcn colors
  pageTheme: {
    home: genPageTheme({
      colors: ['hsl(222.2, 47.4%, 11.2%)', 'hsl(210, 40%, 96.1%)'],
      shape: shapes.round
    }),
    documentation: genPageTheme({
      colors: ['hsl(142.1, 76.2%, 36.3%)', 'hsl(142.1, 76.2%, 70%)'],
      shape: shapes.wave2,
    }),
    tool: genPageTheme({
      colors: ['hsl(221.2, 83.2%, 53.3%)', 'hsl(221.2, 83.2%, 70%)'],
      shape: shapes.round
    }),
  },
});
```

#### Step 3: Install Custom Fonts

**File**: `packages/app/public/index.html`

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>Backstage</title>

    <!-- shadcn-style fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap"
      rel="stylesheet"
    />
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
```

#### Step 4: Apply Theme in App

**File**: `packages/app/src/App.tsx`

```tsx
import React from 'react';
import { Navigate, Route } from 'react-router-dom';
import { apiDocsPlugin, ApiExplorerPage } from '@backstage/plugin-api-docs';
import { CatalogEntityPage, CatalogIndexPage, catalogPlugin } from '@backstage/plugin-catalog';
import { createApp } from '@backstage/app-defaults';
import { AppRouter, FlatRoutes } from '@backstage/core-app-api';
import { CatalogGraphPage } from '@backstage/plugin-catalog-graph';
import { orgPlugin } from '@backstage/plugin-org';
import { SearchPage } from '@backstage/plugin-search';
import { TechDocsIndexPage, techdocsPlugin, TechDocsReaderPage } from '@backstage/plugin-techdocs';
import { UserSettingsPage } from '@backstage/plugin-user-settings';
import { apis } from './apis';
import { entityPage } from './components/catalog/EntityPage';
import { searchPage } from './components/search/SearchPage';
import { Root } from './components/Root';

import { shadcnTheme } from './theme/shadcnTheme';  // ← Import custom theme
import { UnifiedThemeProvider } from '@backstage/theme';

const app = createApp({
  apis,
  bindRoutes({ bind }) {
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
      viewTechDoc: techdocsPlugin.routes.docRoot,
    });
    bind(apiDocsPlugin.externalRoutes, {
      registerApi: catalogImportPlugin.routes.importPage,
    });
    bind(scaffolderPlugin.externalRoutes, {
      registerComponent: catalogImportPlugin.routes.importPage,
    });
    bind(orgPlugin.externalRoutes, {
      catalogIndex: catalogPlugin.routes.catalogIndex,
    });
  },

  // ✅ Apply shadcn-inspired theme
  themes: [
    {
      id: 'shadcn-light',
      title: 'Shadcn Light',
      variant: 'light',
      Provider: ({ children }) => (
        <UnifiedThemeProvider theme={shadcnTheme} children={children} />
      ),
    },
  ],
});

const routes = (
  <FlatRoutes>
    <Route path="/" element={<Navigate to="catalog" />} />
    <Route path="/catalog" element={<CatalogIndexPage />} />
    <Route path="/catalog/:namespace/:kind/:name" element={<CatalogEntityPage />}>
      {entityPage}
    </Route>
    <Route path="/docs" element={<TechDocsIndexPage />} />
    <Route path="/docs/:namespace/:kind/:name/*" element={<TechDocsReaderPage />} />
    <Route path="/create" element={<ScaffolderPage />} />
    <Route path="/api-docs" element={<ApiExplorerPage />} />
    <Route path="/search" element={<SearchPage />}>
      {searchPage}
    </Route>
    <Route path="/settings" element={<UserSettingsPage />} />
    <Route path="/catalog-graph" element={<CatalogGraphPage />} />
  </FlatRoutes>
);

export default app.createRoot(
  <>
    <Root>{routes}</Root>
  </>,
);
```

#### Result: Backstage with shadcn Aesthetic

**Before**: Material Design look (cards with shadows, uppercase buttons, Roboto font)
**After**: Modern, clean shadcn aesthetic (flat cards, sentence-case buttons, Inter font)

**Limitations**:
- ❌ Still Material-UI components underneath (not native shadcn/ui)
- ❌ Cannot use Tailwind utility classes directly
- ✅ But achieves visual consistency with your existing design system

---

### ⚠️ Phase 2: Custom Component Library (Future)

If you need **true shadcn/ui components** in Backstage (not recommended for MVP):

**Approach**: Create custom Backstage plugins with shadcn/ui components

```typescript
// Example: Custom Card using shadcn/ui
// packages/app/src/components/shadcn/Card.tsx

import * as React from "react"
import { cn } from "@/lib/utils"

const Card = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn(
      "rounded-lg border bg-card text-card-foreground shadow-sm",
      className
    )}
    {...props}
  />
))

// Use in custom Backstage plugin
export const CustomEntityCard = () => {
  return (
    <Card className="p-6">
      <h3 className="text-2xl font-semibold">Entity Information</h3>
      <p className="text-sm text-muted-foreground">Details here</p>
    </Card>
  );
};
```

**Requirements**:
- Install Tailwind CSS in Backstage (complex webpack config)
- Replace all core Backstage components
- Maintain compatibility with Backstage plugin ecosystem
- Significant ongoing maintenance

**Verdict**: Only consider if you have 3+ frontend engineers dedicated to this.

---

## GitOps Architecture for Multi-Service Platform

### Mono-Repo Strategy ⭐ **RECOMMENDED**

**Repository Structure**:

```
platform-infrastructure/
├── .github/
│   └── workflows/
│       ├── backstage-deploy.yml
│       ├── coder-templates-sync.yml
│       ├── claude-config-sync.yml
│       ├── mattermost-deploy.yml
│       └── twenty-deploy.yml
│
├── backstage/
│   ├── catalog/
│   │   ├── org/
│   │   │   ├── groups.yaml
│   │   │   └── users.yaml
│   │   ├── systems/
│   │   └── components/
│   ├── templates/
│   │   ├── formulas/
│   │   │   ├── ml-research/
│   │   │   │   └── template.yaml
│   │   │   ├── fullstack-dev/
│   │   │   └── data-analysis/
│   │   ├── services/
│   │   │   ├── node-service/
│   │   │   ├── python-api/
│   │   │   └── golang-service/
│   │   └── infrastructure/
│   │       ├── terraform-module/
│   │       └── helm-chart/
│   ├── plugins/
│   │   ├── custom-coder/
│   │   ├── custom-mattermost/
│   │   └── custom-twenty/
│   ├── app-config.yaml
│   ├── app-config.production.yaml
│   └── catalog-info.yaml
│
├── coder/
│   ├── templates/
│   │   ├── ml-research/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── README.md
│   │   ├── fullstack-dev/
│   │   ├── data-analysis/
│   │   └── base/
│   ├── modules/
│   │   ├── docker/
│   │   ├── kubernetes/
│   │   └── common/
│   └── coder.tf
│
├── claude-code/
│   ├── skills/
│   │   ├── code-review/
│   │   │   └── SKILL.md
│   │   ├── testing/
│   │   └── documentation/
│   ├── agents/
│   │   ├── deployment/
│   │   │   └── agent.md
│   │   ├── refactoring/
│   │   └── security-scan/
│   ├── hooks/
│   │   ├── pre-commit.json
│   │   ├── post-tool-use.json
│   │   └── user-prompt-submit.json
│   ├── commands/
│   │   ├── deploy/
│   │   └── test/
│   ├── mcp/
│   │   └── servers.json
│   └── settings.json
│
├── mattermost/
│   ├── bots/
│   │   ├── onboarding-bot/
│   │   │   ├── bot.yml
│   │   │   └── README.md
│   │   ├── incident-bot/
│   │   └── devops-bot/
│   ├── plugins/
│   │   ├── github-integration/
│   │   └── custom-commands/
│   └── config/
│       └── config.json
│
├── twenty/
│   ├── objects/
│   │   ├── custom-objects.json
│   │   └── schema.graphql
│   ├── workflows/
│   │   ├── lead-scoring.json
│   │   └── onboarding-automation.json
│   └── settings/
│       └── workspace-config.json
│
├── scripts/
│   ├── sync-coder-templates.sh
│   ├── sync-claude-config.sh
│   ├── sync-backstage-catalog.sh
│   └── validate-all.sh
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── RUNBOOK.md
│   └── ONBOARDING.md
│
└── README.md
```

---

### CI/CD Workflows

#### 1. Backstage Templates Sync

**File**: `.github/workflows/backstage-deploy.yml`

```yaml
name: Backstage Deploy

on:
  push:
    branches: [main]
    paths:
      - 'backstage/**'
  pull_request:
    paths:
      - 'backstage/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate Backstage Templates
        run: |
          cd backstage/templates
          for template in $(find . -name 'template.yaml'); do
            echo "Validating $template"
            # Use Backstage CLI to validate
            npx @backstage/cli validate-template $template
          done

      - name: Validate Catalog Entities
        run: |
          cd backstage/catalog
          for entity in $(find . -name '*.yaml'); do
            echo "Validating $entity"
            # Custom validation script
            node scripts/validate-entity.js $entity
          done

  deploy-staging:
    needs: validate
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Staging Backstage
        env:
          BACKSTAGE_STAGING_URL: ${{ secrets.BACKSTAGE_STAGING_URL }}
          BACKSTAGE_TOKEN: ${{ secrets.BACKSTAGE_STAGING_TOKEN }}
        run: |
          # Sync templates to staging
          ./scripts/sync-backstage-catalog.sh staging

      - name: Comment PR with Staging URL
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.name,
              body: `🚀 Templates deployed to staging: ${process.env.BACKSTAGE_STAGING_URL}/create`
            })

  deploy-production:
    needs: validate
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Production Backstage
        env:
          BACKSTAGE_PROD_URL: ${{ secrets.BACKSTAGE_PROD_URL }}
          BACKSTAGE_TOKEN: ${{ secrets.BACKSTAGE_PROD_TOKEN }}
        run: |
          ./scripts/sync-backstage-catalog.sh production

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Backstage templates deployed to production",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Backstage Deploy* ✅\n\nTemplates updated in production"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

#### 2. Coder Templates Sync

**File**: `.github/workflows/coder-templates-sync.yml`

```yaml
name: Coder Templates Sync

on:
  push:
    branches: [main]
    paths:
      - 'coder/**'
  pull_request:
    paths:
      - 'coder/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0

      - name: Terraform Format Check
        run: |
          cd coder/templates
          terraform fmt -check -recursive

      - name: Terraform Validate
        run: |
          for template in coder/templates/*/; do
            echo "Validating $template"
            cd $template
            terraform init -backend=false
            terraform validate
            cd -
          done

  push-templates:
    needs: validate
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Coder CLI
        run: |
          curl -fsSL https://coder.com/install.sh | sh

      - name: Push Templates to Coder
        env:
          CODER_URL: ${{ secrets.CODER_URL }}
          CODER_SESSION_TOKEN: ${{ secrets.CODER_SESSION_TOKEN }}
        run: |
          cd coder/templates
          for template_dir in */; do
            template_name=$(basename $template_dir)
            echo "Pushing template: $template_name"

            cd $template_dir
            coder templates push $template_name \
              --directory . \
              --yes
            cd ..
          done

      - name: Tag Template Versions
        run: |
          git_sha=$(git rev-parse --short HEAD)
          echo "Templates synced from commit $git_sha"
```

**Sync Script**: `scripts/sync-coder-templates.sh`

```bash
#!/bin/bash
set -e

ENVIRONMENT=${1:-production}
CODER_URL=${CODER_URL:-https://coder.example.com}
TEMPLATES_DIR="coder/templates"

echo "🚀 Syncing Coder templates to $ENVIRONMENT"

# Iterate through template directories
for template_dir in $TEMPLATES_DIR/*/; do
  template_name=$(basename $template_dir)

  echo "📦 Processing template: $template_name"

  # Validate Terraform
  cd $template_dir
  terraform fmt -check
  terraform init -backend=false
  terraform validate

  # Push to Coder
  coder templates push $template_name \
    --directory . \
    --message "GitOps sync from $(git rev-parse --short HEAD)" \
    --yes

  cd -

  echo "✅ $template_name synced successfully"
done

echo "🎉 All Coder templates synced to $ENVIRONMENT"
```

#### 3. Claude Code Configuration Sync

**File**: `.github/workflows/claude-config-sync.yml`

```yaml
name: Claude Code Config Sync

on:
  push:
    branches: [main]
    paths:
      - 'claude-code/**'

jobs:
  sync-config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate Claude Code Configs
        run: |
          # Validate skills structure
          for skill in claude-code/skills/*/SKILL.md; do
            if [ ! -f "$skill" ]; then
              echo "❌ Invalid skill structure: $skill"
              exit 1
            fi
          done

          # Validate agents
          for agent in claude-code/agents/*/agent.md; do
            if [ ! -f "$agent" ]; then
              echo "❌ Invalid agent structure: $agent"
              exit 1
            fi
          done

          # Validate MCP config
          if [ -f claude-code/mcp/servers.json ]; then
            jq empty claude-code/mcp/servers.json
          fi

      - name: Sync to Coder Template .claude Directory
        run: |
          # Copy Claude configs to Coder template
          for template in coder/templates/*/; do
            if [ -d "$template" ]; then
              echo "Syncing Claude config to $template"

              # Create .claude directory in template
              mkdir -p "$template/.claude"

              # Copy skills, agents, hooks
              cp -r claude-code/skills "$template/.claude/"
              cp -r claude-code/agents "$template/.claude/"
              cp -r claude-code/hooks "$template/.claude/"
              cp -r claude-code/commands "$template/.claude/"
              cp claude-code/settings.json "$template/.claude/"

              # Copy MCP config
              if [ -f claude-code/mcp/servers.json ]; then
                cp claude-code/mcp/servers.json "$template/.mcp.json"
              fi
            fi
          done

      - name: Create PR with Updated Coder Templates
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: "chore: sync Claude Code configs to Coder templates"
          title: "🤖 Sync Claude Code Configuration"
          body: |
            Automated PR to sync Claude Code configurations to Coder workspace templates.

            **Changes:**
            - Updated skills in .claude/skills/
            - Updated agents in .claude/agents/
            - Updated MCP servers in .mcp.json
          branch: sync-claude-config
```

**Claude Code Configuration Structure**:

**File**: `claude-code/skills/code-review/SKILL.md`

```markdown
# Code Review Skill

Perform comprehensive code reviews focusing on:
- Code quality and maintainability
- Security vulnerabilities
- Performance optimizations
- Best practices adherence

## Usage

When reviewing code, analyze:
1. Architecture and design patterns
2. Error handling and edge cases
3. Test coverage
4. Documentation completeness

## Auto-activation

This skill should activate when:
- User asks for code review
- PR is opened (via hook)
- Large code changes are made
```

**File**: `claude-code/agents/deployment/agent.md`

```markdown
---
name: deployment
description: Handles deployment workflows and infrastructure operations
---

# Deployment Agent

This agent specializes in:
- CI/CD pipeline management
- Infrastructure deployments
- Rollback procedures
- Deployment validation

## Tools Available
- kubectl (Kubernetes CLI)
- terraform (Infrastructure as Code)
- coder CLI (Workspace management)
- gh (GitHub CLI)

## Workflows

### Deploy to Staging
1. Run tests
2. Build container images
3. Push to registry
4. Apply Kubernetes manifests
5. Verify health checks

### Rollback
1. Identify previous stable version
2. Apply previous manifests
3. Verify rollback success
```

**File**: `claude-code/mcp/servers.json`

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "description": "Library documentation and code examples"
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Structured reasoning and problem-solving"
    },
    "deepwiki": {
      "type": "http",
      "url": "https://mcp.deepwiki.com/mcp",
      "description": "Repository documentation and codebase understanding"
    },
    "coder": {
      "type": "stdio",
      "command": "node",
      "args": ["./mcp-servers/coder-server.js"],
      "env": {
        "CODER_URL": "${CODER_URL}",
        "CODER_TOKEN": "${CODER_TOKEN}"
      },
      "description": "Coder workspace management"
    }
  }
}
```

---

### Version Control Strategy

#### Semantic Versioning for Templates

**Backstage Template Versioning**:

```yaml
# templates/ml-research/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: formula-ml-research
  title: ML Research Workspace
  annotations:
    backstage.io/template-version: "2.1.0"  # ← Semantic version
    backstage.io/changelog: |
      ## 2.1.0 (2024-03-15)
      - Added support for H100 GPUs
      - Updated PyTorch to 2.2.0
      - Fixed JupyterLab extension issues

      ## 2.0.0 (2024-02-01)
      - Breaking: Changed parameter structure
      - Added Coder pre-provisioning
    backstage.io/source-location: url:https://github.com/org/platform-infrastructure/tree/main/backstage/templates/formulas/ml-research
```

**Coder Template Versioning** (via Git tags):

```bash
# Tag Coder template versions
git tag -a coder/ml-research/v1.2.0 -m "ML Research template v1.2.0: Add H100 support"
git push origin coder/ml-research/v1.2.0

# Coder CLI can reference specific versions
coder templates push ml-research \
  --directory ./coder/templates/ml-research \
  --version v1.2.0
```

**Claude Code Config Versioning**:

```json
// claude-code/skills/version-manifest.json
{
  "version": "1.5.0",
  "skills": {
    "code-review": "2.0.0",
    "testing": "1.3.0",
    "documentation": "1.1.0"
  },
  "agents": {
    "deployment": "1.4.0",
    "refactoring": "1.0.0"
  },
  "mcp_servers": {
    "context7": "stable",
    "sequential-thinking": "stable",
    "deepwiki": "stable",
    "coder": "1.0.0"
  }
}
```

---

## Production-Ready Backstage Catalog

### Official Backstage Templates

**Repository**: https://github.com/backstage/software-templates

**Available Templates**:

| Template | Description | Use Case |
|----------|-------------|----------|
| `react-ssr-template` | React Server-Side Rendering app | Web applications |
| `spring-boot-template` | Java Spring Boot microservice | Backend services |
| `go-grpc-template` | Go gRPC service | High-performance APIs |
| `python-fastapi-template` | Python FastAPI service | ML/Data APIs |
| `docs-template` | TechDocs documentation site | Project documentation |
| `react-native-template` | React Native mobile app | Mobile development |

**How to Add**:

```yaml
# backstage/app-config.yaml
catalog:
  locations:
    # Official templates
    - type: url
      target: https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml

    # Your custom templates
    - type: url
      target: https://github.com/org/platform-infrastructure/blob/main/backstage/templates/formulas/ml-research/template.yaml
```

---

### Community Plugins

**Source**: https://github.com/backstage/community-plugins (210+ plugins)

#### Essential Production Plugins

| Plugin | Package | Purpose | Status |
|--------|---------|---------|--------|
| **Coder** | `@coder/backstage-plugin-coder` | Workspace management | ✅ Official |
| **Gitea** | `@backstage/plugin-scaffolder-backend-module-gitea` | Repository scaffolding | ✅ Official |
| **HTTP Request** | `@roadiehq/scaffolder-backend-module-http-request` | Generic API calls | ✅ Roadie |
| **AWS** | `@roadiehq/scaffolder-backend-module-aws` | AWS resource provisioning | ✅ Roadie |
| **Kubernetes** | `@backstage/plugin-kubernetes` | K8s resource view | ✅ Official |
| **ArgoCD** | `@roadiehq/backstage-plugin-argo-cd` | GitOps deployments | ✅ Roadie |
| **Datadog** | `@roadiehq/backstage-plugin-datadog` | Monitoring integration | ✅ Roadie |
| **PagerDuty** | `@pagerduty/backstage-plugin` | Incident management | ✅ Official |
| **GitHub Actions** | `@backstage/plugin-github-actions` | CI/CD visibility | ✅ Official |
| **Cost Insights** | `@backstage/plugin-cost-insights` | Cloud cost tracking | ✅ Official |

**Installation**:

```bash
# Backend plugins
yarn --cwd packages/backend add @coder/backstage-plugin-coder
yarn --cwd packages/backend add @roadiehq/scaffolder-backend-module-http-request
yarn --cwd packages/backend add @roadiehq/scaffolder-backend-module-aws

# Frontend plugins
yarn --cwd packages/app add @backstage/plugin-kubernetes
yarn --cwd packages/app add @roadiehq/backstage-plugin-argo-cd
```

**Backend Registration**:

```typescript
// packages/backend/src/index.ts
import { createBackend } from '@backstage/backend-defaults';

const backend = createBackend();

// Core plugins
backend.add(import('@backstage/plugin-app-backend'));
backend.add(import('@backstage/plugin-catalog-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend'));
backend.add(import('@backstage/plugin-auth-backend'));

// Scaffolder actions
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitea'));
backend.add(import('@roadiehq/scaffolder-backend-module-http-request'));
backend.add(import('@roadiehq/scaffolder-backend-module-aws'));

// Custom actions
backend.add(import('./modules/scaffolder-coder'));
backend.add(import('./modules/scaffolder-mattermost'));
backend.add(import('./modules/scaffolder-twenty'));

backend.start();
```

---

### Roadie Scaffolder Actions Library

**Source**: https://roadie.io/backstage/scaffolder-actions/

**146 Available Actions** organized by category:

#### Infrastructure Actions

| Action | Package | Purpose |
|--------|---------|---------|
| `roadiehq:aws:s3:cp` | `@roadiehq/scaffolder-backend-module-aws` | Copy files to S3 |
| `roadiehq:aws:ecr:create` | Same | Create ECR repository |
| `roadiehq:aws:secrets-manager:create` | Same | Store secrets in AWS |
| `http:backstage:request` | `@roadiehq/scaffolder-backend-module-http-request` | Call any HTTP API |

#### Git/SCM Actions

| Action | Package | Purpose |
|--------|---------|---------|
| `publish:github` | `@backstage/plugin-scaffolder-backend-module-github` | Publish to GitHub |
| `publish:gitlab` | `@backstage/plugin-scaffolder-backend-module-gitlab` | Publish to GitLab |
| `publish:gitea` | `@backstage/plugin-scaffolder-backend-module-gitea` | Publish to Gitea |
| `publish:bitbucket` | `@backstage/plugin-scaffolder-backend-module-bitbucket` | Publish to Bitbucket |

#### Utility Actions

| Action | Package | Purpose |
|--------|---------|---------|
| `roadiehq:utils:fs:parse` | `@roadiehq/scaffolder-backend-module-utils` | Parse JSON/YAML files |
| `roadiehq:utils:jsonata` | Same | Transform JSON data |
| `roadiehq:utils:serialize:yaml` | Same | Convert to YAML |

---

### Production Template Examples

#### 1. Terraform Module Template

**Repository**: `backstage/templates/infrastructure/terraform-module/`

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: terraform-module
  title: Terraform Module
  description: Create a new Terraform module with CI/CD
spec:
  owner: platform-team
  type: infrastructure

  parameters:
    - title: Module Information
      required: [name, provider]
      properties:
        name:
          title: Module Name
          type: string
          pattern: '^terraform-[a-z0-9-]+$'
        provider:
          title: Cloud Provider
          type: string
          enum: [aws, azure, gcp]

  steps:
    - id: fetch
      name: Fetch Skeleton
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          provider: ${{ parameters.provider }}

    - id: publish
      name: Publish to Gitea
      action: publish:gitea
      input:
        repoUrl: gitea.example.com?owner=terraform&repo=${{ parameters.name }}

    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
```

#### 2. Microservice with Full Stack

**Repository**: `backstage/templates/services/fullstack-service/`

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: fullstack-service
  title: Full-Stack Service
  description: Create backend API + frontend + infrastructure
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Service Configuration
      required: [name, language, database]
      properties:
        name:
          title: Service Name
          type: string
        language:
          title: Backend Language
          type: string
          enum: [typescript, python, go]
        database:
          title: Database
          type: string
          enum: [postgresql, mongodb, mysql]
        includeFrontend:
          title: Include Frontend?
          type: boolean
          default: true

  steps:
    # Backend
    - id: fetch-backend
      name: Fetch Backend Template
      action: fetch:template
      input:
        url: ./backend-${{ parameters.language }}
        targetPath: ./backend

    # Frontend (conditional)
    - id: fetch-frontend
      if: ${{ parameters.includeFrontend }}
      name: Fetch Frontend Template
      action: fetch:template
      input:
        url: ./frontend-react
        targetPath: ./frontend

    # Infrastructure
    - id: fetch-infra
      name: Fetch Infrastructure
      action: fetch:template
      input:
        url: ./infrastructure
        targetPath: ./infrastructure

    # Publish
    - id: publish
      name: Publish to Gitea
      action: publish:gitea
      input:
        repoUrl: gitea.example.com?owner=${{ user.entity.metadata.name }}&repo=${{ parameters.name }}

    # Provision Infrastructure
    - id: create-database
      name: Create Database
      action: http:backstage:request
      input:
        method: POST
        path: /api/proxy/aws/rds/create
        body:
          engine: ${{ parameters.database }}
          name: ${{ parameters.name }}-db

    # Create Coder Workspace
    - id: create-workspace
      name: Create Development Workspace
      action: coder:create-workspace
      input:
        user: ${{ user.entity.metadata.name }}
        templateId: fullstack-dev
        workspaceName: ${{ parameters.name }}-dev
        parameters:
          git_repo: ${{ steps.publish.output.remoteUrl }}
          language: ${{ parameters.language }}

    # Register
    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}

  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Development Workspace
        url: ${{ steps['create-workspace'].output.workspaceUrl }}
```

---

## Complete Implementation Examples

### Example 1: Platform Mono-Repo Setup

```bash
# Initialize platform repository
git init platform-infrastructure
cd platform-infrastructure

# Create directory structure
mkdir -p {backstage,coder,claude-code,mattermost,twenty}/{templates,config}
mkdir -p .github/workflows scripts docs

# Add Backstage
cd backstage
npx @backstage/create-app@latest

# Configure Backstage to use mono-repo templates
cat > catalog-info.yaml <<EOF
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: platform-templates
  description: Platform software templates
spec:
  type: file
  targets:
    - ./templates/**/template.yaml
    - ./catalog/**/*.yaml
EOF

# Add to Backstage config
cat >> app-config.yaml <<EOF
catalog:
  locations:
    - type: file
      target: ./catalog-info.yaml
EOF

# Add Coder template
cd ../coder/templates
mkdir ml-research
cd ml-research
cat > main.tf <<EOF
terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
    }
  }
}

# ... Coder template configuration
EOF

# Add Claude Code skills
cd ../../../claude-code/skills
mkdir code-review
echo "# Code Review Skill" > code-review/SKILL.md

# Commit initial structure
git add .
git commit -m "chore: initialize platform infrastructure mono-repo"
git push
```

### Example 2: Complete CI/CD Pipeline

See `.github/workflows/` examples above for:
- Backstage template validation and deployment
- Coder template Terraform validation and push
- Claude Code configuration sync
- Automated versioning and tagging

---

## Summary & Recommendations

### UI Customization
✅ **Use Material-UI theme override** to achieve shadcn aesthetic
- Implement custom theme in `packages/app/src/theme/shadcnTheme.ts`
- Override components to match flat design, proper spacing, modern typography
- **Time**: 1-2 days for initial theme, 1 week for polish

❌ **Avoid** trying to integrate Tailwind CSS directly (high complexity, low ROI)

---

### GitOps Architecture
✅ **Use mono-repo** for all platform configurations
- Single source of truth
- Atomic changes across services
- Easier version correlation
- **Structure**: `/backstage`, `/coder`, `/claude-code`, `/mattermost`, `/twenty`

✅ **Implement CI/CD workflows** for each service
- Validate on PR
- Deploy to staging on merge to dev
- Deploy to production on merge to main
- **Time**: 1 week for initial pipelines

---

### Production Catalog
✅ **Start with official templates** (Backstage + Roadie)
✅ **Add community plugins** as needed (210+ available)
✅ **Build custom actions** for Coder, Mattermost, Twenty (3-4 weeks)

---

## Next Steps

1. **Week 1-2**: Implement shadcn-inspired Backstage theme
2. **Week 3**: Set up mono-repo structure + CI/CD scaffolding
3. **Week 4-6**: Build custom scaffolder actions (Coder, Mattermost, Twenty)
4. **Week 7**: Create formula marketplace templates
5. **Week 8**: End-to-end testing + documentation
6. **Week 9**: Production deployment

**Total Time**: 9 weeks with 2-3 engineers
