# MCP Entity Hierarchy and Architecture

The MCP (Multi-Tenant Control Plane) follows a 4-tier hierarchical entity model designed to support complex organizational structures and white-labeled portals.

## 1. The 4-Tier Model

Data isolation and authority are structured into four primary levels:

1.  **Platform (Root)**: The global administrative layer (e.g., `admin.platform.io`). Manages global users, the list of tenants, and system-wide configuration.
2.  **Tenants (Organizations)**: Discrete organizations isolated via Postgres schemas (e.g., `acq_{tenant_slug}`). Tenants are the primary units of billing, custom domains, and administrative policy.
3.  **Intermediate Entities**: Resources that belong to a single tenant and act as containers for further business logic:
    *   **Developers**: Manage API keys and integrations within a tenant.
    *   **Resellers**: Manage portfolios of merchants.
    *   **Merchants**: The primary business entities (e.g., `bobs-burgers.base.do`).
4.  **Sub-Entities (Merchant-Scoped)**: Resources that belong to a specific merchant:
    *   **Stores**: Physical or logical locations (e.g., `north.bobs-burgers.base.do`).
    *   **Customers**: End-users interacting with a merchant (self-registration usually enabled only here).
    *   **Vendors**: Suppliers for a merchant.
    *   **MIDs**: Merchant Identification numbers for payment processing.

## 2. Platform Domain Implementation

The `Mcp.Platform` domain implements the core resources that support this hierarchy:

- **Tenancy**: `Tenant`, `TenantSettings`, `TenantBranding`.
- **Entity Identities**: `Developer`, `Reseller`, `Merchant`, `Customer`, `Vendor`.
- **Hierarchical Links**: `DeveloperTenant`, `ResellerTenant`, `CustomerStore`, `VendorStore`.
- **Units of Operation**: `Store`, `MID`.
- **Shared Data**: `Address`, `Email`, `Phone`.

## 3. Base Core vs. Vertical Extensions

A critical architectural distinction is maintained between the "Base Core" and "Vertical Feature Domains":

1.  **Base Core (Platform)**: The horizontal infrastructure (authentication, multi-tenancy, and basic entity hierarchies) defined in early epics.
2.  **Vertical Extensions**: Specialized business logic layered *on top* of the core:
    *   **Fintech Vertical**: Includes `Underwriting` (Risk/Applications), `Finance` (Ledgers/Credits), and `Payments`.
    *   **Pattern**: Vertical domains reference core Platform entities (e.g., an `Underwriting.Application` belongs to a `Platform.Tenant`).

This separation ensures the platform remains modular and can be re-targeted for different industries by swapping vertical bundles.
