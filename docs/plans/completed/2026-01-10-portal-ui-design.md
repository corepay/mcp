# Portal UI/UX Design Specification

> **Created**: 2026-01-10 | **Status**: In Progress
> **Approach**: UI-first design - build stunning UIs, iterate until perfect, then backfill with implementation

## Executive Summary

This document captures the complete UI/UX design for the MCP platform portals, focusing on the Merchant Portal (admin/backend) and Store Portal (frontend/operations). The design prioritizes operational completeness over MVP minimalism - all features are designed for the superset of business verticals, with vertical-specific profiles controlling visibility.

---

## Design Philosophy

### Core Principles

1. **UI-First Development**: Design the complete interface, see it, iterate, perfect it, then implement
2. **Generic = ALL-Encompassing**: Build the superset of all features; verticals are configuration profiles that show/hide
3. **No Half-Baked Skeletons**: Every screen is designed to production quality, not placeholder wireframes
4. **Operational Quality**: Platform must feel real and capable of running actual businesses

### Vertical Flexibility

The platform supports multiple business types through configuration, not separate codebases:

| Vertical | Key Features |
|----------|--------------|
| Retail | POS, inventory, products, orders |
| Restaurant | Tables, tickets, tips, kitchen display |
| Services | Appointments, time tracking, invoicing |
| Food Truck | Quick checkout, limited menu, mobile-first |
| Professional | Billable hours, projects, retainers |
| Subscription | Recurring billing, members, renewals |

Each vertical is a profile that shows/hides features and adjusts terminology.

---

## Portal Architecture

### Portal Hierarchy

```
Merchant (Business Owner)
    │
    │  configures
    ▼
Store (Operating Unit)
    │
    │  serves
    ▼
Customer (End Consumer)
```

### Mental Model

| Portal | Purpose | User | Navigation Pattern |
|--------|---------|------|-------------------|
| **Merchant Portal** | Admin/Backend - BUILD and CONFIGURE the business | Business owner, operations manager | Top nav + contextual sidebar |
| **Store Portal** | Frontend/Operations - RUN the business day-to-day | Store staff, cashiers, sales team | Left sidebar |

### MID/Store Relationship

```
Merchant (Business Entity)
    │
    ├── MID 1 (QorPay Production)     ←── Payment "pipes"
    │       └── credentials, limits, routing
    │
    ├── MID 2 (Backup / High-Risk)
    │
    ├── Store A (Downtown Location)   ←── Where transactions happen
    │       ├── primary_mid → MID 1
    │       └── fallback_mid_ids → [MID 2]
    │
    └── Store B (Online Shop)
            ├── primary_mid → MID 2
            └── fallback_mid_ids → [MID 1]
```

- **MID** = Gateway credentials, the "pipe" to the processor
- **Store** = Operational unit where transactions occur
- Each Store is assigned a MID for payment routing

---

## Merchant Portal Design

### Shell Structure

**Navigation Pattern**: Top nav + contextual sidebar (like GitHub, Shopify Admin)

**Header Bar (56px)**

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [▾ Acme Corp]    Dashboard    Products    Stores    Payments    Customers [...]│
│                                                           [Search] [?] [🔔] [👤]│
└──────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contents |
|------|----------|
| **Left** | Context Switcher (merchant name + dropdown to stores) |
| **Center** | Main Navigation tabs |
| **Right** | Search (⌘K), Help, Notifications, Avatar menu |

**Context Switcher Dropdown**:
```
[▾ Acme Corp]
  ┌────────────────────┐
  │ ● Acme Corp        │  ← Merchant Portal (current)
  │ ─────────────────  │
  │   Downtown Store   │  ← Jump to store operations
  │   Online Shop      │
  │   Warehouse        │
  │ ─────────────────  │
  │ + New Store        │
  └────────────────────┘
```

**Main Navigation Items**:

| Nav Item | Purpose | Has Sidebar? |
|----------|---------|--------------|
| Dashboard | Aggregate metrics, activity feed, quick actions | No |
| Products | Catalog, pricing, inventory | Yes - categories, filters |
| Stores | List stores, create new, configure each | Yes - store-specific settings |
| Payments | MIDs, transactions, settlements, chargebacks | Yes - filters, date ranges |
| Customers | CRM, customer list, segments | Yes - filters, segments |
| [...] More | Reports, Team, Settings, Integrations | Yes - sub-sections |

**Content Area Behavior**:
- Sections WITHOUT sidebar: Full-width content (Dashboard)
- Sections WITH sidebar: 240px persistent left sidebar + content area
- Sidebar is persistent when in a section (no toggle)

