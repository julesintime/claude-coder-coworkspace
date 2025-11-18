# Coder SSO + External Auth Integration Guide

## TL;DR - The Answer

**You need SEPARATE OAuth apps:**
- **Logto/Keycloak** → for SSO (logging into Coder)
- **Direct GitHub/Gitea OAuth** → for External Auth (workspace Git operations)

**Why?** Coder's SSO and External Auth are **independent authentication systems** serving different purposes.

---

## Understanding the Architecture

### 1. SSO Authentication (Logto/Keycloak)

**Purpose**: Authenticate users to access the Coder platform itself

**Flow**:
```
User → Logto/Keycloak → Coder Platform
     (OIDC/OAuth2)         (Dashboard access)
```

**Configuration**:
```bash
# Logto Example
export CODER_OIDC_ISSUER_URL="https://your-logto.app/oidc"
export CODER_OIDC_CLIENT_ID="coder-app"
export CODER_OIDC_CLIENT_SECRET="..."

# Keycloak Example
export CODER_OIDC_ISSUER_URL="https://keycloak.local/realms/homelab"
export CODER_OIDC_CLIENT_ID="coder-app"
export CODER_OIDC_CLIENT_SECRET="..."
export CODER_OIDC_IGNORE_EMAIL_VERIFIED="true"
```

**What it provides**:
- Login to Coder dashboard
- User identity management
- Role-based access control

---

### 2. External Auth (GitHub/Gitea)

**Purpose**: Provide workspace access to Git repositories and external services

**Flow**:
```
Workspace Creation → User clicks "Login with GitHub" → GitHub OAuth
                  ↓
              Coder stores GitHub token
                  ↓
         Workspace receives GITHUB_TOKEN env var
                  ↓
         Git operations, Copilot, extensions work
```

**Configuration**:
```bash
# GitHub External Auth
export CODER_EXTERNAL_AUTH_0_ID="primary-github"
export CODER_EXTERNAL_AUTH_0_TYPE="github"
export CODER_EXTERNAL_AUTH_0_CLIENT_ID="..."      # GitHub OAuth App
export CODER_EXTERNAL_AUTH_0_CLIENT_SECRET="..."

# Gitea External Auth
export CODER_EXTERNAL_AUTH_1_ID="primary-gitea"
export CODER_EXTERNAL_AUTH_1_TYPE="gitea"
export CODER_EXTERNAL_AUTH_1_AUTH_URL="https://gitea.your-domain.com"
export CODER_EXTERNAL_AUTH_1_CLIENT_ID="..."      # Gitea OAuth App
export CODER_EXTERNAL_AUTH_1_CLIENT_SECRET="..."
```

**What it provides**:
- Git clone/push/pull over HTTPS
- GitHub Copilot authentication
- VS Code extension authentication
- API access to GitHub/Gitea

---

## Why You Can't Use SSO for External Auth

### The Problem with Token Brokering

While **both Keycloak and Logto CAN**:
- ✅ Act as identity brokers for GitHub/Gitea
- ✅ Store external provider tokens
- ✅ Provide those tokens to downstream applications via token exchange

**Coder's External Auth expects to**:
- Initiate its OWN OAuth flow with the Git provider
- Receive a redirect callback from GitHub/Gitea
- Store the token in its own database
- Inject it into workspace environments

**The mismatch**:
```
What Logto/Keycloak offers:
User → SSO → GitHub → SSO → Downstream App retrieves token from SSO

What Coder External Auth expects:
User → Coder → GitHub → Coder (stores token)
```

Coder's external auth isn't designed to retrieve tokens from your SSO provider's token exchange endpoint.

---

## Recommended Architecture

### Option 1: Dual OAuth (Recommended)

**Best for**: Production environments, full feature support

```
┌─────────────────────────────────────────────────────┐
│                    User Login                       │
│                                                     │
│  User → Logto/Keycloak → Coder Dashboard          │
│         (SSO - OIDC)                               │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                Workspace Creation                    │
│                                                     │
│  User → "Login with GitHub" → GitHub OAuth → Coder │
│         (External Auth)                            │
│                                                     │
│  User → "Login with Gitea" → Gitea OAuth → Coder  │
│         (External Auth)                            │
└─────────────────────────────────────────────────────┘
```

**Setup Steps**:

1. **Configure SSO (Logto or Keycloak)**
   - Create OIDC client for Coder in Logto/Keycloak
   - Set `CODER_OIDC_*` environment variables
   - Users log into Coder with SSO

2. **Configure GitHub External Auth**
   - Create separate GitHub OAuth App
   - Callback URL: `https://coder.example.com/external-auth/primary-github/callback`
   - Set `CODER_EXTERNAL_AUTH_0_*` environment variables
   - Users authenticate GitHub separately when creating workspaces

3. **Configure Gitea External Auth (if using)**
   - Create separate Gitea OAuth App
   - Callback URL: `https://coder.example.com/external-auth/primary-gitea/callback`
   - Set `CODER_EXTERNAL_AUTH_1_*` environment variables

