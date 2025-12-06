# Backstage Unified Service Provisioning - Detailed Implementation Plan

## Executive Summary

This document provides a production-ready implementation plan for building a unified service provisioning panel using Backstage, with multi-tenant Keycloak SSO integration and automated provisioning across Coder, Gitea, Mattermost, and Twenty CRM.

**Key Decision: Use Backstage with Custom Scaffolder Actions**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Existing vs Custom Components](#existing-vs-custom-components)
3. [Multi-Tenancy & SSO Design](#multi-tenancy--sso-design)
4. [Implementation Phases](#implementation-phases)
5. [Code Structure & Examples](#code-structure--examples)
6. [API Integration Details](#api-integration-details)
7. [Security & RBAC](#security--rbac)
8. [Deployment Strategy](#deployment-strategy)

---

## Architecture Overview

### High-Level System Design

```
┌────────────────────────────────────────────────────────────────┐
│                    User Signs In via Keycloak                  │
│                  (Organization-based SSO)                      │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                      Backstage Frontend                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Software Catalog   │  Software Templates (Scaffolder)   │  │
│  │  - Users/Groups     │  - Unified Provisioning Template   │  │
│  │  - Organizations    │  - Per-service Templates           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                      Backstage Backend                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Auth Module (Keycloak OIDC)                             │  │
│  │  - Sign-in Resolver (org-aware)                          │  │
│  │  - Group/User Sync                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Scaffolder Actions                                       │  │
│  │  ✅ Gitea Action (publish:gitea) - EXISTING              │  │
│  │  ⚠️ Coder Action - CUSTOM (workspace provisioning)       │  │
│  │  ⚠️ Mattermost Action - CUSTOM (user/team creation)      │  │
│  │  ⚠️ Twenty CRM Action - CUSTOM (user/entity creation)    │  │
│  │  ✅ HTTP Request Action - EXISTING (Roadie)              │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────┬──────────┬───────────────┬─────────────────────────┐
│  Coder   │  Gitea   │  Mattermost   │       Twenty CRM        │
│ REST API │ REST API │   REST API    │    REST API/GraphQL     │
└──────────┴──────────┴───────────────┴─────────────────────────┘
```

---

## Existing vs Custom Components

### ✅ Existing Backstage Providers/Plugins

| Component | Package | Status | Notes |
|-----------|---------|--------|-------|
| **Keycloak Auth** | `@backstage/plugin-auth-backend` (OIDC) | ✅ Core | Built-in OIDC provider |
| **Gitea Scaffolder** | `@backstage/plugin-scaffolder-backend-module-gitea` | ✅ Official | Repository creation action |
| **HTTP Request Action** | `@roadiehq/scaffolder-backend-module-http-request` | ✅ Community | Generic REST API calls |
| **Coder Plugin** | `@coder/backstage-plugin-coder` | ⚠️ Partial | UI only, no scaffolder action yet |
| **RBAC Plugin** | `@backstage-community/plugin-rbac-backend` | ✅ Community | Permission management |

### ⚠️ Custom Providers to Build

| Service | Approach | Effort | Priority |
|---------|----------|--------|----------|
| **Coder Workspace** | Custom scaffolder action | Medium | High |
| **Mattermost User/Team** | Custom scaffolder action | Medium | High |
| **Twenty CRM Entity** | Custom scaffolder action | Low | Medium |
| **Unified Provisioning** | Software template orchestrating all actions | Low | High |

---

## Multi-Tenancy & SSO Design

### Organization-Based Multi-Tenancy Model

Backstage's multi-tenancy is achieved through the **Software Catalog** with organization grouping:

```yaml
# Example Catalog Structure
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: acme-corp
  namespace: default
  description: ACME Corporation
spec:
  type: organization
  profile:
    displayName: ACME Corporation
  children: [acme-engineering, acme-sales]
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: acme-engineering
  namespace: default
spec:
  type: team
  parent: acme-corp
  children: []
---
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: jane.doe
  namespace: default
spec:
  profile:
    displayName: Jane Doe
    email: jane.doe@acme.com
  memberOf: [acme-engineering]
```

### Keycloak OIDC Integration

**Backend Module**: `packages/backend/src/modules/auth/keycloak.ts`

```typescript
import { createBackendModule } from '@backstage/backend-plugin-api';
import {
  authProvidersExtensionPoint,
  createOAuthProviderFactory,
} from '@backstage/plugin-auth-node';
import { oidcAuthenticator } from '@backstage/plugin-auth-backend-module-oidc-provider';

export const authModuleKeycloakProvider = createBackendModule({
  pluginId: 'auth',
  moduleId: 'keycloak-oidc',
  register(reg) {
    reg.registerInit({
      deps: {
        providers: authProvidersExtensionPoint,
      },
      async init({ providers }) {
        providers.registerProvider({
          providerId: 'keycloak',
          factory: createOAuthProviderFactory({
            authenticator: oidcAuthenticator,
            signInResolver: async (info, ctx) => {
              const { profile } = info.result;

              // Extract organization from email domain or Keycloak group
              const email = profile.email;
              if (!email) {
                throw new Error('Email is required for sign-in');
              }

              // Get groups from Keycloak token
              const groups = profile.groups || [];

              // Map to Backstage user entity
              // Option 1: Use catalog lookup
              const userEntityRef = await ctx.signInWithCatalogUser({
                filter: {
                  'spec.profile.email': email,
                },
              });

              // Option 2: Dynamic user creation (if not in catalog)
              if (!userEntityRef) {
                const username = email.split('@')[0];
                const domain = email.split('@')[1];

                // Validate organization domain
                const allowedDomains = ['acme.com', 'example.org'];
                if (!allowedDomains.includes(domain)) {
                  throw new Error(`Domain ${domain} not authorized`);
                }

                return ctx.issueToken({
                  claims: {
                    sub: username,
                    ent: groups.map(g => `group:default/${g}`),
                  },
                });
              }

              return userEntityRef;
            },
          }),
        });
      },
    });
  },
});
```

**Configuration**: `app-config.yaml`

```yaml
auth:
  environment: production
  providers:
    keycloak:
      production:
        metadataUrl: ${KEYCLOAK_METADATA_URL} # e.g., https://keycloak.example.com/realms/backstage/.well-known/openid-configuration
        clientId: ${KEYCLOAK_CLIENT_ID}
        clientSecret: ${KEYCLOAK_CLIENT_SECRET}
        prompt: auto
        sessionDuration: { hours: 24 }
        signIn:
          # Built-in resolver (simple case)
          resolvers:
            - resolver: preferredUsernameMatchingUserEntityName

catalog:
  providers:
    keycloakOrg:
      default:
        baseUrl: ${KEYCLOAK_BASE_URL}
        loginRealm: ${KEYCLOAK_REALM}
        realm: ${KEYCLOAK_REALM}
        clientId: ${KEYCLOAK_CLIENT_ID}
        clientSecret: ${KEYCLOAK_CLIENT_SECRET}
```

**Group Sync from Keycloak**: `packages/backend/src/modules/catalog/keycloak-org-provider.ts`

```typescript
import {
  createBackendModule,
  coreServices,
} from '@backstage/backend-plugin-api';
import { catalogProcessingExtensionPoint } from '@backstage/plugin-catalog-node/alpha';
import { KeycloakOrgEntityProvider } from '@backstage/plugin-catalog-backend-module-keycloak';

export const catalogModuleKeycloakOrgProvider = createBackendModule({
  pluginId: 'catalog',
  moduleId: 'keycloak-org-provider',
  register(env) {
    env.registerInit({
      deps: {
        catalog: catalogProcessingExtensionPoint,
        config: coreServices.rootConfig,
        logger: coreServices.logger,
        scheduler: coreServices.scheduler,
      },
      async init({ catalog, config, logger, scheduler }) {
        const provider = KeycloakOrgEntityProvider.fromConfig(config, {
          id: 'production',
          logger,
          schedule: scheduler.createScheduledTaskRunner({
            frequency: { hours: 1 },
            timeout: { minutes: 15 },
          }),
        });

        catalog.addEntityProvider(provider);
      },
    });
  },
});
```

### RBAC for Multi-Tenant Access Control

**Permission Policy**: `packages/backend/src/modules/permission/policy.ts`

```typescript
import { BackstageIdentityResponse } from '@backstage/plugin-auth-node';
import { PolicyDecision, AuthorizeResult } from '@backstage/plugin-permission-common';
import { PermissionPolicy, PolicyQuery } from '@backstage/plugin-permission-node';
import { catalogEntityCreatePermission } from '@backstage/plugin-catalog-common/alpha';

export class MultiTenantPermissionPolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: BackstageIdentityResponse,
  ): Promise<PolicyDecision> {
    // Get user's organization from entity refs
    const userOrgs = user?.identity.ownershipEntityRefs.filter(ref =>
      ref.startsWith('group:')
    ) || [];

    // Restrict workspace creation to organization members
    if (request.permission.name === 'scaffolder.task.create') {
      // Check if user belongs to an approved organization
      if (userOrgs.length === 0) {
        return { result: AuthorizeResult.DENY };
      }
      return { result: AuthorizeResult.ALLOW };
    }

    // Default allow for authenticated users
    return { result: AuthorizeResult.ALLOW };
  }
}
```

---

## Implementation Phases

### Phase 1: Backstage Foundation (Weeks 1-2)

**Objectives**:
- Deploy Backstage with PostgreSQL backend
- Configure Keycloak OIDC authentication
- Set up organization/group sync from Keycloak
- Configure RBAC policies

**Deliverables**:
```bash
# Directory structure
packages/
├── backend/
│   ├── src/
│   │   ├── index.ts                          # Backend entry point
│   │   └── modules/
│   │       ├── auth/
│   │       │   └── keycloak.ts              # Keycloak auth module
│   │       ├── catalog/
│   │       │   └── keycloak-org-provider.ts # Group sync
│   │       └── permission/
│   │           └── policy.ts                # RBAC policy
│   └── package.json
└── app/
    └── src/
        └── App.tsx                           # Frontend with auth
```

**Commands**:
```bash
# Create Backstage app
npx @backstage/create-app@latest

# Add dependencies
yarn --cwd packages/backend add @backstage/plugin-auth-backend-module-oidc-provider
yarn --cwd packages/backend add @backstage/plugin-catalog-backend-module-keycloak
yarn --cwd packages/backend add @backstage-community/plugin-rbac-backend

# Register modules in backend/src/index.ts
backend.add(import('./modules/auth/keycloak'));
backend.add(import('./modules/catalog/keycloak-org-provider'));
backend.add(import('@backstage-community/plugin-rbac-backend'));
```

### Phase 2: Gitea Integration (Week 3)

**Objectives**:
- Install official Gitea scaffolder module
- Create test template for repository creation
- Validate user/organization mapping

**Deliverables**:
```yaml
# templates/gitea-repo/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: create-gitea-repo
  title: Create Gitea Repository
  description: Create a new Git repository in Gitea
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Repository Information
      required:
        - name
        - owner
      properties:
        name:
          title: Repository Name
          type: string
        owner:
          title: Owner
          type: string
          ui:field: OwnerPicker
          ui:options:
            catalogFilter:
              kind: [Group, User]
        visibility:
          title: Visibility
          type: string
          enum: ['public', 'private']
          default: private

  steps:
    - id: publish
      name: Publish to Gitea
      action: publish:gitea
      input:
        repoUrl: gitea.example.com?owner=${{ parameters.owner }}&repo=${{ parameters.name }}
        description: Repository created via Backstage
        defaultBranch: main
        repoVisibility: ${{ parameters.visibility }}

  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
```

**Installation**:
```bash
# Install Gitea module
yarn --cwd packages/backend add @backstage/plugin-scaffolder-backend-module-gitea

# Add to backend
# packages/backend/src/index.ts
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitea'));
```

**Configuration**: `app-config.yaml`
```yaml
integrations:
  gitea:
    - host: gitea.example.com
      username: ${GITEA_USERNAME}
      password: ${GITEA_TOKEN}
```

### Phase 3: Custom Scaffolder Actions (Weeks 4-6)

#### A. Coder Workspace Action

**Module**: `plugins/scaffolder-backend-module-coder/`

**Structure**:
```
plugins/scaffolder-backend-module-coder/
├── package.json
├── src/
│   ├── index.ts
│   ├── module.ts
│   └── actions/
│       ├── createWorkspace.ts
│       └── createWorkspace.test.ts
└── README.md
```

**Implementation**: `plugins/scaffolder-backend-module-coder/src/actions/createWorkspace.ts`

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';

export const createCoderWorkspaceAction = () => {
  return createTemplateAction({
    id: 'coder:create-workspace',
    description: 'Creates a new Coder workspace from a template',
    schema: {
      input: z.object({
        coderUrl: z.string().describe('Coder deployment URL'),
        token: z.string().describe('Coder API token'),
        user: z.string().describe('Username for workspace owner'),
        templateId: z.string().describe('Coder template ID'),
        workspaceName: z.string().describe('Name for the new workspace'),
        parameters: z.record(z.any()).optional().describe('Template parameters'),
      }),
      output: z.object({
        workspaceId: z.string(),
        workspaceUrl: z.string(),
      }),
    },
    async handler(ctx) {
      const { coderUrl, token, user, templateId, workspaceName, parameters } = ctx.input;

      ctx.logger.info(`Creating Coder workspace for user: ${user}`);

      // Call Coder API
      const response = await fetch(
        `${coderUrl}/api/v2/users/${user}/workspaces`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Coder-Session-Token': token,
          },
          body: JSON.stringify({
            name: workspaceName,
            template_id: templateId,
            rich_parameter_values: parameters || {},
          }),
        }
      );

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Failed to create workspace: ${error}`);
      }

      const workspace = await response.json();

      ctx.logger.info(`Workspace created: ${workspace.id}`);

      ctx.output('workspaceId', workspace.id);
      ctx.output('workspaceUrl', `${coderUrl}/@${user}/${workspaceName}`);
    },
  });
};
```

**Module Registration**: `plugins/scaffolder-backend-module-coder/src/module.ts`

```typescript
import { createBackendModule } from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node/alpha';
import { createCoderWorkspaceAction } from './actions/createWorkspace';

export const scaffolderModuleCoderActions = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'coder-actions',
  register(env) {
    env.registerInit({
      deps: {
        scaffolder: scaffolderActionsExtensionPoint,
      },
      async init({ scaffolder }) {
        scaffolder.addActions(createCoderWorkspaceAction());
      },
    });
  },
});
```

**Usage in Template**:
```yaml
steps:
  - id: create-workspace
    name: Create Coder Workspace
    action: coder:create-workspace
    input:
      coderUrl: https://coder.example.com
      token: ${{ secrets.CODER_TOKEN }}
      user: ${{ user.entity.metadata.name }}
      templateId: ${{ parameters.templateId }}
      workspaceName: ${{ parameters.name }}-workspace
      parameters:
        git_repo: ${{ steps.publish.output.remoteUrl }}
```

#### B. Mattermost User/Team Action

**Implementation**: `plugins/scaffolder-backend-module-mattermost/src/actions/createUser.ts`

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';

export const createMattermostUserAction = () => {
  return createTemplateAction({
    id: 'mattermost:create-user',
    description: 'Creates a Mattermost user and adds to team',
    schema: {
      input: z.object({
        mattermostUrl: z.string(),
        token: z.string(),
        username: z.string(),
        email: z.string().email(),
        firstName: z.string().optional(),
        lastName: z.string().optional(),
        teamName: z.string(),
        channels: z.array(z.string()).optional(),
      }),
      output: z.object({
        userId: z.string(),
        teamId: z.string(),
      }),
    },
    async handler(ctx) {
      const { mattermostUrl, token, username, email, firstName, lastName, teamName, channels } = ctx.input;

      const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      };

      // 1. Create user
      const createUserResponse = await fetch(`${mattermostUrl}/api/v4/users`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          username,
          email,
          first_name: firstName,
          last_name: lastName,
          password: Math.random().toString(36).slice(-12), // Temporary password
        }),
      });

      if (!createUserResponse.ok) {
        throw new Error(`Failed to create user: ${await createUserResponse.text()}`);
      }

      const user = await createUserResponse.json();
      ctx.logger.info(`User created: ${user.id}`);

      // 2. Get team by name
      const teamsResponse = await fetch(`${mattermostUrl}/api/v4/teams/name/${teamName}`, {
        method: 'GET',
        headers,
      });

      const team = await teamsResponse.json();

      // 3. Add user to team
      await fetch(`${mattermostUrl}/api/v4/teams/${team.id}/members`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          team_id: team.id,
          user_id: user.id,
        }),
      });

      // 4. Add to channels (optional)
      if (channels) {
        for (const channelName of channels) {
          const channelResponse = await fetch(
            `${mattermostUrl}/api/v4/teams/${team.id}/channels/name/${channelName}`,
            { method: 'GET', headers }
          );
          const channel = await channelResponse.json();

          await fetch(`${mattermostUrl}/api/v4/channels/${channel.id}/members`, {
            method: 'POST',
            headers,
            body: JSON.stringify({ user_id: user.id }),
          });
        }
      }

      ctx.output('userId', user.id);
      ctx.output('teamId', team.id);
    },
  });
};
```

#### C. Twenty CRM Action

**Implementation**: `plugins/scaffolder-backend-module-twenty/src/actions/createPerson.ts`

```typescript
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';

export const createTwentyPersonAction = () => {
  return createTemplateAction({
    id: 'twenty:create-person',
    description: 'Creates a person entity in Twenty CRM',
    schema: {
      input: z.object({
        twentyUrl: z.string(),
        apiKey: z.string(),
        name: z.string(),
        email: z.string().email(),
        phone: z.string().optional(),
        companyId: z.string().optional(),
      }),
      output: z.object({
        personId: z.string(),
      }),
    },
    async handler(ctx) {
      const { twentyUrl, apiKey, name, email, phone, companyId } = ctx.input;

      // GraphQL mutation for creating person
      const mutation = `
        mutation CreatePerson($name: String!, $email: String!, $phone: String, $companyId: ID) {
          createPerson(
            data: {
              name: { firstName: $name }
              email: $email
              phone: $phone
              companyId: $companyId
            }
          ) {
            id
          }
        }
      `;

      const response = await fetch(`${twentyUrl}/graphql`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          query: mutation,
          variables: { name, email, phone, companyId },
        }),
      });

      const result = await response.json();

      if (result.errors) {
        throw new Error(`GraphQL errors: ${JSON.stringify(result.errors)}`);
      }

      const personId = result.data.createPerson.id;
      ctx.logger.info(`Person created in Twenty CRM: ${personId}`);

      ctx.output('personId', personId);
    },
  });
};
```

### Phase 4: Unified Provisioning Template (Week 7)

**Template**: `templates/unified-onboarding/template.yaml`

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: unified-user-onboarding
  title: Unified User Onboarding
  description: Provision user access to all services (Coder, Gitea, Mattermost, Twenty CRM)
spec:
  owner: platform-team
  type: service

  parameters:
    - title: User Information
      required:
        - username
        - email
        - organization
      properties:
        username:
          title: Username
          type: string
          pattern: '^[a-z0-9-]+$'
        email:
          title: Email
          type: string
          format: email
        organization:
          title: Organization
          type: string
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: Group
              spec.type: organization

    - title: Service Provisioning
      properties:
        provisionCoder:
          title: Provision Coder Workspace
          type: boolean
          default: true
        coderTemplate:
          title: Coder Template
          type: string
          enum: ['node-workspace', 'python-workspace', 'full-stack-workspace']
          default: node-workspace
          ui:field: SelectFieldFromApi
          ui:options:
            path: /api/coder/templates

        provisionGitea:
          title: Create Gitea Account & Initial Repo
          type: boolean
          default: true

        provisionMattermost:
          title: Add to Mattermost Team
          type: boolean
          default: true
        mattermostTeam:
          title: Mattermost Team
          type: string
          default: engineering

        provisionTwenty:
          title: Create Twenty CRM Contact
          type: boolean
          default: false

  steps:
    # Step 1: Create Gitea Repository
    - id: create-gitea-repo
      if: ${{ parameters.provisionGitea }}
      name: Create Gitea Initial Repository
      action: publish:gitea
      input:
        repoUrl: gitea.example.com?owner=${{ parameters.username }}&repo=my-first-repo
        description: Initial repository for ${{ parameters.username }}
        repoVisibility: private

    # Step 2: Provision Coder Workspace
    - id: create-coder-workspace
      if: ${{ parameters.provisionCoder }}
      name: Create Coder Workspace
      action: coder:create-workspace
      input:
        coderUrl: ${{ secrets.CODER_URL }}
        token: ${{ secrets.CODER_TOKEN }}
        user: ${{ parameters.username }}
        templateId: ${{ parameters.coderTemplate }}
        workspaceName: ${{ parameters.username }}-dev
        parameters:
          git_repo: ${{ steps['create-gitea-repo'].output.remoteUrl }}

    # Step 3: Create Mattermost User
    - id: create-mattermost-user
      if: ${{ parameters.provisionMattermost }}
      name: Add User to Mattermost
      action: mattermost:create-user
      input:
        mattermostUrl: ${{ secrets.MATTERMOST_URL }}
        token: ${{ secrets.MATTERMOST_TOKEN }}
        username: ${{ parameters.username }}
        email: ${{ parameters.email }}
        teamName: ${{ parameters.mattermostTeam }}
        channels: ['general', 'random']

    # Step 4: Create Twenty CRM Contact
    - id: create-twenty-person
      if: ${{ parameters.provisionTwenty }}
      name: Create Twenty CRM Contact
      action: twenty:create-person
      input:
        twentyUrl: ${{ secrets.TWENTY_URL }}
        apiKey: ${{ secrets.TWENTY_API_KEY }}
        name: ${{ parameters.username }}
        email: ${{ parameters.email }}

  output:
    links:
      - title: Gitea Repository
        url: ${{ steps['create-gitea-repo'].output.remoteUrl }}
        icon: git
      - title: Coder Workspace
        url: ${{ steps['create-coder-workspace'].output.workspaceUrl }}
        icon: dashboard
    text:
      - title: Provisioning Summary
        content: |
          User ${{ parameters.username }} has been provisioned across services:
          - Gitea: ✓ Repository created
          - Coder: ✓ Workspace ready
          - Mattermost: ✓ Added to team
          - Twenty CRM: ✓ Contact created
```