### Merchant Dashboard

**Layout**: Full-width, no sidebar

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Welcome back, Ryan                                        [Today ▾] [Export]│
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ $12,847     │ │ 156         │ │ 89          │ │ $82.35      │            │
│  │ Today's Rev │ │ Transactions│ │ Customers   │ │ Avg Order   │            │
│  │ ↑ 12% vs yd │ │ ↑ 8% vs yd  │ │ ↓ 3% vs yd  │ │ ↑ 5% vs yd  │            │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                                              │
│  ┌─────────────────────────────────┐ ┌──────────────────────────────┐       │
│  │ Revenue (7 days)                │ │ Stores Performance           │       │
│  │ [Chart]                         │ │ Downtown    $6,420  ████████ │       │
│  │                                 │ │ Online      $4,890  ██████   │       │
│  │                                 │ │ Warehouse   $1,537  ███      │       │
│  └─────────────────────────────────┘ └──────────────────────────────┘       │
│                                                                              │
│  ┌─────────────────────────────────┐ ┌──────────────────────────────┐       │
│  │ Recent Transactions             │ │ Needs Attention              │       │
│  │ [Table: Time, Customer, Amount] │ │ ⚠ 3 failed transactions      │       │
│  │                                 │ │ ⚠ MID approaching limit     │       │
│  │                                 │ │ 📋 5 invoices overdue        │       │
│  └─────────────────────────────────┘ └──────────────────────────────┘       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Key Sections**:
- Stat cards: Today's headline metrics with comparison
- Revenue chart: Trend over selected period
- Stores performance: Quick comparison across locations
- Recent transactions: Live feed of activity
- Needs attention: Actionable alerts and issues

### Payments Section

**Layout**: Top nav + persistent sidebar

**Sidebar Structure**:
```
Transactions
Settlements
Payouts

───────────

Chargebacks
├─ Open (3)
├─ Pending Response
└─ History

───────────

MIDs
├─ QorPay Production
├─ QorPay Backup
└─ + Add MID

───────────

Gateway Health
```

| Section | Purpose |
|---------|---------|
| Transactions | All transactions across all stores, search/filter |
| Settlements | Daily batches, settlement status, timing |
| Payouts | Money movement to bank account |
| Chargebacks | Dispute management (merchant-level, not store) |
| MIDs | Gateway account management, credentials, limits |
| Gateway Health | Processor status, success rates, alerts |

---

## Store Portal Design

### Shell Structure

**Navigation Pattern**: Left sidebar (due to feature density)

**Layout**:
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [▾ Downtown Store]                              [Search] [?] [🔔] [Avatar]   │
├─────────────────┬────────────────────────────────────────────────────────────┤
│                 │                                                            │
│  ◉ Dashboard    │                                                            │
│                 │                                                            │
│  SELL           │                     Content Area                           │
│  □ POS          │                                                            │
│  □ Terminal     │                                                            │
│  □ Orders       │                                                            │
│  □ Invoices     │                                                            │
│                 │                                                            │
│  MANAGE         │                                                            │
│  □ Customers    │                                                            │
│  □ Products     │  (read-only reference)                                     │
│  □ Inventory    │                                                            │
│  □ Subscriptions│                                                            │
│  □ Loyalty      │                                                            │
│                 │                                                            │
│  SCHEDULE       │                                                            │
│  □ Appointments │                                                            │
│  □ Tables       │                                                            │
│  □ Staff        │                                                            │
│                 │                                                            │
│  MONEY          │                                                            │
│  □ Refunds      │                                                            │
│  □ Tips         │                                                            │
│  □ Reports      │                                                            │
│                 │                                                            │
│  ───────────    │                                                            │
│  □ Settings     │                                                            │
│  □ Close Shift  │                                                            │
│                 │                                                            │
└─────────────────┴────────────────────────────────────────────────────────────┘
```

**Top Bar (48px)** - Slimmer than Merchant Portal:
- Context switcher (store name + dropdown)
- Search (⌘K)
- Help, Notifications, User menu

**Context Switcher Dropdown**:
```
[▾ Downtown Store]
  ┌────────────────────┐
  │ ← Acme Corp        │  ← Back to Merchant Portal
  │ ─────────────────  │
  │ ● Downtown Store   │  ← Current
  │   Online Shop      │
  │   Warehouse        │
  └────────────────────┘