**Pros**:
- ✅ Full Coder feature support
- ✅ Clean separation of concerns
- ✅ Automatic token refresh by Coder
- ✅ Works with all Git operations
- ✅ GitHub Copilot works seamlessly
- ✅ Documented and officially supported

**Cons**:
- ⚠️ Users authenticate twice (once for Coder, once for Git)
- ⚠️ Requires managing multiple OAuth apps

---

### Option 2: SSO with GitHub/Gitea as Identity Broker

**Best for**: Unified login experience, willing to sacrifice some features

```
┌──────────────────────────────────────────────────────┐
│           Configure in Logto/Keycloak                │
│                                                      │
│  GitHub as Identity Provider                        │
│  ↓                                                  │
│  Enable "Store Tokens"                              │
│  ↓                                                  │
│  User logs into Logto/Keycloak via GitHub          │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│           In Coder Workspaces                        │
│                                                      │
│  Manual token injection via startup script:          │
│  - Fetch GitHub token from Keycloak API            │
│  - Set as GITHUB_TOKEN environment variable        │
└──────────────────────────────────────────────────────┘
```

**Implementation** (Keycloak example):

```hcl
# In your Coder template main.tf

resource "coder_agent" "main" {
  startup_script = <<-EOT
    # Fetch GitHub token from Keycloak
    GITHUB_TOKEN=$(curl -s \
      -H "Authorization: Bearer $CODER_SESSION_TOKEN" \
      "https://keycloak.local/realms/homelab/broker/github/token" | jq -r '.access_token')

    export GITHUB_TOKEN
    echo "export GITHUB_TOKEN=$GITHUB_TOKEN" >> ~/.bashrc
  EOT

  env = {
    CODER_SESSION_TOKEN = coder_workspace_owner.me.session_token
  }
}
```

**Pros**:
- ✅ Single sign-on experience
- ✅ Centralized identity management
- ✅ One OAuth app to manage

**Cons**:
- ⚠️ Requires custom scripting
- ⚠️ Token refresh is manual
- ⚠️ Not officially supported by Coder
- ⚠️ May break with Coder updates
- ⚠️ More complex troubleshooting

---

### Option 3: Parameter-Based (Simplest, Least Secure)

**Best for**: Testing, development environments

```bash
# User provides GitHub PAT as workspace parameter
# No OAuth at all
```

**Pros**:
- ✅ Simplest setup
- ✅ No OAuth configuration needed

**Cons**:
- ❌ Manual token management
- ❌ Tokens don't auto-refresh
- ❌ Security concerns (PATs in parameters)
- ❌ Poor user experience

---

## Detailed Configuration Examples

### Logto + GitHub Dual OAuth

**1. Logto SSO Configuration**

In Logto Console:
1. Create new application → "Traditional Web"
2. Set Redirect URI: `https://coder.example.com/oidc/callback`
3. Note the App ID and App Secret

In Coder Server:
```bash
export CODER_OIDC_ISSUER_URL="https://your-logto.app/oidc"
export CODER_OIDC_CLIENT_ID="<logto-app-id>"
export CODER_OIDC_CLIENT_SECRET="<logto-app-secret>"
export CODER_OIDC_SIGN_IN_TEXT="Sign in with Logto"
```

**2. GitHub External Auth**

In GitHub Settings → Developer Settings → OAuth Apps:
1. Create new OAuth App
2. Homepage URL: `https://coder.example.com`
3. Authorization callback URL: `https://coder.example.com/external-auth/primary-github/callback`
4. Note Client ID and Client Secret

In Coder Server:
```bash
export CODER_EXTERNAL_AUTH_0_ID="primary-github"
export CODER_EXTERNAL_AUTH_0_TYPE="github"
export CODER_EXTERNAL_AUTH_0_CLIENT_ID="<github-client-id>"
export CODER_EXTERNAL_AUTH_0_CLIENT_SECRET="<github-client-secret>"
```

**3. Enable in Template**

Uncomment in `main.tf`:
```hcl
data "coder_external_auth" "github" {
  id       = "primary-github"
  optional = true
}

locals {
  has_github_external_auth = data.coder_external_auth.github.access_token != ""
  github_token = local.has_github_external_auth ?
    data.coder_external_auth.github.access_token :
    data.coder_parameter.github_token.value
}
```

---

### Keycloak + Gitea Dual OAuth

**1. Keycloak SSO Configuration**

In Keycloak Admin Console:
1. Create new client for Coder
2. Client Protocol: openid-connect
3. Access Type: confidential
4. Valid Redirect URIs: `https://coder.example.com/*`
5. Note Client ID and Secret

In Coder Server:
```bash
export CODER_OIDC_ISSUER_URL="https://keycloak.local/realms/homelab"
export CODER_OIDC_CLIENT_ID="coder-app"
export CODER_OIDC_CLIENT_SECRET="<keycloak-secret>"
export CODER_OIDC_IGNORE_EMAIL_VERIFIED="true"
export CODER_OIDC_SIGN_IN_TEXT="Sign in with Keycloak"
```

