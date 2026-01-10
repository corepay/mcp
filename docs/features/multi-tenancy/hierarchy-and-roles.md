# Multi-Tenancy Hierarchy & Portal Roles

This document clarifies the organizational hierarchy of the MCP platform and the distinct purpose of each portal.

## Organizational Hierarchy

The platform follows a strict 4-level hierarchy:

1.  **Platform** (System Level)
    *   The root level. Manages the entire infrastructure, all tenants, and global settings.
2.  **Tenant** (Organization Level)
    *   A distinct isolation boundary (PostgreSQL Schema).
    *   Represents a Reseller, ISO, or Large Organization.
    *   Manages Merchants, Resellers, and Developers within their ecosystem.
3.  **Merchant** (Business Level)
    *   A business entity under a Tenant.
    *   Manages business settings, products, customers, and reporting.
    *   Can have multiple "Stores".
4.  **Store** (Operational Level)
    *   The actual operating unit (e.g., a physical location, an online storefront, a pop-up).
    *   Where transactions happen (Invoicing, Virtual Terminal, Subscriptions).

## Portal Purpose & Intent

Each level has a dedicated portal with a specific user persona and intent.

| Portal | URL Pattern | User Persona | Primary Intent | Key Features |
| :--- | :--- | :--- | :--- | :--- |
| **Platform Admin** | `admin.platform.com` | System Admins | **Infrastructure Management** | Global monitoring, tenant provisioning, system configuration. |
| **Tenant Portal** | `tenant.tenant-name.com` | Tenant Admins | **Ecosystem Management** | Onboarding merchants, managing resellers, configuring tenant-wide branding/settings. |
| **Reseller Portal** | `partners.tenant-name.com` | Resellers / Partners | **Sales & Commissions** | Managing their portfolio of merchants, viewing commission reports. |
| **Merchant Portal** | `app.tenant-name.com` | Business Owners | **Business Administration** | Product catalog management, customer CRM, reporting & analytics, staff management. |
| **Store Portal** | `app.tenant-name.com/stores/:slug` | Store Managers / Staff | **Daily Operations** | **Virtual Terminal**, **Invoicing**, Subscription management, Order fulfillment. |
| **Customer Portal** | `store.tenant-name.com/account` | End Consumers | **Self-Service** | View order history, manage subscriptions, update payment methods. |
| **Developer Portal** | `developers.tenant-name.com` | Integrators | **Technical Integration** | API key management, webhook configuration, app marketplace submissions. |
| **Vendor Portal** | `vendors.merchant-domain.com` | Suppliers | **Supply Chain** | Managing product listings, viewing purchase orders. |

## Key Distinctions

### Merchant Portal vs. Store Portal
*   **Merchant Portal** is for the **"Back Office"**. It's where you define *what* you sell (Products) and *who* you sell to (Customers). It's about high-level management and analysis.
*   **Store Portal** is for the **"Front Line"**. It's where you *actually sell*. It's where a staff member logs in to charge a card, send an invoice, or manage a specific location's operations. A merchant can have many stores (e.g., "Downtown Location", "Online Store", "Pop-up Event"), each with its own Store Portal view.

### Tenant vs. Platform
*   **Platform** owns the code and infrastructure.
*   **Tenant** owns the data and the customer relationships. Tenants are isolated from each other and can be white-labeled to look like their own independent platforms.
