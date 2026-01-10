# MCP Platform Domain Reference

> **Audience**: Product Managers, Stakeholders, Business Analysts
> **Generated**: 2026-01-10 (Code-Verified)
> **Version**: 1.0

---

## Executive Summary

MCP is an AI-powered multi-tenant platform designed to serve the payment processing and merchant services industry. The platform supports a hierarchical ecosystem of **Tenants**, **Resellers**, **Developers**, **Merchants**, and their downstream **Customers** and **Vendors**.

### Key Value Propositions

1. **White-Label Platform**: Tenants can offer fully branded merchant services platforms
2. **AI-Assisted Underwriting**: Automated merchant onboarding with intelligent risk assessment
3. **Multi-Vertical Support**: Payment processing, merchant management, and developer APIs
4. **Compliance-First**: GDPR, KYC/KYB, and PCI-ready architecture

---

## Platform Hierarchy

```
Platform (Infrastructure)
    └── Tenant (Organization - e.g., ISO, Reseller Network)
            ├── Reseller (Sales Partner)
            │       └── Merchant (Business)
            │               ├── Store (Location/Storefront)
            │               ├── Customer (End Consumer)
            │               └── Vendor (Supplier)
            │
            ├── Developer (API Integration Partner)
            │
            └── Merchant (Direct - no reseller)
                    └── ...
```

| Level | Entity | Purpose | Key Features |
|-------|--------|---------|--------------|
| L0 | **Platform** | System infrastructure | Global monitoring, tenant provisioning |
| L1 | **Tenant** | Isolation boundary (PostgreSQL schema) | White-label branding, merchant oversight |
| L2 | **Reseller** | Sales channel partner | Commission tracking, merchant portfolio |
| L2 | **Developer** | API integration partner | Webhooks, API keys, app marketplace |
| L3 | **Merchant** | Business entity | Products, customers, transactions |
| L4 | **Store** | Operating unit | Point-of-sale, invoicing, terminal |
| L4 | **Customer** | End consumer | Order history, subscriptions |
| L4 | **Vendor** | Supplier | Purchase orders, inventory |

---

## Domain Overview

### 1. Accounts Domain

**Purpose**: User authentication and identity management

**Readiness**: ✅ Production Ready

| Feature | Status | Notes |
|---------|--------|-------|
| Email/Password Auth | ✅ Complete | With secure password hashing |
| JWT Sessions | ✅ Complete | Token-based authentication |
| 2FA (TOTP) | ✅ Complete | Backup codes supported |
| OAuth (Google/GitHub) | ✅ Complete | Social login |
| API Keys | ✅ Complete | Developer authentication |
| Account Lockout | ✅ Complete | Failed attempt tracking |
| Registration Requests | ✅ Complete | Self-service onboarding |

**Data Model**:
- `User`: Core identity with email, password hash, 2FA secrets
- `AuthToken`: JWT refresh tokens
- `ApiKey`: Programmatic access credentials
- `RegistrationRequest`: Pending user registrations

**Security Features**:
- Sign-in tracking (IP, timestamp, count)
- Brute-force protection (lockout after failed attempts)
- GDPR fields (deletion, anonymization timestamps)

---

### 2. Platform Domain

**Purpose**: Multi-tenancy, organizational hierarchy, and team management

**Readiness**: ✅ Production Ready

| Feature | Status | Notes |
|---------|--------|-------|
| Tenant Management | ✅ Complete | Per-tenant PostgreSQL schemas |
| Schema Provisioning | ✅ Complete | Auto-creates tenant schemas |
| Reseller Management | ✅ Complete | Commission tracking, branding |
| Developer Management | ✅ Complete | API quotas, webhooks |
| Merchant Management | ✅ Complete | Full business lifecycle |
| Store Management | ✅ Complete | Multi-location support |
| Customer/Vendor | ✅ Complete | B2B and B2C relationships |
| Team & Permissions | ✅ Complete | Role-based access control |
| Custom Domains | ✅ Complete | White-label URLs |
| Data Migration | ✅ Complete | Tenant data portability |