---

## API Integration Details

### Service API Endpoints Summary

| Service | Base URL | Authentication | Key Endpoints |
|---------|----------|----------------|---------------|
| **Coder** | `https://coder.example.com/api/v2` | `Coder-Session-Token` header | `POST /users/{user}/workspaces`<br>`GET /templates` |
| **Gitea** | `https://gitea.example.com/api/v1` | Token or Basic Auth | `POST /orgs/{org}/repos`<br>`POST /user/repos` |
| **Mattermost** | `https://mattermost.example.com/api/v4` | `Bearer` token | `POST /users`<br>`POST /teams/{id}/members` |
| **Twenty CRM** | `https://twenty.example.com/graphql` | `Bearer` API key | GraphQL mutations |

### Error Handling Pattern

```typescript
async function callServiceAPI(url: string, options: RequestInit, ctx: any) {
  try {
    const response = await fetch(url, options);

    if (!response.ok) {
      const errorText = await response.text();
      ctx.logger.error(`API call failed: ${response.status} - ${errorText}`);
      throw new Error(`API Error (${response.status}): ${errorText}`);
    }

    return await response.json();
  } catch (error) {
    ctx.logger.error(`Failed to call API: ${error.message}`);
    throw error;
  }
}
```

---

## Security & RBAC

### Secrets Management