```

**Left Sidebar (240px)**:
- Grouped by activity type: SELL, MANAGE, SCHEDULE, MONEY
- Groups can collapse
- Icons + labels
- Active state highlight
- Bottom: Settings, Close Shift (always visible)

**Vertical Configuration**:

Sidebar sections show/hide based on store type:

| Section | Retail | Restaurant | Services | Subscription |
|---------|--------|------------|----------|--------------|
| POS | ✓ | ✓ | ✓ | ✓ |
| Terminal | ✓ | ✓ | ✓ | ✓ |
| Orders | ✓ | ✓ | - | - |
| Invoices | ✓ | - | ✓ | ✓ |
| Appointments | - | - | ✓ | - |
| Tables | - | ✓ | - | - |
| Subscriptions | - | - | - | ✓ |
| Inventory | ✓ | ✓ | - | - |
| Loyalty | ✓ | ✓ | ✓ | ✓ |
| Tips | Optional | ✓ | ✓ | - |

### Store Dashboard

**Layout**: Full-width, no sidebar

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Good afternoon                                    Shift: 2:00 PM - Close    │
│                                                                              │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐                │
│  │    $2,847       │ │      34         │ │    $83.74       │                │
│  │  Today's Sales  │ │  Transactions   │ │   Avg Ticket    │                │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘                │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                        QUICK ACTIONS                                  │   │
│  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                │   │
│  │   │  New Sale   │   │  Invoice    │   │  Customer   │                │   │
│  │   │     💳      │   │     📄      │   │   Lookup    │                │   │
│  │   └─────────────┘   └─────────────┘   └─────────────┘                │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────────────────────────────────────┐ ┌─────────────────────────────┐     │
│  │ Recent Transactions                │ │ Pending                     │     │
│  │ 2:34 PM  J. Smith    $124.00  ✓   │ │ 🔔 2 orders ready to ship   │     │
│  │ 2:21 PM  M. Lee       $89.50  ✓   │ │ 📄 1 invoice awaiting pay   │     │
│  │ 2:15 PM  Guest        $42.00  ✓   │ │ ↩️  1 refund request         │     │
│  │ [View All]                         │ │                             │     │
│  └────────────────────────────────────┘ └─────────────────────────────┘     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Key Differences from Merchant Dashboard**:
- Simpler metrics - just today, no trend charts
- Quick actions prominent - big buttons to start common tasks
- Shift context - shows who's working, when
- Pending items - actionable tasks, not just alerts
- No store comparison - you're IN this store

### POS (Point of Sale)

**Layout**: Full-screen focused mode (no sidebar)

**Purpose**: In-person checkout with customer present

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [✕ Exit POS]    Downtown Store                    [Staff: Jamie]  [🔔] [?]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────┐  ┌──────────────────────────────────┐  │
│  │         PRODUCT AREA            │  │           CART                   │  │
│  │                                 │  │                                  │  │
│  │  [Search products...]           │  │  Customer: + Add Customer        │  │
│  │                                 │  │  ─────────────────────────────── │  │
│  │  [Quick Item Buttons Grid]      │  │                                  │  │
│  │                                 │  │  T-Shirt (Blue, L)        $29.99 │  │
│  │  CATEGORIES                     │  │  Qty: 1        [−] [+]    [🗑]   │  │
│  │  [All] [Apparel] [Accessories] │  │                                  │  │
│  │                                 │  │  Coffee Mug              $12.00  │  │
│  │  [Product Grid with Images]     │  │  Qty: 2        [−] [+]    [🗑]   │  │
│  │                                 │  │                                  │  │
│  │                                 │  │  ─────────────────────────────── │  │
│  │                                 │  │  + Add Discount                  │  │
│  │                                 │  │  + Add Note                      │  │
│  │                                 │  │  ─────────────────────────────── │  │
│  │                                 │  │  Subtotal              $53.99    │  │
│  │                                 │  │  Tax (8.25%)            $4.45    │  │
│  │  [Barcode Scan]  [Custom Item] │  │  TOTAL                 $58.44    │  │
│  │                                 │  │                                  │  │
│  └─────────────────────────────────┘  │  [      PAY   $58.44         ]   │  │
│                                       │  [Hold Order]  [Clear Cart]      │  │
│                                       └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

**POS Payment Screen**:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           PAYMENT                              [← Back]      │
├──────────────────────────────────────────────────────────────────────────────┤
│                         Total Due: $58.44                                    │
│                                                                              │
│     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│     │  CARD       │  │  MANUAL     │  │   CASH      │  │   SPLIT     │      │
│     │  READER     │  │  ENTRY      │  │             │  │             │      │
│     │   Tap/Dip   │  │  Key in #   │  │             │  │             │      │
│     └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘      │
│                                                                              │
│     ┌─────────────┐  ┌─────────────┐                                        │
│     │   OTHER     │  │  PAYMENT    │                                        │
│     │  Gift/Check │  │   LINK      │                                        │
│     └─────────────┘  └─────────────┘                                        │
│                                                                              │
│                    [Loyalty: 580 pts (−$5)]  [ ] Apply Points               │
│                    [+ Add Tip]                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Payment Methods**:

| Method | Use Case |
|--------|----------|
| Card Reader | Primary - tap, dip, swipe via hardware |
| Manual Entry | Fallback - key in card number |
| Cash | Bills/coins, calculate change |
| Split | Part card, part cash, multiple cards |
| Other | Gift card, check, store credit |
| Payment Link | Customer pays on their phone |

### Terminal (Virtual Terminal)

**Layout**: Full-screen focused mode (same as POS)

**Purpose**: Invoice builder with immediate payment capability for card-not-present transactions (phone, mail, remote orders)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [✕ Exit Terminal]    Downtown Store               [Staff: Jamie]  [🔔] [?]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────┐  ┌──────────────────────────────────┐  │
│  │         PRODUCT AREA            │  │        ORDER DETAILS             │  │
│  │                                 │  │                                  │  │
│  │  [Search products...]           │  │  Customer: John Smith            │  │
│  │                                 │  │  📧 john@email.com               │  │
│  │  [Quick Item Buttons Grid]      │  │  📱 (555) 123-4567               │  │
│  │                                 │  │  Order Type: Phone Order         │  │
│  │  CATEGORIES                     │  │  ─────────────────────────────── │  │
│  │  [All] [Apparel] [Accessories] │  │                                  │  │
│  │                                 │  │  [Cart Items with Qty Controls]  │  │
│  │  [Product Grid with Images]     │  │                                  │  │
│  │                                 │  │  ─────────────────────────────── │  │
│  │                                 │  │  + Add Discount                  │  │
│  │                                 │  │  + Add Custom Item               │  │
│  │                                 │  │  + Add Note                      │  │
│  │                                 │  │  ─────────────────────────────── │  │
│  │                                 │  │  DELIVERY                        │  │
│  │                                 │  │  ○ Ship to customer              │  │
│  │                                 │  │  ○ Local delivery                │  │
│  │                                 │  │  ○ Customer pickup               │  │
│  │                                 │  │                                  │  │
│  │  [Barcode Scan]  [Custom Item] │  │  Shipping Address: [Edit]        │  │
│  │                                 │  │  Shipping Method: [Standard ▾]   │  │
│  └─────────────────────────────────┘  │  ─────────────────────────────── │  │
│                                       │  Subtotal              $53.99    │  │
│                                       │  Shipping               $8.99    │  │
│                                       │  Tax [CA 8.25% ▾]       $4.45    │  │
│                                       │  TOTAL                 $67.43    │  │
│                                       │                                  │  │
│                                       │  [    CHARGE CARD $67.43     ]   │  │
│                                       │  [Send Payment Link]             │  │
│                                       │  [Save as Quote] [Save as Draft] │  │
│                                       └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

**POS vs Terminal Comparison**:

| Aspect | POS | Terminal |
|--------|-----|----------|
| Context | Customer present | Remote (phone, mail, email) |
| Speed | Optimized for fast checkout | Optimized for completeness |
| Shipping | No - customer takes items | Yes - address, method, cost |
| Billing Address | Not collected | Required for card verification |
| Payment Methods | Card reader, cash, split, manual | Manual entry, payment link |
| Tips | Yes | No |
| Save Options | Hold order | Quote, Draft Invoice |
| Fulfillment | Immediate | Creates order for fulfillment queue |

---

## Visual Design

### Density

**Balanced** - adapts to content (like Shopify Admin)
- Spacious for dashboards and forms
- Compact for data tables and lists

### Theming

**3-tier inheritance model**:
1. Platform Default (app.css)
2. Tenant Override (ThemePlug runtime injection)
3. Merchant Override (white-labeling)

### Design System

Per `docs/DESIGN_GUIDE.md`:
- **Framework**: DaisyUI + Tailwind CSS v4
- **Components**: Use CoreComponents only, never raw HTML
- **Tokens**: Semantic only (bg-primary, text-base-content), no hex values
- **Motion**: Transitions and loading states mandatory

### New CoreComponents Needed

| Component | Purpose |
|-----------|---------|
| `navbar` | Top navigation bar |
| `dropdown` | Context switcher, user menu |
| `sidebar` | Store Portal left nav |
| `stat_card` | Dashboard metrics |
| `tabs` | Horizontal navigation indicator |
| `avatar` | User menu |
| `badge` | Status indicators |
| `skeleton` | Loading states |

---

## Remaining Screens to Design

### Merchant Portal

| Section | Screen | Priority |
|---------|--------|----------|
| **Products** | Product List (grid/table view) | High |
| | Product Detail/Edit | High |
| | Categories Management | Medium |
| | Inventory Overview | Medium |
| **Stores** | Store List | High |
| | Store Configuration | High |
| | Store Creation Wizard | Medium |
| **Payments** | Transactions List | High |
| | Transaction Detail | High |
| | Settlements List | High |
| | Chargeback Detail | Medium |
| | MID Configuration | Medium |
| **Customers** | Customer List | High |
| | Customer Profile | High |
| | Segments/Lists | Medium |
| **Reports** | Sales Reports | Medium |
| | Settlement Reports | Medium |
| | Export/Download | Low |
| **Team** | User Management | Medium |
| | Roles/Permissions | Medium |
| **Settings** | Business Settings | Medium |
| | Branding/White-label | Medium |
| | Integrations | Low |

### Store Portal

| Section | Screen | Priority |
|---------|--------|----------|
| **Orders** | Order Queue | High |
| | Order Detail | High |
| | Fulfillment Flow | High |
| **Invoices** | Invoice List | High |
| | Invoice Builder | High |
| | Invoice Preview/Send | High |
| **Customers** | Customer Lookup | High |
| | Quick Add Customer | High |
| | Customer Profile (read-focused) | Medium |
| **Products** | Product Search/Browse (read-only) | Medium |
| | Quick Lookup | Medium |
| **Inventory** | Stock Levels | Medium |
| | Low Stock Alerts | Medium |
| | Receiving | Low |
| **Subscriptions** | Active Subscriptions | Medium |
| | Subscription Detail | Medium |
| | Renewal/Cancel Flow | Medium |
| **Loyalty** | Points Lookup | Medium |
| | Redemption Flow | Medium |
| | Enrollment | Medium |
| **Appointments** | Calendar View | Medium |
| | Booking Flow | Medium |
| | Check In/Out | Medium |
| **Tables** | Table Map | Low |
| | Assign/Transfer | Low |
| **Staff** | Clock In/Out | Medium |
| | Schedule View | Low |
| | Time Log | Low |
| **Refunds** | Refund Request List | High |
| | Process Refund Flow | High |
| **Tips** | Tip Entry | Medium |
| | Tip Distribution | Low |
| **Reports** | Daily Summary | Medium |
| | Shift Report | Medium |
| | Close Register Flow | Medium |

---

## Implementation Notes

### Component Architecture

```
lib/mcp_web/
├── components/
│   ├── core/           # Pure UI (DaisyUI wrappers)
│   │   ├── core_components.ex
│   │   ├── navigation.ex     # navbar, sidebar, dropdown
│   │   ├── data_display.ex   # stat_card, badge, avatar
│   │   └── feedback.ex       # skeleton, loading states
│   ├── layouts/
│   │   ├── merchant_shell.ex  # Top nav + contextual sidebar
│   │   └── store_shell.ex     # Left sidebar layout
│   └── portals/
│       ├── merchant/          # Merchant-specific components
│       └── store/             # Store-specific components
├── live/
│   ├── merchant/              # Merchant Portal LiveViews
│   └── store/                 # Store Portal LiveViews
```

### Route Structure

```elixir
# Merchant Portal
scope "/app", McpWeb.Merchant do
  pipe_through [:browser, :merchant_layout]

  live "/", DashboardLive
  live "/products", ProductsLive
  live "/stores", StoresLive
  live "/payments", PaymentsLive
  live "/customers", CustomersLive
end

# Store Portal
scope "/app/stores/:store_slug", McpWeb.Store do
  pipe_through [:browser, :store_layout]

  live "/", DashboardLive
  live "/pos", PosLive
  live "/terminal", TerminalLive
  live "/orders", OrdersLive
  live "/invoices", InvoicesLive
end
```

---

## Next Steps

1. **Continue Design Sessions**: Complete remaining screen designs
2. **Component Library**: Build new CoreComponents (navbar, sidebar, etc.)
3. **Shell Implementation**: Build Merchant and Store portal shells
4. **Screen Implementation**: Build screens in priority order
5. **Integration**: Connect to Ash resources and QorPay gateway

---

*Document generated from brainstorming session 2026-01-10*