**Tenant Features**:
- **Plans**: Starter, Professional, Enterprise
- **Status Lifecycle**: Active → Suspended → Canceled
- **White-Label**: Custom domains, subdomains, branding
- **Feature Flags**: Per-tenant feature toggles

**Hierarchy Resources**:

| Resource | Scope | Key Relationships |
|----------|-------|-------------------|
| `Tenant` | Global | → Settings, Branding, Account |
| `Reseller` | Tenant | → Developer (parent), Merchants |
| `Developer` | Tenant | → User (owner), Resellers |
| `Merchant` | Tenant | → Reseller, Stores, MIDs |
| `Store` | Merchant | → MID (payment routing) |
| `Customer` | Merchant | → Stores (many-to-many) |
| `Vendor` | Merchant | → Stores (many-to-many) |

**Team System**:
- Permissions: `read`, `write`, `archive`, `create_users`, `create_teams`, `manage_members`
- Scopes: Teams can be assigned to specific entities (merchants, stores)
- Invitations: Email-based with 24-hour expiration

---

### 3. Underwriting Domain

**Purpose**: Merchant onboarding, KYC/KYB verification, risk assessment

**Readiness**: ✅ Production Ready (Core), 🔄 In Progress (Advanced AI)

| Feature | Status | Notes |
|---------|--------|-------|
| Application Processing | ✅ Complete | Full workflow |
| KYC Verification | ✅ Complete | Identity checks |
| KYB Verification | ✅ Complete | Business verification |
| Document Upload | ✅ Complete | S3 storage |
| Risk Scoring | ✅ Complete | Rule-based engine |
| Vendor Integration | ✅ Complete | ComplyCube, Idenfy |
| SLA Tracking | ✅ Complete | Due date calculation |
| Activity Logging | ✅ Complete | Full audit trail |
| Deal Room Notes | ✅ Complete | @mentions support |
| AI Agent System | 🔄 Partial | Blueprint/pipeline framework |
| Atlas Concierge | ✅ Complete | AI chat assistant |
| Magic Camera | ✅ Complete | Mobile document upload |
| Magic Link | ✅ Complete | Save & resume sessions |
| ML Risk Models | ⏳ Planned | Replace rule-based scoring |
| Document Pre-Validation | ⏳ Planned | Quality checks before submit |

**Application Workflow**:
```
draft → submitted → under_review → manual_review → approved
                                 ↘ rejected
                                 ↘ more_info_required
```

**Risk Assessment**:
- **Scoring**: 0-100 scale
- **Recommendation**: `approve` (≥90), `reject` (<50), `manual_review` (50-89)
- **Factors**: KYB results, document verification, credit scoring

**Vendor Adapters**:
| Vendor | Services | Status |
|--------|----------|--------|
| ComplyCube | KYC, KYB, Document | ✅ Implemented |
| Idenfy | Identity verification | ✅ Implemented |
| Mock | Testing | ✅ Available |

**AI/Agent Components**:
- `AgentBlueprint`: Defines AI agent capabilities
- `InstructionSet`: Prompts and instructions
- `Pipeline`: Ordered execution stages
- `Execution`: Runtime context and results
- `Atlas Agent`: Proactive onboarding assistant

---

### 4. OLA Domain (Online Application)

**Purpose**: Self-service merchant application portal

**Readiness**: 🔄 In Development (Actively Building)

| Feature | Status | Notes |
|---------|--------|-------|
| Multi-Step Form | ✅ Complete | 5-step wizard |
| User Registration | ✅ Complete | Account creation |
| Document Upload | ✅ Complete | Validated uploads |
| Application Resume | ✅ Complete | Magic link support |
| Status Tracking | ✅ Complete | Progress display |
| Atlas Chat Integration | ✅ Complete | AI assistance |
| Camera Upload | ✅ Complete | Mobile document capture |
| Schema Definition | ⏳ Planned | Dynamic form builder |

**Form Steps**:
1. Business Information (EIN, business type, address)
2. Owner Details (SSN, ownership %)
3. Document Upload (ID, bank statements, licenses)
4. Banking Information (routing/account numbers)
5. Review & Submit

