# Unified Service Management Panel - Evaluation & Implementation Plan

## Use Case

**Problem**: Users signing up via SSO (Logto/Keycloak) must manually navigate to multiple self-hosted services (Coder, Gitea, Twenty CRM, Mattermost) to create accounts and provision resources.

**Solution**: A unified control panel that automatically provisions user accounts and resources across all services through a single interface after SSO authentication.

**User Journey**:
1. User signs up/logs in via Logto/Keycloak SSO
2. Lands on unified dashboard
3. Self-service provisions:
   - Coder workspace from predefined templates
   - Gitea account + repositories
   - Twenty CRM user/entities
   - Mattermost team membership
4. All services pre-authenticated and ready to use

---

## Technical Requirements

### Core Capabilities
- **SSO Integration**: Logto/Keycloak OAuth2/OIDC authentication
- **API Orchestration**: Programmatic provisioning across services
- **Idempotency**: Safe retry logic for failed operations
- **RBAC**: Role-based resource templates (dev, admin, manager)
- **Audit Trail**: Track all provisioning actions

### Service API Availability
✅ **Coder**: REST API with workspace creation (`POST /api/v2/users/{user}/workspaces`)
✅ **Gitea**: REST API with repo creation (`/api/v1/repos`, `/api/v1/users`)
✅ **Mattermost**: REST API for users/teams (`/api/v4/users`, `/api/v4/teams`)
✅ **Twenty CRM**: REST + GraphQL API with full entity management
✅ **Logto/Keycloak**: OIDC/OAuth2 standard compliant

---

## Architecture Options

### Option 1: Backstage Framework ⭐ **RECOMMENDED**

**Overview**: Spotify's production-ready open-source IDP framework