**Use Backstage Proxy for Secure Token Storage**:

`app-config.yaml`:
```yaml
proxy:
  '/coder-api':
    target: https://coder.example.com/api/v2
    headers:
      Coder-Session-Token: ${CODER_ADMIN_TOKEN}

  '/mattermost-api':
    target: https://mattermost.example.com/api/v4
    headers:
      Authorization: Bearer ${MATTERMOST_TOKEN}

  '/twenty-api':
    target: https://twenty.example.com
    headers:
      Authorization: Bearer ${TWENTY_API_KEY}
```

### Permission Checks in Templates

```yaml
# In template.yaml
spec:
  parameters:
    - title: Organization (Required for RBAC)
      required:
        - organization
      properties:
        organization:
          title: Organization
          type: string
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: Group
              spec.type: organization
            # Only show user's own organizations
            allowedKinds: [Group]

# Permission policy will validate user is member of selected organization
```

---

## Deployment Strategy

### Production Deployment Checklist

```bash
# 1. PostgreSQL Database
docker run -d \
  --name backstage-postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=backstage \
  -p 5432:5432 \
  postgres:15

# 2. Backstage Backend
cd packages/backend
yarn build
node dist/bundle.tar.gz

# 3. Backstage Frontend (static build)
cd packages/app
yarn build
# Serve dist/ via nginx or CDN

# 4. Environment Variables
export POSTGRES_HOST=postgres.example.com
export POSTGRES_USER=backstage
export POSTGRES_PASSWORD=***
export KEYCLOAK_CLIENT_ID=backstage
export KEYCLOAK_CLIENT_SECRET=***
export CODER_ADMIN_TOKEN=***
export MATTERMOST_TOKEN=***
export GITEA_TOKEN=***
export TWENTY_API_KEY=***
```