**Current Implementation**:
- LiveView-based SPA experience
- Real-time validation
- AI-assisted field help via Atlas
- Progress persistence via sessions

---

### 5. Payments Domain

**Purpose**: Transaction processing and payment method management

**Readiness**: ✅ Core Complete, 🔄 Gateway Integration Ongoing

| Feature | Status | Notes |
|---------|--------|-------|
| Charge Processing | ✅ Complete | Create, capture, void |
| Refunds | ✅ Complete | Full and partial |
| Payment Methods | ✅ Complete | Card tokenization |
| Customer Records | ✅ Complete | Payment history |
| Gateway Transactions | ✅ Complete | Audit logging |
| Stripe Adapter | ✅ Complete | Production ready |
| QorPay Adapter | ✅ Complete | Production ready |
| Reactor Workflows | ✅ Complete | Async processing |

**Transaction States**:
```
pending → succeeded → refunded
       ↘ failed
       ↘ voided
```

**Resources**:
| Resource | Purpose |
|----------|---------|
| `Charge` | Payment transaction |
| `Refund` | Reversal transaction |
| `PaymentMethod` | Tokenized card/bank |
| `Customer` | Payment profile |
| `GatewayTransaction` | Provider audit trail |

---

### 6. Finance Domain

**Purpose**: Ledger accounting and fund management

**Readiness**: ✅ Core Complete

| Feature | Status | Notes |
|---------|--------|-------|
| Double-Entry Ledger | ✅ Complete | Immutable entries |
| Account Management | ✅ Complete | Per-tenant/merchant |
| Balance Tracking | ✅ Complete | Real-time totals |
| Fund Transfers | ✅ Complete | Internal movement |
| JSON API | ✅ Complete | REST endpoints |

**Ledger Entry Types**:
- `credit`: Funds added
- `debit`: Funds removed

**Entry States**: `pending` → `cleared` / `failed`

---

### 7. AI Domain

**Purpose**: LLM integration and intelligent features

**Readiness**: 🔄 Active Development

| Feature | Status | Notes |
|---------|--------|-------|
| Chat Interface | ✅ Complete | Ash-based actions |
| Document Embeddings | ✅ Complete | Vector storage |
| Knowledge Base | ✅ Complete | RAG support |
| LLM Usage Tracking | ✅ Complete | Token accounting |
| Semantic Cache | ✅ Complete | Response caching |
| OpenRouter Integration | ✅ Complete | Multi-provider |
| AshAi Integration | ✅ Complete | Framework support |

**Resources**:
| Resource | Purpose |
|----------|---------|
| `Chat` | Conversation action |
| `Document` | Embedded content |
| `LlmUsage` | Token tracking |
| `KnowledgeBase` | Document collections |

**Providers**: Ollama (local), OpenRouter (cloud)

---

### 8. Communication Domain

**Purpose**: Webhooks and external notifications

**Readiness**: ✅ Production Ready

| Feature | Status | Notes |
|---------|--------|-------|
| Webhook Endpoints | ✅ Complete | URL registration |
| Webhook Delivery | ✅ Complete | Retry logic |
| Email Service | ✅ Complete | Transactional email |
| SMS Service | ✅ Complete | Text notifications |
| Push Notifications | ✅ Complete | Mobile alerts |

---

### 9. GDPR Compliance Domain

**Purpose**: Data privacy and regulatory compliance

**Readiness**: ✅ Production Ready

| Feature | Status | Notes |
|---------|--------|-------|
| User Data Export | ✅ Complete | Full data dump |
| Account Deletion | ✅ Complete | With anonymization |
| Consent Management | ✅ Complete | Opt-in tracking |
| Retention Policies | ✅ Complete | Auto-cleanup |
| Audit Trail | ✅ Complete | Change logging |
| Consent Reactor | ✅ Complete | Async workflows |

---

### 10. Audit Domain

**Purpose**: System-wide activity tracking

**Readiness**: ✅ Production Ready

