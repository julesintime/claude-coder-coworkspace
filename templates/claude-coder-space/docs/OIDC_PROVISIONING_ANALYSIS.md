# OIDC + API Provisioning Architecture Analysis

## Executive Summary

This document analyzes three architectural approaches for integrating Backstage with your existing OIDC-enabled services (Coder, Gitea, Mattermost, Twenty CRM) and provides a comprehensive evaluation of the Formula Marketplace implementation strategy.

**Critical Context**: All backend services are already configured with Logto/Keycloak OIDC SSO. Users are auto-created on first login, not pre-provisioned.

**Key Challenge**: How can Backstage act as a control plane to pre-provision resources (workspaces, repos, teams) when users don't exist yet in the target services?

---

## Table of Contents

1. [Architecture Scenarios Comparison](#architecture-scenarios-comparison)
2. [Recommended Solution: Hybrid Pre-provisioning](#recommended-solution-hybrid-pre-provisioning)
3. [Per-Service Implementation Details](#per-service-implementation-details)
4. [Headless vs Direct Access Evaluation](#headless-vs-direct-access-evaluation)
5. [Formula Marketplace Implementation](#formula-marketplace-implementation)
6. [Complete Code Examples](#complete-code-examples)

---

## Architecture Scenarios Comparison

### Scenario A: OIDC-First (Current State)

**How it works:**
```
User signs up in Keycloak
   ↓
User logs into Gitea → OIDC auto-creates Gitea account
User logs into Coder → OIDC auto-creates Coder account
User logs into Mattermost → OIDC auto-creates Mattermost account
   ↓
User manually creates workspace/repo in each service
```

**Backstage Integration Problem:**
```typescript
// ❌ This will FAIL because user doesn't exist in Coder yet
await createCoderWorkspace({
  user: 'alice',  // Alice hasn't logged into Coder yet!
  template: 'node-workspace'
});
// Error: User 'alice' not found
```

**Verdict**: ❌ **Cannot pre-provision resources** - user must login first

---

### Scenario B: API-First with Proxy Service Account

**How it works:**
```
Backstage uses single service account per service
   ↓
All resources created under "backstage-bot" account
   ↓
Resource-level permissions granted to real users
   ↓
Users access services ONLY through Backstage (headless mode)
```

**Architecture:**
```
┌─────────────────────────────────────────────┐
│  Backstage (Control Plane)                 │
│  - backstage-bot@gitea (service account)   │
│  - backstage-bot@coder (service account)   │
│  - backstage-bot@mattermost (admin token)  │
└─────────────────────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│  Gitea                                    │
│  - Organization: "backstage-org"          │
│  - Repos owned by backstage-bot           │
│  - Users added as collaborators           │
└───────────────────────────────────────────┘
```

**Implementation Example:**

```typescript
// Create repo under service account
const repo = await gitea.createRepo({
  owner: 'backstage-org',  // Organization, not individual user
  name: 'alice-project',
  token: GITEA_SERVICE_TOKEN
});

// Grant Alice access as collaborator
await gitea.addCollaborator({
  repo: 'backstage-org/alice-project',
  username: 'alice',  // Alice's OIDC username
  permission: 'write'
});
```

**Pros:**
- ✅ No OIDC conflicts - user accounts never created via API
- ✅ Full control from Backstage
- ✅ Works immediately without user login
- ✅ Centralized resource management
- ✅ Simpler error handling (one service account to manage)

**Cons:**
- ❌ Resources not owned by actual users (owned by backstage-bot)
- ❌ Audit trail shows backstage-bot as creator, not real user
- ❌ Users cannot access services directly (must go through Backstage)
- ❌ Requires all services to support resource-level permissions
- ❌ Some features might not work (e.g., personal settings, preferences)

**Best for:** True "headless" architecture where Backstage is the only interface

---

### Scenario C: Hybrid Pre-provisioning ⭐ **RECOMMENDED**

**How it works:**
```
User signs up in Keycloak/Logto
   ↓
Backstage receives signup webhook/event
   ↓
Backstage pre-creates user in ALL services via admin APIs
(Using same username/email as Keycloak claims)
   ↓
Backstage provisions resources (repos, workspaces, teams)
   ↓
When user eventually logs in via OIDC:
  - Service recognizes user already exists (by email match)
  - OIDC links to existing account
  - No duplicate creation
```

**Critical Implementation Detail:**

```typescript
// 1. Extract user info from Keycloak
const keycloakUser = {
  username: 'alice',           // preferred_username claim
  email: 'alice@acme.com',     // email claim
  groups: ['acme-engineering'] // groups claim
};

// 2. Pre-create in Gitea with OIDC marker
await gitea.admin.createUser({
  username: 'alice',
  email: 'alice@acme.com',
  login_source: 'oauth2',  // ← Marks as OIDC user
  login_name: 'alice@acme.com',
  must_change_password: false
});

// 3. Pre-create in Mattermost linked to OIDC
await mattermost.createUser({
  username: 'alice',
  email: 'alice@acme.com',
  auth_service: 'oidc',    // ← Links to OIDC provider
  auth_data: 'alice@acme.com'
});

// 4. Now we can create resources BEFORE user logs in
await coder.createWorkspace({
  user: 'alice',  // ✅ Now this works!
  template: 'node-workspace'
});
```

**When Alice logs in via OIDC later:**
```
Gitea OIDC flow:
  - Checks: Does user with email 'alice@acme.com' exist? → YES
  - Checks: Is it marked as login_source='oauth2'? → YES
  - Action: Link OIDC session to existing account ✅

Mattermost OIDC flow:
  - Checks: Does user with auth_service='oidc' and auth_data='alice@acme.com' exist? → YES
  - Action: Authenticate existing user ✅
```

**Pros:**
- ✅ Pre-provision resources before first login
- ✅ Resources owned by actual users (proper audit trail)
- ✅ Users can access services directly OR through Backstage
- ✅ No conflicts with OIDC auto-creation
- ✅ Maintains true multi-user architecture

**Cons:**
- ⚠️ Requires careful username/email mapping (must match Keycloak claims exactly)
- ⚠️ Need admin API access to all services
- ⚠️ Slightly complex OIDC linking logic per service

**Best for:** Production multi-tenant systems where users own their resources

---

## Comparison Matrix

| Criteria | OIDC-First | Proxy Account | Hybrid Pre-provision |
|----------|------------|---------------|----------------------|
| **Pre-provision before login** | ❌ No | ✅ Yes | ✅ Yes |
| **True user ownership** | ✅ Yes | ❌ No (bot owns) | ✅ Yes |
| **Audit trail accuracy** | ✅ User = creator | ❌ Bot = creator | ✅ User = creator |
| **Direct service access** | ✅ Yes | ❌ No (headless only) | ✅ Yes |
| **OIDC conflict risk** | ✅ None | ✅ None | ⚠️ Low (if mapped correctly) |
| **Implementation complexity** | ✅ Simple | ⚠️ Medium | ⚠️ Medium |
| **Flexibility** | ❌ Limited | ⚠️ Medium | ✅ High |
| **Production-ready** | ❌ No | ⚠️ Depends | ✅ Yes |

---

## Recommended Solution: Hybrid Pre-provisioning

### Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│            User Signs Up in Keycloak                 │
│  Claims: {username: 'alice', email: 'alice@acme.com'}│
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│         Backstage Receives User Info                 │
│  (via Keycloak webhook or Backstage catalog sync)    │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│    Backstage Pre-provisions User in All Services     │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │ Gitea Admin API                             │   │
│  │ POST /admin/users                           │   │
│  │ {username: 'alice', login_source: 'oauth2'} │   │
│  └─────────────────────────────────────────────┘   │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │ Coder Admin API                             │   │
│  │ POST /api/v2/users                          │   │
│  │ {username: 'alice', email: '...'}           │   │
│  └─────────────────────────────────────────────┘   │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │ Mattermost API                              │   │
│  │ POST /api/v4/users                          │   │
│  │ {username: 'alice', auth_service: 'oidc'}   │   │
│  └─────────────────────────────────────────────┘   │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │ Twenty CRM GraphQL                          │   │
│  │ mutation createPerson                       │   │
│  └─────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│    Backstage Provisions Resources                    │
│  - Gitea: Create initial repository                  │
│  - Coder: Create development workspace               │
│  - Mattermost: Add to team + channels                │
│  - Twenty CRM: Create contact record                 │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│    User Logs In to Services (Later)                  │
│  - OIDC recognizes existing user by email            │
│  - Links OIDC session to pre-created account         │
│  - Resources already waiting for them! ✅            │
└──────────────────────────────────────────────────────┘
```

---

## Per-Service Implementation Details

### 1. Gitea Pre-provisioning

**Admin API Endpoint**: `POST /admin/users`

**Implementation:**

```typescript
async function preProvisionGiteaUser(user: KeycloakUser, adminToken: string) {
  const giteaUser = {
    username: user.username,
    email: user.email,
    login_name: user.email,      // OIDC login identifier
    login_source: 4,              // 4 = OAuth2/OIDC source ID (check your Gitea)
    source_id: 1,                 // Your OIDC provider ID in Gitea
    must_change_password: false,
    send_notify: false,
    visibility: 'public'
  };

  const response = await fetch('https://gitea.example.com/api/v1/admin/users', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `token ${adminToken}`
    },
    body: JSON.stringify(giteaUser)
  });

  if (!response.ok) {
    const error = await response.json();
    // Check if user already exists (409 conflict)
    if (response.status === 409) {
      console.log('User already exists in Gitea');
      return;
    }
    throw new Error(`Failed to create Gitea user: ${JSON.stringify(error)}`);
  }

  return await response.json();
}
```

**OIDC Linking Configuration** (Gitea `app.ini`):

```ini
[oauth2]
ENABLE = true

[oauth2.client]
ACCOUNT_LINKING = auto  # Auto-link to existing accounts by email
UPDATE_AVATAR = true
USERNAME = preferred_username
EMAIL = email
```

**Key Points:**
- ✅ `login_source` must match your OIDC provider configuration
- ✅ `login_name` should be the email or username claim from Keycloak
- ✅ Gitea will auto-link OIDC login to existing account if email matches

---

### 2. Coder Pre-provisioning

**Research Note**: Coder v2 API requires user to exist before creating workspace. Need to check if Coder has user creation endpoint.

**Approach 1: User Creation API (if available)**

```typescript
async function preProvisionCoderUser(user: KeycloakUser, adminToken: string) {
  // Check if Coder has POST /api/v2/users endpoint
  const coderUser = {
    username: user.username,
    email: user.email,
    login_type: 'oidc'
  };

  const response = await fetch('https://coder.example.com/api/v2/users', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Coder-Session-Token': adminToken
    },
    body: JSON.stringify(coderUser)
  });

  return await response.json();
}
```

**Approach 2: Trigger OIDC Login Programmatically**

```typescript
async function triggerCoderOIDCLogin(user: KeycloakUser) {
  // Use Puppeteer/Playwright to automate OIDC login
  // This creates the user in Coder's database
  const browser = await puppeteer.launch();
  const page = await browser.newPage();

  await page.goto('https://coder.example.com/login/oidc');
  // Complete OIDC flow programmatically
  // ...

  await browser.close();
}
```

**Approach 3: Database Direct Insert (Advanced)**

```typescript
// Only if Coder uses PostgreSQL and you have DB access
async function insertCoderUser(user: KeycloakUser, db: PostgresClient) {
  await db.query(`
    INSERT INTO users (id, username, email, created_at, updated_at, status)
    VALUES (gen_random_uuid(), $1, $2, NOW(), NOW(), 'active')
  `, [user.username, user.email]);
}
```

**Recommendation**:
- Check Coder documentation for user creation API
- If not available, use Approach 2 (programmatic OIDC login)
- As fallback, contact Coder support for provisioning guidance

---

### 3. Mattermost Pre-provisioning

**API Endpoint**: `POST /api/v4/users`

**Implementation:**

```typescript
async function preProvisionMattermostUser(user: KeycloakUser, adminToken: string) {
  // 1. Create user
  const mattermostUser = {
    username: user.username,
    email: user.email,
    first_name: user.firstName || '',
    last_name: user.lastName || '',
    auth_service: 'oidc',       // Link to OIDC provider
    auth_data: user.email,      // OIDC identifier
    password: '',               // No password for OIDC users
    email_verified: true
  };

  const createResponse = await fetch('https://mattermost.example.com/api/v4/users', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${adminToken}`
    },
    body: JSON.stringify(mattermostUser)
  });

  const createdUser = await createResponse.json();

  // 2. Add to default team
  const teamId = 'your-team-id'; // Get from Mattermost
  await fetch(`https://mattermost.example.com/api/v4/teams/${teamId}/members`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${adminToken}`
    },
    body: JSON.stringify({
      team_id: teamId,
      user_id: createdUser.id
    })
  });

  // 3. Add to channels
  const channels = ['general', 'random'];
  for (const channelName of channels) {
    const channelResponse = await fetch(
      `https://mattermost.example.com/api/v4/teams/${teamId}/channels/name/${channelName}`,
      {
        method: 'GET',
        headers: { 'Authorization': `Bearer ${adminToken}` }
      }
    );
    const channel = await channelResponse.json();

    await fetch(`https://mattermost.example.com/api/v4/channels/${channel.id}/members`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminToken}`
      },
      body: JSON.stringify({ user_id: createdUser.id })
    });
  }

  return createdUser;
}
```

**OIDC Configuration** (Mattermost `config.json`):

```json
{
  "GitLabSettings": {
    "Enable": true,
    "Id": "your-keycloak-client-id",
    "Secret": "your-keycloak-client-secret",
    "AuthEndpoint": "https://keycloak.example.com/realms/backstage/protocol/openid-connect/auth",
    "TokenEndpoint": "https://keycloak.example.com/realms/backstage/protocol/openid-connect/token",
    "UserApiEndpoint": "https://keycloak.example.com/realms/backstage/protocol/openid-connect/userinfo"
  }
}
```

**Key Points:**
- ✅ `auth_service: 'oidc'` marks user as OIDC-authenticated
- ✅ `auth_data` should match the OIDC subject identifier
- ✅ Mattermost will recognize existing user on OIDC login

---

### 4. Twenty CRM Pre-provisioning

**API Type**: GraphQL

**Implementation:**

```typescript
async function preProvisionTwentyPerson(user: KeycloakUser, apiKey: string) {
  const mutation = `
    mutation CreatePerson($input: PersonCreateInput!) {
      createPerson(data: $input) {
        id
        name {
          firstName
          lastName
        }
        email
        createdAt
      }
    }
  `;

  const variables = {
    input: {
      name: {
        firstName: user.firstName || user.username,
        lastName: user.lastName || ''
      },
      email: user.email,
      phone: user.phone || null,
      // Link to company if organization info available
      companyId: user.organizationId || null
    }
  };

  const response = await fetch('https://twenty.example.com/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({ query: mutation, variables })
  });

  const result = await response.json();

  if (result.errors) {
    throw new Error(`GraphQL errors: ${JSON.stringify(result.errors)}`);
  }

  return result.data.createPerson;
}
```

**Note**: Twenty CRM doesn't have OIDC "user accounts" - it's a CRM system. Pre-provisioning creates a "Person" entity representing the user as a contact.

---

## Complete Backstage Scaffolder Action

**Unified Pre-provisioning Action:**

```typescript
// plugins/scaffolder-backend-module-provisioning/src/actions/preProvisionUser.ts

import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';

export const preProvisionUserAction = () => {
  return createTemplateAction({
    id: 'platform:pre-provision-user',
    description: 'Pre-provisions user across all services before OIDC login',
    schema: {
      input: z.object({
        username: z.string(),
        email: z.string().email(),
        firstName: z.string().optional(),
        lastName: z.string().optional(),
        organization: z.string(),
        services: z.object({
          gitea: z.boolean().default(true),
          coder: z.boolean().default(true),
          mattermost: z.boolean().default(true),
          twenty: z.boolean().default(false),
        }),
      }),
      output: z.object({
        giteaUserId: z.string().optional(),
        coderUserId: z.string().optional(),
        mattermostUserId: z.string().optional(),
        twentyPersonId: z.string().optional(),
      }),
    },
    async handler(ctx) {
      const { username, email, firstName, lastName, organization, services } = ctx.input;

      const results: any = {};

      // 1. Gitea
      if (services.gitea) {
        ctx.logger.info(`Pre-provisioning Gitea user: ${username}`);
        try {
          const giteaUser = await preProvisionGiteaUser(
            { username, email, firstName, lastName },
            ctx.secrets?.GITEA_ADMIN_TOKEN || ''
          );
          results.giteaUserId = giteaUser.id;
          ctx.logger.info(`✅ Gitea user created: ${giteaUser.id}`);
        } catch (error: any) {
          if (error.status === 409) {
            ctx.logger.info('Gitea user already exists, skipping');
          } else {
            ctx.logger.error(`❌ Failed to create Gitea user: ${error.message}`);
            throw error;
          }
        }
      }

      // 2. Coder
      if (services.coder) {
        ctx.logger.info(`Pre-provisioning Coder user: ${username}`);
        try {
          const coderUser = await preProvisionCoderUser(
            { username, email },
            ctx.secrets?.CODER_ADMIN_TOKEN || ''
          );
          results.coderUserId = coderUser.id;
          ctx.logger.info(`✅ Coder user created: ${coderUser.id}`);
        } catch (error: any) {
          ctx.logger.error(`❌ Failed to create Coder user: ${error.message}`);
          // Don't throw - Coder might auto-create on first workspace creation
          ctx.logger.warn('Will retry during workspace creation');
        }
      }

      // 3. Mattermost
      if (services.mattermost) {
        ctx.logger.info(`Pre-provisioning Mattermost user: ${username}`);
        try {
          const mattermostUser = await preProvisionMattermostUser(
            { username, email, firstName, lastName, organization },
            ctx.secrets?.MATTERMOST_ADMIN_TOKEN || ''
          );
          results.mattermostUserId = mattermostUser.id;
          ctx.logger.info(`✅ Mattermost user created: ${mattermostUser.id}`);
        } catch (error: any) {
          ctx.logger.error(`❌ Failed to create Mattermost user: ${error.message}`);
          throw error;
        }
      }

      // 4. Twenty CRM
      if (services.twenty) {
        ctx.logger.info(`Pre-provisioning Twenty CRM person: ${email}`);
        try {
          const twentyPerson = await preProvisionTwentyPerson(
            { username, email, firstName, lastName },
            ctx.secrets?.TWENTY_API_KEY || ''
          );
          results.twentyPersonId = twentyPerson.id;
          ctx.logger.info(`✅ Twenty person created: ${twentyPerson.id}`);
        } catch (error: any) {
          ctx.logger.error(`❌ Failed to create Twenty person: ${error.message}`);
          // Non-critical - continue
        }
      }

      // Output all created IDs
      ctx.output('giteaUserId', results.giteaUserId);
      ctx.output('coderUserId', results.coderUserId);
      ctx.output('mattermostUserId', results.mattermostUserId);
      ctx.output('twentyPersonId', results.twentyPersonId);

      ctx.logger.info(`✅ User pre-provisioning complete for: ${username}`);
    },
  });
};
```

---

## Headless vs Direct Access Evaluation

### Option 1: Headless Services (Backstage as Only Interface)

**Architecture:**
```
User → Backstage UI → Embedded Service UIs
                   → Proxy APIs
```

**Implementation:**

```typescript
// Backstage backend proxy configuration
// app-config.yaml
proxy:
  '/gitea':
    target: https://gitea.example.com
    pathRewrite:
      '^/api/proxy/gitea': '/'
    headers:
      Authorization: 'token ${GITEA_SERVICE_TOKEN}'

  '/coder':
    target: https://coder.example.com
    pathRewrite:
      '^/api/proxy/coder': '/'
    headers:
      Coder-Session-Token: '${CODER_SERVICE_TOKEN}'
```

**Frontend Integration (Embedded Coder UI):**

```tsx
// packages/app/src/components/coder/CoderWorkspaceView.tsx

import React from 'react';
import { useEntity } from '@backstage/plugin-catalog-react';

export const CoderWorkspaceView = () => {
  const { entity } = useEntity();
  const workspaceId = entity.metadata.annotations?.['coder.com/workspace-id'];

  // Embed Coder UI in iframe
  return (
    <div style={{ height: '100vh' }}>
      <iframe
        src={`/api/proxy/coder/@${entity.spec.owner}/${workspaceId}`}
        style={{ width: '100%', height: '100%', border: 'none' }}
        title="Coder Workspace"
      />
    </div>
  );
};
```

**Pros:**
- ✅ Single sign-on (only Backstage login needed)
- ✅ Unified UX
- ✅ Centralized access control
- ✅ Better for non-technical users
- ✅ Easier to enforce compliance policies

**Cons:**
- ❌ Complex iframe integration
- ❌ Some features might break in embedded context
- ❌ Power users can't use native service UIs
- ❌ Requires custom frontend components
- ❌ Maintenance overhead

---

### Option 2: Direct Access (Hybrid Approach) ⭐ **RECOMMENDED**

**Architecture:**
```
User → Backstage (provisioning/discovery)
    → Gitea (direct access via OIDC)
    → Coder (direct access via OIDC)
    → Mattermost (direct access via OIDC)
```

**Backstage Integration (Links + Monitoring):**

```typescript
// Entity annotation to link to external service
// catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-project
  annotations:
    gitea.com/repo-url: https://gitea.example.com/alice/my-project
    coder.com/workspace-url: https://coder.example.com/@alice/my-project-dev
    mattermost.com/channel-url: https://mattermost.example.com/team/channels/my-project
spec:
  type: service
  owner: alice
```

**Backstage UI (Link Cards):**

```tsx
// packages/app/src/components/catalog/EntityPage.tsx

import { EntityGiteaCard } from '@internal/plugin-gitea';
import { EntityCoderCard } from '@coder/backstage-plugin-coder';

const serviceEntityPage = (
  <EntityLayout>
    <EntityLayout.Route path="/" title="Overview">
      <Grid container spacing={3}>
        <Grid item md={6}>
          <EntityGiteaCard />
        </Grid>
        <Grid item md={6}>
          <EntityCoderCard />
        </Grid>
      </Grid>
    </EntityLayout.Route>
  </EntityLayout>
);
```

**EntityGiteaCard Component:**

```tsx
import React from 'react';
import { InfoCard } from '@backstage/core-components';
import { useEntity } from '@backstage/plugin-catalog-react';
import LaunchIcon from '@material-ui/icons/Launch';

export const EntityGiteaCard = () => {
  const { entity } = useEntity();
  const repoUrl = entity.metadata.annotations?.['gitea.com/repo-url'];

  return (
    <InfoCard title="Gitea Repository">
      <div>
        <p>Repository: {repoUrl}</p>
        <a href={repoUrl} target="_blank" rel="noopener">
          Open in Gitea <LaunchIcon />
        </a>
      </div>
    </InfoCard>
  );
};
```

**Pros:**
- ✅ Users can access services directly (power user friendly)
- ✅ Simpler implementation (just links, no embedding)
- ✅ Native service UX (all features work)
- ✅ Backstage acts as discovery/provisioning layer
- ✅ Lower maintenance
- ✅ Coder plugin already provides this pattern

**Cons:**
- ⚠️ Users need to login to each service via OIDC (but only once)
- ⚠️ Multiple browser tabs/windows
- ⚠️ Less control over what users can do

---

### Comparison Matrix

| Aspect | Headless (Embedded) | Direct Access |
|--------|---------------------|---------------|
| **User Experience** | Unified, single interface | Native service UIs |
| **Implementation Complexity** | ❌ High (iframes, proxies) | ✅ Low (links, cards) |
| **Feature Completeness** | ⚠️ Some features broken | ✅ All features work |
| **Access Control** | ✅ Centralized | ⚠️ Per-service |
| **Developer Preference** | ⚠️ Mixed (less control) | ✅ High (full access) |
| **Maintenance** | ❌ High | ✅ Low |
| **Time to Implement** | 6-8 weeks | 2-3 weeks |

**Recommendation**:
- **Phase 1**: Direct access with Backstage cards/links (fast MVP)
- **Phase 2**: Add embedded views for specific workflows (e.g., quick repo browse)
- **Phase 3**: Fully headless if organizational policy requires it

---

## Formula Marketplace Implementation

### Approach 1: Software Templates (MVP) ⭐ **FASTEST**

**Structure:**
```
formula-marketplace/
├── formulas/
│   ├── ml-research/
│   │   └── template.yaml
│   ├── fullstack-dev/
│   │   └── template.yaml
│   └── data-analysis/
│       └── template.yaml
└── catalog-info.yaml
```

**Example Formula Template:**

```yaml
# formulas/ml-research/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: formula-ml-research
  title: 🧪 ML Research Workspace
  description: GPU-accelerated workspace with Jupyter, PyTorch, TensorFlow
  tags:
    - machine-learning
    - research
    - gpu
    - python
spec:
  owner: platform-team
  type: formula

  parameters:
    - title: Workspace Configuration
      required:
        - name
        - gpu_type
      properties:
        name:
          title: Workspace Name
          type: string
          pattern: '^[a-z0-9-]+$'

        gpu_type:
          title: GPU Type
          type: string
          enum: ['nvidia-a100', 'nvidia-h100', 'nvidia-v100']
          default: nvidia-a100
          enumNames: ['A100 (40GB)', 'H100 (80GB)', 'V100 (16GB)']

        memory:
          title: Memory (GB)
          type: number
          enum: [32, 64, 128]
          default: 64

        storage:
          title: Storage (GB)
          type: number
          default: 500
          minimum: 100
          maximum: 2000

  steps:
    # Step 1: Pre-provision user
    - id: pre-provision
      name: Pre-provision User
      action: platform:pre-provision-user
      input:
        username: ${{ user.entity.metadata.name }}
        email: ${{ user.entity.spec.profile.email }}
        organization: ${{ parameters.organization }}
        services:
          gitea: true
          coder: true
          mattermost: true
          twenty: false

    # Step 2: Create Gitea repository
    - id: create-repo
      name: Create ML Research Repository
      action: publish:gitea
      input:
        repoUrl: gitea.example.com?owner=${{ user.entity.metadata.name }}&repo=${{ parameters.name }}
        description: ML Research project created from formula
        defaultBranch: main
        gitAuthorName: ${{ user.entity.spec.profile.displayName }}
        gitAuthorEmail: ${{ user.entity.spec.profile.email }}

    # Step 3: Create Coder workspace with ML template
    - id: create-workspace
      name: Create Coder Workspace
      action: coder:create-workspace
      input:
        coderUrl: ${{ secrets.CODER_URL }}
        token: ${{ secrets.CODER_ADMIN_TOKEN }}
        user: ${{ user.entity.metadata.name }}
        templateId: ml-research-template
        workspaceName: ${{ parameters.name }}
        parameters:
          gpu_type: ${{ parameters.gpu_type }}
          memory_gb: ${{ parameters.memory }}
          storage_gb: ${{ parameters.storage }}
          git_repo: ${{ steps['create-repo'].output.remoteUrl }}
          ai_prompt: |
            You are a machine learning research assistant specialized in PyTorch and TensorFlow.
            Provide guidance on model architecture, training optimization, and experiment tracking.
            Always suggest best practices for reproducibility and documentation.

    # Step 4: Register in catalog
    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['create-repo'].output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'

  output:
    links:
      - title: Gitea Repository
        url: ${{ steps['create-repo'].output.remoteUrl }}
        icon: git
      - title: Coder Workspace
        url: ${{ steps['create-workspace'].output.workspaceUrl }}
        icon: dashboard
      - title: View in Catalog
        entityRef: ${{ steps.register.output.entityRef }}
```

**Formula Discovery UI:**

```tsx
// packages/app/src/components/formulas/FormulaMarketplace.tsx

import React from 'react';
import { Content, Header, Page } from '@backstage/core-components';
import { useEntityList } from '@backstage/plugin-catalog-react';

export const FormulaMarketplace = () => {
  const { entities } = useEntityList({
    filter: {
      kind: 'Template',
      'spec.type': 'formula'
    }
  });

  return (
    <Page themeId="home">
      <Header title="Formula Marketplace" subtitle="Pre-configured workspace recipes" />
      <Content>
        <Grid container spacing={3}>
          {entities.map(formula => (
            <Grid item xs={12} md={4} key={formula.metadata.name}>
              <FormulaCard formula={formula} />
            </Grid>
          ))}
        </Grid>
      </Content>
    </Page>
  );
};
```

**Pros:**
- ✅ Uses existing Backstage infrastructure
- ✅ Searchable, taggable, version-controlled
- ✅ No custom backend needed
- ✅ Time to implement: 1-2 weeks

**Cons:**
- ⚠️ Templates are static YAML (limited dynamic logic)
- ⚠️ No built-in ratings/reviews
- ⚠️ Limited metadata (tags, description only)

---

### Approach 2: Custom Entity Kind "Formula"

**Entity Definition:**

```yaml
# catalog-model/formula-entity.yaml
apiVersion: backstage.io/v1alpha1
kind: Formula
metadata:
  name: ml-research-workspace
  namespace: formulas
  title: ML Research Workspace
  description: GPU-accelerated ML research environment
  tags:
    - machine-learning
    - gpu
    - research
  annotations:
    formula.marketplace/category: research
    formula.marketplace/difficulty: intermediate
    formula.marketplace/rating: "4.8"
    formula.marketplace/usage-count: "142"
spec:
  type: workspace
  version: 2.0.0
  author: platform-team

  hardware:
    cpu:
      min: 8
      max: 32
      default: 16
      unit: cores
    memory:
      min: 32
      max: 128
      default: 64
      unit: GB
    gpu:
      required: true
      types: [nvidia-a100, nvidia-h100, nvidia-v100]
      default: nvidia-a100
    storage:
      min: 100
      max: 2000
      default: 500
      unit: GB

  software:
    baseImage: ubuntu:22.04
    packages:
      system:
        - cuda-toolkit-12-0
        - python3.11
        - git
      python:
        - torch==2.0.0
        - tensorflow==2.12.0
        - jupyter-lab==4.0.0
        - transformers==4.28.0

  coderTemplate: ml-research-template

  aiConfiguration:
    systemPrompt: |
      You are a machine learning research assistant.
      Specialize in PyTorch and TensorFlow.
    codeStyle: |
      - Use type hints
      - Add docstrings
      - Follow PEP 8

  initScript: |
    #!/bin/bash
    pip install torch torchvision
    jupyter lab --generate-config
    git config --global user.name "$GIT_AUTHOR_NAME"

  relatedFormulas:
    - formula:default/deep-learning-training
    - formula:default/computer-vision-research

status:
  createdAt: 2024-01-15T10:00:00Z
  updatedAt: 2024-03-20T15:30:00Z
  usageCount: 142
  averageRating: 4.8
```

**Custom Plugin Structure:**

```
plugins/
└── formula-marketplace/
    ├── src/
    │   ├── components/
    │   │   ├── FormulaCard.tsx
    │   │   ├── FormulaDetails.tsx
    │   │   └── FormulaProvisionDialog.tsx
    │   ├── api/
    │   │   └── FormulaApi.ts
    │   └── plugin.ts
    └── package.json
```

**Pros:**
- ✅ First-class entities in catalog
- ✅ Rich metadata (ratings, usage stats)
- ✅ Can have relationships between formulas
- ✅ Custom UI possible

**Cons:**
- ⚠️ Need to build custom plugin (4-6 weeks)
- ⚠️ More complex than templates
- ⚠️ Requires entity processor for validation

---

### Approach 3: Separate Microservice

**Architecture:**

```
┌──────────────────────────────────────────┐
│  Formula Marketplace Service             │
│  ┌────────────────────────────────────┐  │
│  │ REST API (Express/FastAPI)         │  │
│  │ - GET /api/formulas                │  │
│  │ - POST /api/formulas/{id}/provision│  │
│  │ - POST /api/formulas/{id}/rate     │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ PostgreSQL Database                │  │
│  │ - formulas table                   │  │
│  │ - versions table                   │  │
│  │ - ratings table                    │  │
│  │ - usage_logs table                 │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
              ↓
┌──────────────────────────────────────────┐
│  Backstage Plugin                        │
│  - Consumes formula marketplace API      │
│  - Displays formulas in UI               │
│  - Triggers provisioning                 │
└──────────────────────────────────────────┘
```

**Database Schema:**

```sql
CREATE TABLE formulas (
  id UUID PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(100),
  author VARCHAR(255),
  config JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE formula_versions (
  id UUID PRIMARY KEY,
  formula_id UUID REFERENCES formulas(id),
  version VARCHAR(50) NOT NULL,
  config JSONB NOT NULL,
  released_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE formula_ratings (
  id UUID PRIMARY KEY,
  formula_id UUID REFERENCES formulas(id),
  user_id VARCHAR(255) NOT NULL,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  review TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE formula_usage (
  id UUID PRIMARY KEY,
  formula_id UUID REFERENCES formulas(id),
  user_id VARCHAR(255) NOT NULL,
  provisioned_at TIMESTAMP DEFAULT NOW()
);
```

**Pros:**
- ✅ Full control over features
- ✅ Can add reviews, ratings, analytics
- ✅ Independent deployment/scaling
- ✅ Can be used by other systems

**Cons:**
- ❌ Most complex (8-10 weeks development)
- ❌ More infrastructure to manage
- ❌ Need to integrate with Backstage

---

## Comparison: Formula Implementation Approaches

| Feature | Software Templates | Custom Entity | Microservice |
|---------|-------------------|---------------|--------------|
| **Time to MVP** | 1-2 weeks | 4-6 weeks | 8-10 weeks |
| **Development Effort** | ✅ Low | ⚠️ Medium | ❌ High |
| **Flexibility** | ⚠️ Limited | ⚠️ Medium | ✅ Full |
| **Versioning** | ⚠️ Git-based | ✅ Entity versioning | ✅ DB versioning |
| **User Ratings** | ❌ No | ⚠️ Via annotations | ✅ Built-in |
| **Search/Filter** | ✅ Built-in | ✅ Built-in | ⚠️ Custom |
| **Dynamic Config** | ❌ Static YAML | ⚠️ Limited | ✅ Full |
| **Integration** | ✅ Native | ✅ Native | ⚠️ API-based |
| **Maintenance** | ✅ Low | ⚠️ Medium | ❌ High |

---

## Final Recommendations

### For User Provisioning

✅ **Use Hybrid Pre-provisioning (Scenario C)**

**Implementation Steps:**
1. Create pre-provisioning scaffolder action
2. Configure admin API tokens for all services
3. Implement OIDC claim mapping (username/email)
4. Test OIDC linking on first login
5. Add error handling and idempotency

**Timeline**: 2-3 weeks

---

### For Service Access

✅ **Start with Direct Access, Add Headless Features Later**

**Phase 1 (Weeks 1-2)**: Direct access with Backstage cards
- Users login to services via OIDC
- Backstage shows links to Gitea repos, Coder workspaces
- Use existing Coder plugin for workspace management

**Phase 2 (Weeks 8-10)**: Add embedded views for specific workflows
- Embed Gitea file browser for quick previews
- Embed Coder terminal for quick access
- Keep option for full native UI access

---

### For Formula Marketplace

✅ **MVP with Software Templates → Migrate to Custom Entity**

**Phase 1 (Weeks 1-2)**: Software Templates
- Create 5-10 formula templates
- Tag with `type: formula`
- Build simple discovery UI
- Test provisioning flow

**Phase 2 (Weeks 6-10)**: Custom Formula Entity
- Define Formula entity kind
- Migrate templates to entities
- Add ratings/reviews via annotations
- Build rich marketplace UI

**Phase 3 (Future)**: Add dynamic features
- A/B testing of formulas
- Usage analytics
- Formula recommendations
- Community contributions

---

## Success Metrics

- ✅ User onboarding time: < 5 minutes (down from 2 hours)
- ✅ Zero manual provisioning errors
- ✅ 100% service coverage (Coder, Gitea, Mattermost, Twenty)
- ✅ Formula usage rate: > 80% of new workspaces
- ✅ User satisfaction: > 4.5/5 rating

---

## Next Steps

1. **Validate architecture** with team
2. **Set up dev Backstage** instance
3. **Implement pre-provisioning action** (Week 1-2)
4. **Create 3 pilot formulas** (Week 3)
5. **Test end-to-end flow** with pilot users (Week 4)
6. **Iterate based on feedback**
7. **Production rollout**