### Kubernetes Deployment

**Helm Chart Structure**:
```yaml
# values.yaml
backstage:
  image: ghcr.io/your-org/backstage:latest
  replicas: 2

  envSecrets:
    - name: POSTGRES_PASSWORD
      secretName: postgres-credentials
      key: password
    - name: KEYCLOAK_CLIENT_SECRET
      secretName: keycloak-credentials
      key: client-secret

  ingress:
    enabled: true
    host: backstage.example.com
    tls:
      enabled: true
      secretName: backstage-tls

postgresql:
  enabled: true
  auth:
    database: backstage
    existingSecret: postgres-credentials
```

---

## Testing Strategy

### Unit Tests for Actions

```typescript
// plugins/scaffolder-backend-module-coder/src/actions/createWorkspace.test.ts
import { createCoderWorkspaceAction } from './createWorkspace';
import { PassThrough } from 'stream';
import { getVoidLogger } from '@backstage/backend-common';

describe('coder:create-workspace', () => {
  const action = createCoderWorkspaceAction();

  it('should create workspace via Coder API', async () => {
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ id: 'ws-123', name: 'test-workspace' }),
    });

    global.fetch = mockFetch as any;

    const context = {
      input: {
        coderUrl: 'https://coder.test',
        token: 'test-token',
        user: 'testuser',
        templateId: 'tmpl-1',
        workspaceName: 'test-workspace',
      },
      output: jest.fn(),
      logger: getVoidLogger(),
      logStream: new PassThrough(),
      workspacePath: '/tmp/test',
    };

    await action.handler(context);

    expect(mockFetch).toHaveBeenCalledWith(
      'https://coder.test/api/v2/users/testuser/workspaces',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          'Coder-Session-Token': 'test-token',
        }),
      })
    );

    expect(context.output).toHaveBeenCalledWith('workspaceId', 'ws-123');
  });
});
```