| Feature | Status | Notes |
|---------|--------|-------|
| Version Tracking | ✅ Complete | Change history |
| Admin Interface | ✅ Complete | AshAdmin integration |

---

### 11. Chat Domain

**Purpose**: Real-time messaging within the platform

**Readiness**: ✅ Production Ready

| Feature | Status | Notes |
|---------|--------|-------|
| Conversations | ✅ Complete | Thread management |
| Messages | ✅ Complete | Real-time via PubSub |
| User History | ✅ Complete | Conversation lookup |
| Phoenix Integration | ✅ Complete | LiveView support |

---

## Portal Mapping

| Portal | URL Pattern | Domain Dependencies |
|--------|-------------|---------------------|
| Platform Admin | `admin.platform.com` | Accounts, Platform |
| Tenant Portal | `tenant.{name}.com` | Platform, Underwriting, Finance |
| Reseller Portal | `partners.{name}.com` | Platform, Underwriting |
| Merchant Portal | `app.{name}.com` | Platform, Payments, Finance |
| Store Portal | `app.{name}.com/stores/:slug` | Platform, Payments |
| Customer Portal | `store.{name}.com/account` | Platform, Payments |
| Developer Portal | `developers.{name}.com` | Platform, Accounts |
| OLA Portal | `/online-application` | OLA, Underwriting, Chat |

---

## Readiness Summary

| Domain | Status | Production Ready? |
|--------|--------|-------------------|
| Accounts | ✅ Complete | Yes |
| Platform | ✅ Complete | Yes |
| Underwriting | ✅ Core / 🔄 AI | Mostly |
| OLA | 🔄 In Progress | Beta |
| Payments | ✅ Complete | Yes |
| Finance | ✅ Complete | Yes |
| AI | 🔄 In Progress | Partial |
| Communication | ✅ Complete | Yes |
| GDPR | ✅ Complete | Yes |
| Audit | ✅ Complete | Yes |
| Chat | ✅ Complete | Yes |

**Legend**:
- ✅ Complete: Feature-complete and tested
- 🔄 In Progress: Core functionality works, enhancements ongoing
- ⏳ Planned: Designed but not implemented

---

## Test Coverage

| Domain | Test Files | Key Test Areas |
|--------|------------|----------------|
| Platform | 10 files | Tenants, Teams, Invitations, Migrations |
| Underwriting | 25 files | Gateway, Risk Engine, Atlas, Vendors |
| Accounts | Covered | Auth flows, API keys |
| Payments | Covered | Charges, Refunds, Reactors |

**Total Test Files**: 131

---

## Technical Architecture Notes

### Multi-Tenancy
- **Strategy**: PostgreSQL schema isolation (`acq_{uuid}`)
- **Implementation**: Ash Framework multitenancy with context strategy
- **Data Flow**: Tenant ID in session → schema prefix in queries

### AI Integration
- **Framework**: AshAi with LangChain
- **Providers**: Ollama (self-hosted), OpenRouter (cloud fallback)
- **Pattern**: Agent blueprints + instruction sets → pipeline execution

### Security
- **Authentication**: JWT + 2FA + OAuth
- **Authorization**: Team-based RBAC
- **Encryption**: Cloak/Vaultex for secrets
- **Compliance**: GDPR-ready data handling

---

## Next Steps / Roadmap Gaps

### High Priority
1. **ML Risk Models**: Replace rule-based scoring with trained models
2. **Document Pre-Validation**: Quality checks before submission
3. **Schema Builder**: Dynamic OLA form configuration

### Medium Priority
1. **Pizza Tracker UI**: Visual status timeline for applicants
2. **Drip Campaigns**: Automated stalled-application emails
3. **SLA Countdown**: Visual timers on kanban cards

### Future
1. **PAYFAC Platform**: Sub-merchant management
2. **Graph RAG**: Relationship-based risk analysis
3. **Best Offer Screen**: Payfac ↔ Retail bridging

---

*Document generated from code audit. Source: `lib/mcp/` domain definitions and Ash resources.*
