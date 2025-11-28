# Seeded User Logins & Portal Endpoints

## 🔐 Seeded Users

The following users are created by `priv/repo/seeds.exs`. **Default Password**:
`Password123!`

### Platform Admin

- **User**: `admin@platform.local`
- **Role**: Super Admin
- **Access**: Platform Admin Portal

### Tenant Admins

#### Acme Corp (Slug: `acme`)

- **User**: `admin@acme.local`
- **Role**: Tenant Owner
- **Access**: Tenant Portal

#### Globex Corp (Slug: `globex`)

- **User**: `admin@globex.local`
- **Role**: Tenant Owner
- **Access**: Tenant Portal

---

## 🌐 Portal Endpoints

The MCP platform hosts multiple portals. Here are the entry points:

| Portal                 | URL                                        | Description                                                                                         |
| :--------------------- | :----------------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **Platform Admin**     | `http://localhost:4000/admin`              | For MCP staff to manage tenants and infrastructure.                                                 |
| **Tenant Portal**      | `http://localhost:4000/tenant`             | For Tenant Admins (e.g., Acme) to manage their merchants.                                           |
| **Merchant Portal**    | `http://localhost:4000/app`                | For Merchants to manage orders and products.                                                        |
| **Store Portal**       | `http://localhost:4000/app/stores/:slug`   | For Point-of-Sale and store operations. <br> _Example_: `http://localhost:4000/app/stores/downtown` |
| **Online Application** | `http://localhost:4000/online-application` | Public-facing underwriting application flow.                                                        |
| **Developer Portal**   | `http://localhost:4000/developers`         | For API key management and docs.                                                                    |
| **Reseller Portal**    | `http://localhost:4000/partners`           | For ISOs and Partners to track commissions.                                                         |
| **Vendor Portal**      | `http://localhost:4000/vendors`            | For 3rd-party service providers (KYC, Credit).                                                      |
| **Customer Portal**    | `http://localhost:4000/store/account`      | For end-customers to view receipts/subscriptions.                                                   |

## 🤖 AI Services

| Service     | URL                      | Description                               |
| :---------- | :----------------------- | :---------------------------------------- |
| **The Eye** | `http://localhost:48291` | Document Intelligence Service (Internal). |
| **Ollama**  | `http://localhost:42736` | Local LLM Inference Engine.               |
