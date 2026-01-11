# Seeded User Logins & Portal Endpoints

## Prerequisites

### Local DNS Setup

The platform uses subdomain-based multi-tenancy. Add to `/etc/hosts`:

```
127.0.0.1 acme.localhost
127.0.0.1 globex.localhost
```

Or run:

```bash
sudo sh -c 'echo "127.0.0.1 acme.localhost" >> /etc/hosts'
sudo sh -c 'echo "127.0.0.1 globex.localhost" >> /etc/hosts'
```

---

## Seeded Users

Created by `mix run priv/repo/seeds.exs`. **Default Password**: `Password123!`

### Platform Admin

| Field | Value |
|-------|-------|
| **User** | `admin@platform.local` |
| **Role** | Super Admin |
| **Access** | Platform Admin Portal |

### Tenant Admins

#### Acme Corp (Subdomain: `acme`)

| Field | Value |
|-------|-------|
| **User** | `admin@acme.local` |
| **Role** | Tenant Owner |
| **Access** | Tenant, Merchant, Store Portals |

#### Globex Corp (Subdomain: `globex`)

| Field | Value |
|-------|-------|
| **User** | `admin@globex.local` |
| **Role** | Tenant Owner |
| **Access** | Tenant, Merchant, Store Portals |

---

## Seeded Merchants & Stores

### Acme Corp

| Merchant | Stores |
|----------|--------|
| Acme Retail (`acme-retail`) | `downtown`, `mall` |
| Acme Online (`acme-online`) | `web` |

### Globex Corp

| Merchant | Stores |
|----------|--------|
| Globex Supplies (`globex-supplies`) | `hq` |

---

## Portal Endpoints

### Platform-Level (no subdomain required)

| Portal | URL | Description |
|--------|-----|-------------|
| **Platform Admin** | `http://localhost:4000/admin` | MCP staff: manage tenants |
| **Online Application** | `http://localhost:4000/online-application` | Public underwriting flow |

### Tenant-Scoped (requires subdomain)

Access via tenant subdomain (e.g., `acme.localhost:4000`):

| Portal | URL | Description |
|--------|-----|-------------|
| **Tenant Portal** | `http://acme.localhost:4000/tenant` | Manage merchants, settings |
| **Merchant Portal** | `http://acme.localhost:4000/app` | Dashboard, products, customers |
| **Store Portal** | `http://acme.localhost:4000/app/stores/:slug` | POS, invoices, store ops |
| **Developer Portal** | `http://acme.localhost:4000/developers` | API keys, documentation |
| **Reseller Portal** | `http://acme.localhost:4000/partners` | ISO/Partner commissions |
| **Vendor Portal** | `http://acme.localhost:4000/vendors` | 3rd-party providers |
| **Customer Portal** | `http://acme.localhost:4000/store/account` | Receipts, subscriptions |

---

## Quick Start

```bash
# 1. Seed the database
mix run priv/repo/seeds.exs

# 2. Start the server
mix phx.server

# 3. Access Merchant Dashboard
open http://acme.localhost:4000/app/sign-in
# Login: admin@acme.local / Password123!
# Navigate to: /app/dashboard

# 4. Access Store Dashboard
open http://acme.localhost:4000/app/stores/downtown/dashboard
```

---

## Key Routes

### Merchant Portal (`/app`)

| Route | Description |
|-------|-------------|
| `/app/sign-in` | Sign in |
| `/app/dashboard` | Merchant dashboard with stats |
| `/app/products` | Product management |
| `/app/customers` | Customer management |
| `/app/orders` | Order management |

### Store Portal (`/app/stores/:slug`)

| Route | Description |
|-------|-------------|
| `/app/stores/downtown/dashboard` | Store dashboard |
| `/app/stores/downtown/terminal` | Virtual terminal |
| `/app/stores/downtown/invoices` | Invoice management |
| `/app/stores/downtown/subscriptions` | Subscription management |

---

## AI Services

| Service | URL | Description |
|---------|-----|-------------|
| **The Eye** | `http://localhost:48291` | Document Intelligence (Internal) |
| **Ollama** | `http://localhost:42736` | Local LLM Inference |

---

## Troubleshooting

### "Tenant not found"

- Use subdomain URL: `acme.localhost:4000` not `localhost:4000`
- Verify `/etc/hosts` has the entry
- Re-run seeds: `mix run priv/repo/seeds.exs`

### Authentication fails

- Password is case-sensitive: `Password123!`
- Clear browser cookies for `localhost`
- Check user exists: `mix run -e "IO.inspect Mcp.Accounts.User.by_email(\"admin@acme.local\")"`