---

## Timeline & Effort Estimation

| Phase | Duration | Team Size | Deliverables |
|-------|----------|-----------|--------------|
| **Phase 1: Foundation** | 2 weeks | 2 engineers | Backstage + Keycloak SSO + RBAC |
| **Phase 2: Gitea** | 1 week | 1 engineer | Gitea integration working |
| **Phase 3A: Coder Action** | 1.5 weeks | 1 engineer | Custom Coder scaffolder action |
| **Phase 3B: Mattermost Action** | 1 week | 1 engineer | Custom Mattermost action |
| **Phase 3C: Twenty CRM Action** | 0.5 weeks | 1 engineer | Custom Twenty action |
| **Phase 4: Unified Template** | 1 week | 2 engineers | End-to-end provisioning flow |
| **Phase 5: Testing & Docs** | 1 week | 2 engineers | Documentation, tests, deployment |
| **Total** | **8 weeks** | **2-3 engineers** | Production-ready system |

---

## Conclusion

This implementation plan provides:
- ✅ **Multi-tenant SSO** via Keycloak OIDC with organization-based access control
- ✅ **Existing Providers**: Gitea (official), HTTP requests (Roadie)
- ✅ **Custom Actions**: Coder, Mattermost, Twenty CRM (3 custom scaffolder actions)
- ✅ **Unified Provisioning**: Single Software Template orchestrating all services
- ✅ **Production-Ready**: RBAC, error handling, secrets management, testing

**Next Steps**:
1. Review and approve architecture
2. Set up development Backstage instance
3. Begin Phase 1 implementation
4. Iterate based on feedback

**Key Success Metrics**:
- User onboarding time reduced from ~2 hours to < 5 minutes
- Zero manual provisioning errors
- 100% service coverage (Coder, Gitea, Mattermost, Twenty CRM)
- Organization-level isolation enforced via RBAC