**2. Gitea External Auth**

In Gitea Settings → Applications → OAuth2 Applications:
1. Create new OAuth2 Application
2. Application Name: "Coder"
3. Redirect URI: `https://coder.example.com/external-auth/primary-gitea/callback`
4. Note Client ID and Client Secret

In Coder Server:
```bash
export CODER_EXTERNAL_AUTH_1_ID="primary-gitea"
export CODER_EXTERNAL_AUTH_1_TYPE="gitea"
export CODER_EXTERNAL_AUTH_1_AUTH_URL="https://gitea.your-domain.com"
export CODER_EXTERNAL_AUTH_1_CLIENT_ID="<gitea-client-id>"
export CODER_EXTERNAL_AUTH_1_CLIENT_SECRET="<gitea-client-secret>"
```

---

## User Experience Comparison

### Dual OAuth Flow (Recommended)

```
1. User navigates to coder.example.com
2. Click "Sign in with Logto/Keycloak"
3. Authenticate with SSO → Dashboard access ✓
4. Click "Create Workspace"
5. Template requires GitHub auth → Click "Login with GitHub"
6. GitHub OAuth flow → Grant access
7. Workspace created with GITHUB_TOKEN ✓
```

**Total authentications**: 2 (SSO + GitHub)
**Complexity**: Low
**Maintenance**: Low
**Token refresh**: Automatic

---

### SSO Brokered Flow (Advanced)

```
1. User navigates to coder.example.com
2. Click "Sign in with Keycloak"
3. Keycloak redirects to GitHub → Authenticate
4. Back to Keycloak → Back to Coder → Dashboard access ✓
5. Click "Create Workspace"
6. Workspace starts → Startup script fetches GitHub token from Keycloak API
7. Token injected into environment ✓
```

**Total authentications**: 1 (GitHub via SSO)
**Complexity**: High
**Maintenance**: High
**Token refresh**: Manual scripting required

---

## Migration Path

If you're currently using Logto/Keycloak for SSO and want to add External Auth:

**Phase 1: Add External Auth (No Disruption)**
```bash
# Keep existing SSO config
# Add GitHub external auth alongside
export CODER_EXTERNAL_AUTH_0_ID="primary-github"
export CODER_EXTERNAL_AUTH_0_TYPE="github"
export CODER_EXTERNAL_AUTH_0_CLIENT_ID="..."
export CODER_EXTERNAL_AUTH_0_CLIENT_SECRET="..."
```

**Phase 2: Update Template**
```bash
# Uncomment external auth blocks in main.tf
# Push updated template
coder templates push unified-devops
```

**Phase 3: Inform Users**
```
Users will need to:
1. Delete old workspaces (if any)
2. Create new workspace
3. Click "Login with GitHub" when prompted
4. Grant access
5. Enjoy automatic GitHub Copilot!
```

---

## Troubleshooting

### "external auth provider not configured" Error

**Cause**: Template references external auth that doesn't exist on server

**Fix**: Either:
1. Configure external auth on server, OR
2. Comment out external auth blocks in template

### Tokens Not Available in Workspace

**Check**:
```bash
# SSH into workspace
coder ssh <workspace>

# Check environment
echo $GITHUB_TOKEN

# Check external auth status
coder external-auth access-token primary-github
```

### GitHub Copilot Not Working

**Requirements**:
1. ✅ External auth configured
2. ✅ GITHUB_TOKEN in environment
3. ✅ GitHub account has Copilot access
4. ✅ Extension installed in code-server

**Verify**:
```bash
# In workspace terminal
gh auth status
```

---

## Summary & Recommendations

**For Production (Recommended)**:
- ✅ Use Dual OAuth (SSO + External Auth)
- ✅ Logto/Keycloak for Coder login
- ✅ Direct GitHub/Gitea OAuth for workspace Git operations
- ✅ Simple, supported, reliable

**For Advanced Users**:
- ⚠️ SSO brokered approach is possible
- ⚠️ Requires custom scripting
- ⚠️ More maintenance overhead
- ⚠️ Consider if unified login is critical requirement

**For Development/Testing**:
- Use parameter-based tokens
- Quick and simple
- Migrate to OAuth for production

---

## Further Reading

- [Coder External Auth Docs](https://coder.com/docs/admin/external-auth)
- [Keycloak Identity Brokering](https://access.redhat.com/documentation/en-us/red_hat_build_of_keycloak/22.0/html/server_developer_guide/identity_brokering_apis)
- [Logto Social Connectors](https://docs.logto.io/integrations/github)
- [GitHub OAuth Apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app)
- [Gitea OAuth2 Provider](https://docs.gitea.com/development/oauth2-provider)

---

**Questions or Issues?**

File an issue at: https://github.com/julesintime/claude-coder-coworkspace/issues