**Existing Plugins**:
- ✅ **Coder Plugin** ([coder/backstage-plugins](https://github.com/coder/backstage-plugins))
  - Workspace creation/management
  - Template mapping to catalog entities
  - Direct IDE launch from portal
- ✅ **Gitea Plugin** (`@backstage/plugin-scaffolder-backend-module-gitea`)
  - Repository scaffolding
  - Self-service repo creation
  - RepoUrlPicker UI component
- ⚠️ **Mattermost**: No official plugin (custom integration needed)
- ⚠️ **Twenty CRM**: No official plugin (custom integration needed)

**Architecture**:
```
┌─────────────────────────────────────────────────────┐
│  Backstage Frontend (React)                         │
│  - Software Catalog                                 │
│  - Software Templates (Scaffolder)                  │
│  - Custom Provisioning UI                          │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  Backstage Backend (Node.js)                        │
│  - Coder Plugin (existing)                          │
│  - Gitea Plugin (existing)                          │
│  - Custom Mattermost Provider                       │
│  - Custom Twenty CRM Provider                       │
│  - Auth Provider (Logto/Keycloak OIDC)             │
└─────────────────────────────────────────────────────┘
                      ↓
┌────────────┬──────────┬────────────┬───────────────┐
│   Coder    │  Gitea   │ Mattermost │  Twenty CRM   │
│  REST API  │ REST API │  REST API  │ REST/GraphQL  │
└────────────┴──────────┴────────────┴───────────────┘
```

**Pros**:
- Production-ready framework (used by Spotify, Netflix, etc.)
- 50% of work done (Coder + Gitea plugins exist)
- Built-in catalog, RBAC, audit logging
- Active community (GitHub: 28k+ stars)
- Template-driven provisioning (Software Templates)
- Extensible plugin architecture

**Cons**:
- Heavy framework (requires 2-5 engineers for setup per Gartner)
- TypeScript/React mandatory (learning curve)
- Need to build custom plugins for Mattermost + Twenty
- Resource intensive (Node.js + PostgreSQL recommended)

**Effort Estimate**:
- Initial setup: 2-3 weeks
- Custom plugins (Mattermost + Twenty): 3-4 weeks
- SSO integration: 1 week
- Testing + refinement: 2 weeks
- **Total**: 8-10 weeks with 2-3 engineers

---

### Option 2: OpenChoreo

**Overview**: Open-source IDP built on CNCF tools (Kubernetes, Argo CD, Backstage core)

**Status**:
- GitHub: [openchoreo/openchoreo](https://github.com/openchoreo/openchoreo)
- ⚠️ Under active development
- ⚠️ Missing central portal integration (per search results)

**Pros**:
- GitOps-native (Argo CD)
- Kubernetes-first design
- Production-ready infrastructure components

**Cons**:
- Less mature than Backstage
- Smaller community
- Portal integration incomplete
- Would still need custom service integrations

**Verdict**: Not recommended for this use case due to maturity concerns.

---

### Option 3: Custom Build

**Tech Stack**:
- Frontend: React/Vue.js
- Backend: Node.js/Python FastAPI
- Database: PostgreSQL
- Auth: Logto SDK
- Workflow: Temporal.io (orchestration)

**Architecture**:
```
┌──────────────────────────────────────────┐
│  React/Vue Frontend                      │
│  - Dashboard UI                          │
│  - Service Provisioning Forms            │
└──────────────────────────────────────────┘
                ↓
┌──────────────────────────────────────────┐
│  Backend API (Node.js/Python)            │
│  - SSO Auth Middleware                   │
│  - Service Adapter Layer:                │
│    - CoderAdapter                        │
│    - GiteaAdapter                        │
│    - MattermostAdapter                   │
│    - TwentyCRMAdapter                    │
│  - Workflow Engine (Temporal)            │
└──────────────────────────────────────────┘
                ↓
┌────────────────────────────────────────┐
│  PostgreSQL                             │
│  - User mappings                        │
│  - Provisioning state                   │
│  - Audit logs                           │
└────────────────────────────────────────┘
```

**Pros**:
- Full control over UX
- Lightweight (no framework overhead)
- Tailored to exact requirements
- Flexible tech stack

**Cons**:
- Build everything from scratch
- No community plugins/patterns
- Long-term maintenance burden
- Missing catalog, RBAC, audit features
- Reinventing solved problems

**Effort Estimate**:
- Frontend + backend scaffolding: 4 weeks
- Service adapters (4 services): 6 weeks
- SSO integration: 2 weeks
- Workflow orchestration: 3 weeks
- Testing + security: 3 weeks
- **Total**: 18-20 weeks with 2-3 engineers

---

## Comparison Matrix

| Criteria | Backstage | OpenChoreo | Custom Build |
|----------|-----------|------------|--------------|
| **Production Readiness** | ✅ High | ⚠️ Medium | ❌ Low (new) |
| **Time to MVP** | 8-10 weeks | 12-16 weeks | 18-20 weeks |
| **Existing Integrations** | 2/4 services | 0/4 services | 0/4 services |
| **Community Support** | ✅ Large | ⚠️ Small | ❌ None |
| **Maintenance Burden** | ⚠️ Medium | ⚠️ Medium | ❌ High |
| **Customization** | ⚠️ Plugin-based | ✅ Full | ✅ Full |
| **SSO Integration** | ✅ Built-in | ✅ Built-in | ⚠️ Custom |
| **RBAC/Audit** | ✅ Built-in | ✅ Built-in | ❌ Build needed |
| **Learning Curve** | ⚠️ High | ⚠️ High | ✅ Low |
| **Cost (engineering)** | 2-3 engineers | 3-4 engineers | 3-4 engineers |

---

## Implementation Plan (Backstage Approach)

### Phase 1: Foundation (Weeks 1-3)
- [ ] Deploy Backstage instance (Docker/K8s)
- [ ] Configure PostgreSQL backend
- [ ] Integrate Logto/Keycloak SSO provider
- [ ] Set up development environment
- [ ] Create base software catalog

### Phase 2: Existing Plugins (Weeks 4-5)
- [ ] Install Coder plugin
  - Configure Coder API endpoint
  - Create workspace templates
  - Map catalog entities to templates
- [ ] Install Gitea plugin
  - Configure Gitea integration
  - Create repository scaffolding templates
  - Set up default repo templates

### Phase 3: Custom Plugins (Weeks 6-9)
- [ ] Build Mattermost backend plugin
  - User creation API integration
  - Team assignment logic
  - Channel auto-join workflows
- [ ] Build Twenty CRM backend plugin
  - User provisioning via GraphQL
  - Entity creation (contacts, companies)
  - Custom fields mapping

### Phase 4: Orchestration (Weeks 10-11)
- [ ] Create unified provisioning template
- [ ] Implement workflow:
  1. User authenticates via SSO
  2. Trigger multi-service provisioning
  3. Coder workspace creation
  4. Gitea account + initial repo
  5. Mattermost team membership
  6. Twenty CRM user entity
- [ ] Add error handling + rollback logic
- [ ] Implement provisioning status dashboard

### Phase 5: Testing & Launch (Weeks 12-13)
- [ ] Integration testing across all services
- [ ] Security audit (API key storage, RBAC)
- [ ] User acceptance testing
- [ ] Documentation
- [ ] Production deployment

---

## Alternative: Hybrid Approach

**Concept**: Use Backstage for Coder + Gitea, build lightweight microservice for Mattermost + Twenty provisioning

**Why**: Reduce Backstage complexity while leveraging existing plugins

**Architecture**:
```
Backstage (Coder + Gitea) ←→ Provisioning Service (Mattermost + Twenty)
                ↓
        Shared SSO (Logto/Keycloak)
```

**Pros**:
- Faster implementation (6-8 weeks)
- Simpler Backstage setup
- Flexible for non-core services

**Cons**:
- Fragmented UX (two interfaces)
- Duplicate auth/RBAC logic

---

## Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Backstage complexity** | Start with minimal plugins, iterate incrementally |
| **Custom plugin quality** | Follow Backstage plugin development best practices, use TypeScript |
| **API rate limits** | Implement retry logic, request throttling, caching |
| **Service downtime** | Graceful degradation, queue failed operations for retry |
| **Secret management** | Use Backstage's secret storage, Vault integration |
| **Multi-tenant isolation** | Leverage Backstage RBAC + organization scoping |

---

## Recommendation

**Use Backstage** with custom plugins for Mattermost and Twenty CRM.

**Reasoning**:
1. **50% head start**: Coder and Gitea plugins already exist and are production-ready
2. **Battle-tested**: Used by major tech companies (Spotify, Netflix, American Airlines)
3. **Future-proof**: Growing ecosystem (1000+ community plugins)
4. **Built-in features**: Catalog, RBAC, audit logging, SSO already implemented
5. **Time to value**: 8-10 weeks vs 18-20 weeks for custom build
6. **Community**: Active support, documentation, patterns

**When NOT to use Backstage**:
- Team has no TypeScript/React experience (high learning curve)
- Extreme customization needs that break Backstage conventions
- Resource constraints (< 2 engineers available)

**Quick Win Alternative**:
If resources are extremely limited, build a minimal **provisioning microservice** (Python FastAPI) that:
- Authenticates via Logto
- Orchestrates APIs directly using Temporal.io
- Provides simple React dashboard
- Can later be migrated to Backstage

This gets a working system in 6-8 weeks but sacrifices catalog, templates, and long-term scalability.

---

## Reference Implementation

**GitHub Repositories**:
- Backstage: https://github.com/backstage/backstage
- Coder Plugin: https://github.com/coder/backstage-plugins
- Gitea Plugin: Built into Backstage core
- Plugin Template: https://github.com/backstage/backstage/tree/master/plugins

**Documentation**:
- Backstage Plugins: https://backstage.io/docs/plugins/
- Coder API: https://coder.com/docs/api
- Gitea API: https://docs.gitea.com/api
- Mattermost API: https://api.mattermost.com/
- Twenty API: https://twenty.com/developers/section/api-and-webhooks/api

**Example Projects**:
- Roadie (Managed Backstage): https://roadie.io/backstage/plugins/coder/
- OpenChoreo: https://github.com/openchoreo/openchoreo

---

**Next Steps**:
1. Validate Backstage approach with stakeholders
2. Set up Backstage development environment
3. Prototype Coder plugin integration (Week 1)
4. Build Mattermost plugin POC (Week 2-3)
5. Demo end-to-end provisioning flow
