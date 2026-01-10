# Platform Entities Documentation

> **Audience**: Product Managers, Business Analysts, Stakeholders
> **Generated**: 2026-01-10 (Code-Verified)

This folder contains detailed documentation for each entity in the MCP platform hierarchy.

## Entity Hierarchy

```
Platform (Infrastructure)
    └── Tenant (Organization)
            ├── Reseller (Sales Partner)
            │       └── Merchant (Business)
            │               ├── MID (Payment Account)
            │               ├── Store (Location)
            │               ├── Customer (End Consumer)
            │               └── Vendor (Supplier)
            │
            ├── Developer (API Partner)
            │
            └── Merchant (Direct)
                    └── ...
```

## Documentation Index

| Entity | Document | Primary Purpose |
|--------|----------|-----------------|
| [Tenant](./TENANT.md) | Organization/ISO | Database isolation, white-labeling |
| [Reseller](./RESELLER.md) | Sales Partner | Merchant acquisition, commissions |
| [Developer](./DEVELOPER.md) | API Integrator | Platform extensions, webhooks |
| [Merchant](./MERCHANT.md) | Business Entity | Core operations, products, payments |
| [MID](./MID.md) | Payment Account | Gateway credentials, processing |
| [Store](./STORE.md) | Operating Unit | Transactions, invoicing, POS |
| [Customer](./CUSTOMER.md) | End Consumer | Orders, subscriptions |
| [Vendor](./VENDOR.md) | Supplier | Supply chain, purchase orders |

## Readiness Legend

Each document uses the following status indicators:

| Symbol | Status | Description |
|--------|--------|-------------|
| ✅ | Complete | Feature is implemented and tested |
| 🔄 | In Progress | Core works, enhancements ongoing |
| ⏳ | Planned | Designed but not yet built |
| 🚫 | Not Started | No implementation exists |
| ⚠️ | Gap | Missing feature that should exist |

## Document Structure

Each entity document follows this structure:

1. **Overview** - What the entity represents and its purpose
2. **Current State** - What's implemented today (code-verified)
3. **Data Model** - Attributes, relationships, statuses
4. **Portal/UI** - Available interfaces and routes
5. **API** - Available endpoints
6. **Gaps** - Missing features identified through audit
7. **Recommendations** - Suggested improvements
8. **Opportunities** - Potential new features

## Cross-References

- [Domain Reference](../DOMAIN_REFERENCE.md) - Technical domain overview
- [Multi-Tenancy Guide](../features/multi-tenancy/hierarchy-and-roles.md) - Portal mapping
- [Underwriting Reference](../UNDERWRITING.md) - Merchant onboarding workflow
