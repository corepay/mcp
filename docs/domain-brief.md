# Domain Brief - AI-Powered MSP Platform

## Core Functional Requirements

### Authentication & Authorization

**Hierarchy Authentication Requirements:**
- **Primary Authentication**: Email & password with 2FA
- **Social OAuth**: Google and GitHub integration only
- **All Entity Types**: Email/password + 2FA + optional Google/GitHub OAuth
- **Customer**: Email + merchant_id authentication (allows customers to be customers of multiple merchants without cross-merchant visibility)
- **No SAML**: Simplified authentication stack across all levels

**Authorization Architecture:**
- **Teams-based permissions**: Feature-based (read, write, archive)
- **Hierarchical scopes**: Entities assigned downstream in hierarchy
- **GitHub-like invitation system**: Permission to create/invite teams and members

**Example Scenarios:**
- Tenant administrator creates "Support" team
- Support team assigned to specific merchants in portfolio
- Support team has permissions to create users within assigned scope
- Teams can be granted access to specific entities at any hierarchy level

**Multi-Tenancy Data Architecture:**
- **Per-tenant database schemas** with polymorphic common entities
- **No geographic data isolation required**
- **Cross-level data visibility rules** for hierarchical access

**Shared Resources Model:**
- **Payment Gateways**: Shared catalog available to all tenants/developers/resellers/merchants
- **AI Models**: Shared resources available across tenant boundaries
- **Compliance Rules**: Shared framework applicable to all levels

**Payment Gateway Architecture:**
- Multiple payment gateways available in shared catalog
- MIDs are merchant-specific and must select a payment gateway during creation
- Payment processing is MID + gateway specific (not tenant-level)

**Entity Hierarchy & Relationships:**
- **Developer**: Can belong to one or many tenants
- **Reseller**: Can belong to one or many tenants
- **Merchant**: Can only belong to a single tenant
- **Merchant → MIDs**: One merchant can have multiple MIDs
- **Merchant → Customers**: One merchant can have multiple customers
- **Merchant → Products**: One merchant can have multiple products
- **Merchant → Stores**: One merchant can create multiple stores
- **Store**: Logical grouping of customers and products
- **Customer → Stores**: One customer can belong to many stores
- **Product → Stores**: Products can be associated with stores

**Data Ownership Model:**
- Core data (customers, products, etc.) assigned to merchant
- Store associations for logical grouping/segmentation
- Example store groupings: by product category (clothes vs shoes) or by region (West vs East US)

**Schema Management:**
- **Automatic schema creation** per tenant during onboarding
- **Tenant creation permissions**: Only platform users with proper permissions can create tenants
- **Schema definition**: Defined via slug/parameter during tenant onboarding process

**Cross-Tenant Visibility Rules:**

**Reseller Model:**
- Resellers sell merchant accounts on behalf of tenants
- Resellers have their own portfolio of merchants
- **Reseller visibility**: Can see merchant payment processing data (MIDs, gateways, volume) ONLY
- **Reseller restrictions**: CANNOT see merchant business data (customers, products, pricing, PII)
- **Tenant visibility**: Can see their resellers' business data and user data, but no PII

**Developer Invitation Model:**
- **Email-based invitations**: Tenant admin invites developer for API integration
- **24-hour expiration**: Invitations expire after 24 hours if not accepted
- **Revoke/Refresh**: Tenant can revoke pending invitations or refresh expired ones
- **Tenant-defined permissions**: Tenant defines permissions and scope during invitation process
- **Developer scope**: Limited to tenant-defined permissions and data boundaries upon acceptance

**Data Isolation Boundaries:**
- **Merchant business data**: Customers, products, pricing, PII - private to merchant only
- **Payment processing data**: MIDs, gateways, volume - visible to tenant + assigned reseller
- **Reseller business data**: Business operations, user management - visible to tenant (no PII)

**User Creation & Assignment Model:**

**Initial Admin User Pattern:**
- Each entity (Tenant, Developer, Reseller, Merchant, Store) gets exactly one initial admin user
- Initial admin has full scope and permissions for that entity + all direct children
- No multi-user complexity at entity creation

**Store User Assignment:**
- When merchant creates a store, merchant can assign users to that store
- Store users have permissions scoped to that specific store only
- Store users cannot access other stores or merchant-level data

**Hierarchical Permission Inheritance:**
- Entity admin inherits permissions over direct children
- Example: Merchant admin can access all their stores and store data
- Example: Store admin can only access their specific store

**Permission Model:**
- Permissions: read, write, archive, create_users, create_teams, manage_members
- Scopes: Platform → Tenant → Developer/Reseller → Merchant → MIDs → Stores
- Teams can have mixed permissions and multiple scope assignments
- API keys define developer access boundaries per tenant
- Single admin per entity with full entity + children scope