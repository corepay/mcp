# Merchant Portal Features Design

> **Created**: 2026-01-11 | **Status**: Complete Design Specification
> **Portal Route**: `/app/*`
> **User**: Business owner, operations manager
> **Purpose**: Admin/Backend - BUILD and CONFIGURE the business

## Executive Summary

The Merchant Portal is the command center for business owners. It provides full visibility into operations across all stores, with AI-powered insights surfaced at every decision point. The design prioritizes information density and actionability over minimalism.

---

## Navigation Architecture

### Top Navigation Bar (56px)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [▾ Acme Corp]  Dashboard  Products  Stores  Payments  Customers  Orders  [⋯] │
│                                                      [⌘K] [?] [🔔] [👤]      │
└──────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Element | Behavior |
|------|---------|----------|
| Left | Context Switcher | Dropdown to switch between merchant view and individual stores |
| Center | Main Navigation | Tabs with active indicator, overflow menu for additional items |
| Right | Global Actions | ⌘K (Intelligence Bar), Help, Notifications (unread count), User Menu |

### Context Switcher Dropdown

```
┌────────────────────────┐
│ ● Acme Corp            │  ← Current (Merchant Portal)
│ ─────────────────────  │
│ STORES                 │
│   Downtown Store    →  │  ← Opens Store Portal
│   Online Shop       →  │
│   Warehouse         →  │
│ ─────────────────────  │
│ + Create New Store     │
│ ⚙ Manage All Stores    │
└────────────────────────┘
```

### Sidebar Pattern (240px, persistent per section)

Used for sections with subsections. Collapses on mobile.

```
┌─────────────────────┐
│ Section Header      │
│ ─────────────────── │
│ • Active Item       │  ← Highlighted background
│   Item 2            │
│   Item 3            │
│ ─────────────────── │
│ CATEGORY            │  ← Muted label
│   Item 4            │
│   Item 5 (3)        │  ← Count badge
│ ─────────────────── │
│ + Add New           │  ← Action link
└─────────────────────┘
```

---

## Feature Inventory

### Complete Feature List

| Section | Feature | Priority | Sidebar? | LiveView Module |
|---------|---------|----------|----------|-----------------|
| **Dashboard** | Aggregate Overview | P0 | No | `Merchant.DashboardLive` |
| | AI Insights Feed | P0 | No | (component) |
| | Quick Actions | P0 | No | (component) |
| **Products** | Product List | P0 | Yes | `Merchant.Products.IndexLive` |
| | Product Detail/Edit | P0 | Yes | `Merchant.Products.ShowLive` |
| | Product Create | P0 | Yes | `Merchant.Products.NewLive` |
| | Categories | P1 | Yes | `Merchant.Products.CategoriesLive` |
| | Inventory Overview | P1 | Yes | `Merchant.Products.InventoryLive` |
| | Import/Export | P2 | Yes | `Merchant.Products.ImportLive` |
| | Bulk Editor | P2 | Yes | `Merchant.Products.BulkLive` |
| **Stores** | Store List | P0 | Yes | `Merchant.Stores.IndexLive` |
| | Store Configuration | P0 | Yes | `Merchant.Stores.ShowLive` |
| | Store Creation Wizard | P1 | No | `Merchant.Stores.NewLive` |
| | Hardware Management | P2 | Yes | `Merchant.Stores.HardwareLive` |
| **Payments** | Transactions | P0 | Yes | `Merchant.Payments.TransactionsLive` |
| | Transaction Detail | P0 | Yes | `Merchant.Payments.TransactionLive` |
| | Settlements | P1 | Yes | `Merchant.Payments.SettlementsLive` |
| | Payouts | P1 | Yes | `Merchant.Payments.PayoutsLive` |
| | Chargebacks | P1 | Yes | `Merchant.Payments.ChargebacksLive` |
| | Chargeback Detail | P1 | Yes | `Merchant.Payments.ChargebackLive` |
| | MIDs | P1 | Yes | `Merchant.Payments.MidsLive` |
| | Gateway Health | P2 | Yes | `Merchant.Payments.HealthLive` |
| **Customers** | Customer List | P0 | Yes | `Merchant.Customers.IndexLive` |
| | Customer Detail | P0 | Yes | `Merchant.Customers.ShowLive` |
| | Segments | P1 | Yes | `Merchant.Customers.SegmentsLive` |
| | Loyalty Program | P2 | Yes | `Merchant.Customers.LoyaltyLive` |
| **Orders** | Order List | P0 | Yes | `Merchant.Orders.IndexLive` |
| | Order Detail | P0 | Yes | `Merchant.Orders.ShowLive` |
| | Fulfillment Queue | P1 | Yes | `Merchant.Orders.FulfillmentLive` |
| | Returns | P1 | Yes | `Merchant.Orders.ReturnsLive` |
| **Reports** | Sales Report | P1 | Yes | `Merchant.Reports.SalesLive` |
| | Payments Report | P1 | Yes | `Merchant.Reports.PaymentsLive` |
| | Inventory Report | P2 | Yes | `Merchant.Reports.InventoryLive` |
| | Customer Report | P2 | Yes | `Merchant.Reports.CustomersLive` |
| | Custom Reports | P3 | Yes | `Merchant.Reports.CustomLive` |
| **Team** | User List | P1 | Yes | `Merchant.Team.IndexLive` |
| | User Detail | P1 | Yes | `Merchant.Team.ShowLive` |
| | Roles & Permissions | P2 | Yes | `Merchant.Team.RolesLive` |
| | Activity Log | P2 | Yes | `Merchant.Team.ActivityLive` |
| | Invite Flow | P1 | Modal | (component) |
| **Settings** | Business Info | P1 | Yes | `Merchant.Settings.BusinessLive` |
| | Branding | P2 | Yes | `Merchant.Settings.BrandingLive` |
| | Notifications | P2 | Yes | `Merchant.Settings.NotificationsLive` |
| | Integrations | P3 | Yes | `Merchant.Settings.IntegrationsLive` |
| | Billing & Usage | P1 | Yes | `Merchant.Settings.BillingLive` |
| | API & Webhooks | P2 | Yes | `Merchant.Settings.ApiLive` |

---

## 1. Dashboard

### Purpose
Aggregate business health at a glance. Answer: "How is my business doing today/this week?"

### Layout
Template A (Full-Width Dashboard)

### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Welcome back, Ryan                                    [Today ▾]  [Export]   │
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │  $12,847    │ │    156      │ │     89      │ │   $82.35    │            │
│  │ Today's Rev │ │Transactions │ │  Customers  │ │  Avg Order  │            │
│  │  ↑ 12%      │ │  ↑ 8%       │ │  ↓ 3%       │ │  ↑ 5%       │            │
│  │  vs yest.   │ │  vs yest.   │ │  vs yest.   │ │  vs yest.   │            │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ 💡 AI INSIGHT                                                  [Dismiss]││
│  │                                                                         ││
│  │ Revenue is up 12% but customer count is down 3%. You're getting more   ││
│  │ from existing customers. Top driver: 23% increase in repeat purchases. ││
│  │ Consider: Loyalty program promotion could amplify this trend.          ││
│  │                                                                         ││
│  │ [Explore This Insight]  [See Customer Analysis]                        ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌───────────────────────────────────────────┐ ┌──────────────────────────┐ │
│  │ Revenue (Last 7 Days)                     │ │ Store Performance        │ │
│  │                                           │ │                          │ │
│  │      ╭──────────────────────╮             │ │ Downtown    $6,420       │ │
│  │     ╱                        ╲            │ │ ████████████████████     │ │
│  │    ╱                          ╲           │ │ 50% of total             │ │
│  │ ──╯                            ╰──        │ │                          │ │
│  │                                           │ │ Online      $4,890       │ │
│  │ Mon  Tue  Wed  Thu  Fri  Sat  Sun        │ │ ███████████████          │ │
│  │                                           │ │ 38% of total             │ │
│  │                                           │ │                          │ │
│  │                                           │ │ Warehouse   $1,537       │ │
│  │                                           │ │ ██████                   │ │
│  │                                           │ │ 12% of total             │ │
│  │                                           │ │                          │ │
│  │                    [View Full Report →]   │ │        [Compare Stores →]│ │
│  └───────────────────────────────────────────┘ └──────────────────────────┘ │
│                                                                              │
│  ┌───────────────────────────────────────────┐ ┌──────────────────────────┐ │
│  │ Recent Transactions                       │ │ ⚠ Needs Attention        │ │
│  │                                           │ │                          │ │
│  │ 2:34 PM  J. Smith     $124.00  ✓ Paid    │ │ 🔴 3 failed transactions │ │
│  │ 2:21 PM  M. Lee        $89.50  ✓ Paid    │ │    Decline rate: 8%      │ │
│  │ 2:15 PM  Guest         $42.00  ✗ Declined │ │    [Investigate →]       │ │
│  │ 2:08 PM  A. Johnson   $215.00  ✓ Paid    │ │                          │ │
│  │ 1:56 PM  Guest         $67.00  ✓ Paid    │ │ 🟡 MID at 85% limit      │ │
│  │                                           │ │    $85k / $100k monthly  │ │
│  │                      [View All →]         │ │    [Increase Limit →]    │ │
│  │                                           │ │                          │ │
│  │                                           │ │ 📋 5 invoices overdue    │ │
│  │                                           │ │    $2,340 outstanding    │ │
│  │                                           │ │    [Send Reminders →]    │ │
│  └───────────────────────────────────────────┘ └──────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Stat Cards

| Metric | Calculation | Comparison | AI Enhancement |
|--------|-------------|------------|----------------|
| Revenue | Sum of captured transactions | vs same day last week | Trend explanation |
| Transactions | Count of completed transactions | vs same day last week | Volume anomaly detection |
| Customers | Unique customers served | vs same day last week | New vs repeat ratio |
| Avg Order | Revenue / Transactions | vs same day last week | Upsell opportunity detection |

### AI Insights Feed

**Sources:**
- Sales trend analysis (up/down and why)
- Customer behavior changes
- Inventory alerts
- Payment anomalies
- Scheduling/operational insights

**Format:**
- Headline observation
- Supporting data
- Actionable recommendation
- Quick action buttons

### Quick Actions Grid (Mobile-first)

| Action | Icon | Destination |
|--------|------|-------------|
| New Sale | 💳 | Opens POS (store selection if multiple) |
| Add Product | 📦 | Product create form |
| View Orders | 📋 | Orders list filtered to "New" |
| Send Invoice | 📄 | Invoice builder |
| Customer Lookup | 👤 | Customer search |
| Daily Report | 📊 | Sales report for today |

### Data Requirements

```elixir
# Dashboard data query structure
%{
  stats: %{
    revenue_today: Money.t(),
    revenue_comparison: float(),  # percentage change
    transactions_today: integer(),
    transactions_comparison: float(),
    customers_today: integer(),
    customers_comparison: float(),
    avg_order_today: Money.t(),
    avg_order_comparison: float()
  },
  chart_data: [%{date: Date.t(), revenue: Money.t()}],
  store_performance: [%{store: Store.t(), revenue: Money.t(), percentage: float()}],
  recent_transactions: [Transaction.t()],
  needs_attention: [%{type: atom(), count: integer(), value: Money.t() | nil}],
  ai_insight: %{headline: String.t(), body: String.t(), actions: [%{label: String.t(), path: String.t()}]}
}
```

---

## 2. Products

### Sidebar Structure

```
┌─────────────────────┐
│ Products            │
│ ─────────────────── │
│ All Products (156)  │
│ Categories (12)     │
│ Inventory           │
│ ─────────────────── │
│ BULK ACTIONS        │
│   Import            │
│   Export            │
│ ─────────────────── │
│ + Add Product       │
└─────────────────────┘
```

### 2.1 Product List

#### Wireframe (List View)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Products                                    [+ Add]    │
│                    ├─────────────────────────────────────────────────────────┤
│ All Products (156) │  [🔍 Search products, SKUs...]                          │
│ Categories (12)    │  [Category ▾] [Status ▾] [Stock ▾] [Price Range ▾]     │
│ Inventory          ├─────────────────────────────────────────────────────────┤
│ ───────────        │  💡 3 products need attention: 2 low stock, 1 no sales │
│ Import             │     in 30 days. [Review →]                   [Dismiss] │
│ Export             ├─────────────────────────────────────────────────────────┤
│ ───────────        │  [≡ List] [▦ Grid]   Showing 1-25 of 156    [Columns ▾]│
│ + Add Product      │                                                         │
│                    │  ┌─────┬────────┬────────────────────────┬──────┬─────┐│
│                    │  │ □   │ IMAGE  │ PRODUCT ↑              │STATUS│PRICE││
│                    │  ├─────┼────────┼────────────────────────┼──────┼─────┤│
│                    │  │ □   │ [img]  │ Premium Tee            │ ●    │$29  ││
│                    │  │     │        │ SKU: TEE-001           │Active│     ││
│                    │  │     │        │ Apparel • 45 in stock  │      │     ││
│                    │  ├─────┼────────┼────────────────────────┼──────┼─────┤│
│                    │  │ □   │ [img]  │ Coffee Mug             │ ●    │$12  ││
│                    │  │     │        │ SKU: MUG-001           │Active│     ││
│                    │  │     │        │ Drinkware • ⚠ 5 left   │      │     ││
│                    │  ├─────┼────────┼────────────────────────┼──────┼─────┤│
│                    │  │ □   │ [img]  │ Leather Backpack       │ ○    │$89  ││
│                    │  │     │        │ SKU: BAG-001           │Draft │     ││
│                    │  │     │        │ Bags • Not tracked     │      │     ││
│                    │  └─────┴────────┴────────────────────────┴──────┴─────┘│
│                    │                                                         │
│                    │  [Bulk Actions: ▾ Status ▾ Category ▾ Price 🗑 Delete] │
│                    │                                                         │
│                    │  [< Prev] [1] [2] [3] ... [7] [Next >]   25 per page ▾ │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### Wireframe (Grid View)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Same header and filters as above]                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ □              ⋯│  │ □              ⋯│  │ □              ⋯│              │
│  │   ┌─────────┐   │  │   ┌─────────┐   │  │   ┌─────────┐   │              │
│  │   │         │   │  │   │         │   │  │   │         │   │              │
│  │   │  IMAGE  │   │  │   │  IMAGE  │   │  │   │  IMAGE  │   │              │
│  │   │         │   │  │   │         │   │  │   │         │   │              │
│  │   └─────────┘   │  │   └─────────┘   │  │   └─────────┘   │              │
│  │                 │  │                 │  │                 │              │
│  │ Premium Tee     │  │ Coffee Mug      │  │ Leather Backpack│              │
│  │ $29.99          │  │ $12.00          │  │ $89.00          │              │
│  │ ● Active        │  │ ⚠ Low Stock     │  │ ○ Draft         │              │
│  │ 45 in stock     │  │ 5 in stock      │  │ Not tracked     │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ [More cards...] │  │                 │  │                 │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### Row Actions (Hover)

| Action | Icon | Behavior |
|--------|------|----------|
| Edit | ✏️ | Navigate to edit page |
| Duplicate | 📋 | Create copy with "Copy of" prefix |
| View in Store | 🔗 | Open product URL (if published) |
| Archive | 📁 | Move to archived status |
| Delete | 🗑 | Confirm modal, then delete |

#### AI Row Expansion

Click row to expand inline AI analysis:

```
│ □   │ [img]  │ Premium Tee            │ ●    │$29  │ [⌄]  │
├─────┴────────┴────────────────────────┴──────┴─────┴──────┤
│                                                           │
│  🤖 AI PRODUCT ANALYSIS                                   │
│  ────────────────────────────────────────────────────────│
│                                                           │
│  📈 SALES VELOCITY: 45 units/month (top 10% of catalog)  │
│  💰 MARGIN: 60% ($18 profit per unit)                    │
│  📆 PEAK SALES: Weekends (68% of volume)                 │
│  👥 BUYER PROFILE: 25-34, urban, repeat customers        │
│                                                           │
│  💡 OPPORTUNITIES:                                        │
│  • Bundle with Coffee Mug - adds $8 to AOV               │
│  • Price could increase $2-3 without demand impact       │
│  • Consider size restock - Large sells 2x faster         │
│                                                           │
│  [View Full Analytics]  [Create Bundle]  [Adjust Price]  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

#### Filter Options

| Filter | Type | Options |
|--------|------|---------|
| Category | Multi-select | All categories + "Uncategorized" |
| Status | Multi-select | Active, Draft, Archived |
| Stock Level | Select | All, In Stock, Low Stock, Out of Stock |
| Price Range | Range | Min/Max inputs |
| Has Variants | Toggle | Yes/No |
| Created | Date Range | Last 7/30/90 days, Custom |

#### Bulk Actions

| Action | Behavior |
|--------|----------|
| Set Status | Change status of selected products |
| Set Category | Assign/change category for selected |
| Adjust Price | Increase/decrease by % or $ amount |
| Delete | Remove selected (with confirmation) |
| Export | Download as CSV with selected fields |

### 2.2 Product Detail / Edit

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Products]                             [Save Draft]  [Preview]  [Publish]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  ┌─────────────┐                                                        ││
│  │  │             │  Premium Tee                            ● Active       ││
│  │  │   [IMAGE]   │  SKU: TEE-001  •  Created Jan 5, 2026                 ││
│  │  │             │  Last sold: 2 hours ago  •  45 in stock               ││
│  │  │  ○ ○ ○ ○    │                                                        ││
│  │  └─────────────┘                                                        ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  [Details] [Variants] [Inventory] [Pricing] [SEO] [Activity]                │
│  ═══════════════════════════════════════════════════════════════════════════│
│                                                                              │
│  ┌─────────────────────────────────────────────┐  ┌────────────────────────┐│
│  │ BASIC INFORMATION                           │  │ 🤖 AI INSIGHTS         ││
│  │                                             │  │                        ││
│  │ Title *                                     │  │ Top performer in your  ││
│  │ ┌─────────────────────────────────────────┐ │  │ catalog. 45 sold this  ││
│  │ │ Premium Tee                             │ │  │ month.                 ││
│  │ └─────────────────────────────────────────┘ │  │                        ││
│  │                                             │  │ 📈 +23% vs last month  ││
│  │ Description                                 │  │ 👥 Popular: ages 25-34 ││
│  │ ┌─────────────────────────────────────────┐ │  │ 💡 Price could be $32  ││
│  │ │ [Rich text editor with formatting]      │ │  │                        ││
│  │ │                                         │ │  │ [Deep Dive →]          ││
│  │ │                                         │ │  └────────────────────────┘│
│  │ │                                         │ │                            │
│  │ └─────────────────────────────────────────┘ │  ┌────────────────────────┐│
│  │                                             │  │ QUICK ACTIONS          ││
│  │ Category                                    │  │                        ││
│  │ ┌──────────────────────────────────────┐    │  │ [📋 Duplicate]         ││
│  │ │ Apparel                           ▾  │    │  │ [🔗 View in Store]     ││
│  │ └──────────────────────────────────────┘    │  │ [📁 Archive]           ││
│  │                                             │  │                        ││
│  │ Tags                                        │  └────────────────────────┘│
│  │ ┌─────────────────────────────────────────┐ │                            │
│  │ │ [cotton ×] [summer ×] [bestseller ×]   │ │  ┌────────────────────────┐│
│  │ │ [+ Add tag]                            │ │  │ INVENTORY              ││
│  │ └─────────────────────────────────────────┘ │  │                        ││
│  │                                             │  │ Downtown    15 units   ││
│  │ Vendor                                      │  │ Online      20 units   ││
│  │ ┌──────────────────────────────────────┐    │  │ Warehouse   10 units   ││
│  │ │ Acme Suppliers                       │    │  │ ─────────────────────  ││
│  │ └──────────────────────────────────────┘    │  │ Total       45 units   ││
│  │                                             │  │                        ││
│  └─────────────────────────────────────────────┘  │ [Adjust Stock]         ││
│                                                   └────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ MEDIA                                                    [Reorder Mode] ││
│  │                                                                         ││
│  │ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐││
│  │ │           │ │           │ │           │ │                           │││
│  │ │  [IMAGE]  │ │  [IMAGE]  │ │  [IMAGE]  │ │    + Add Image            │││
│  │ │           │ │           │ │           │ │    or drag files          │││
│  │ │  Primary  │ │           │ │           │ │                           │││
│  │ └───────────┘ └───────────┘ └───────────┘ └───────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ PRICING                                                                 ││
│  │                                                                         ││
│  │ Price *                    Compare at price                             ││
│  │ ┌─────────────────┐        ┌─────────────────┐                          ││
│  │ │ $ 29.99         │        │ $ 39.99         │                          ││
│  │ └─────────────────┘        └─────────────────┘                          ││
│  │                                                                         ││
│  │ Cost per item              Profit             Margin                    ││
│  │ ┌─────────────────┐        $17.99             60%                       ││
│  │ │ $ 12.00         │                                                     ││
│  │ └─────────────────┘                                                     ││
│  │                                                                         ││
│  │ ☑ Charge tax on this product                                           ││
│  │ ☐ This is a physical product (requires shipping)                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### Tabs Detail

**Details Tab:**
- Title, description, category, tags, vendor
- Media gallery with drag-to-reorder
- Basic pricing

**Variants Tab:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ VARIANTS                                                    [+ Add Option]  │
│                                                                             │
│ Options                                                                     │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Size:    [S] [M] [L] [XL] [+ Add]                                     │  │
│ │ Color:   [Blue] [Black] [White] [+ Add]                               │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ Variant Matrix (12 variants)                                                │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ VARIANT              │ SKU          │ PRICE  │ STOCK │ ACTIONS        │  │
│ ├──────────────────────┼──────────────┼────────┼───────┼────────────────┤  │
│ │ S / Blue             │ TEE-001-S-BL │ $29.99 │ 10    │ [Edit] [⋯]     │  │
│ │ S / Black            │ TEE-001-S-BK │ $29.99 │ 8     │ [Edit] [⋯]     │  │
│ │ M / Blue             │ TEE-001-M-BL │ $29.99 │ 15    │ [Edit] [⋯]     │  │
│ │ ...                  │              │        │       │                │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ [Bulk Edit Variants]                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Inventory Tab:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ INVENTORY                                                                   │
│                                                                             │
│ ☑ Track inventory for this product                                         │
│ ☐ Continue selling when out of stock                                       │
│                                                                             │
│ Stock by Location                                                           │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ LOCATION        │ ON HAND │ COMMITTED │ AVAILABLE │ ADJUST           │  │
│ ├─────────────────┼─────────┼───────────┼───────────┼──────────────────┤  │
│ │ Downtown Store  │ 15      │ 2         │ 13        │ [+] [-]          │  │
│ │ Online          │ 20      │ 5         │ 15        │ [+] [-]          │  │
│ │ Warehouse       │ 10      │ 0         │ 10        │ [+] [-]          │  │
│ ├─────────────────┼─────────┼───────────┼───────────┼──────────────────┤  │
│ │ TOTAL           │ 45      │ 7         │ 38        │                  │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ Reorder Settings                                                            │
│ Low stock alert when:  [10] units remaining                                 │
│ Reorder point:         [20] units                                           │
│ Reorder quantity:      [50] units                                           │
│                                                                             │
│ 💡 AI: Based on sales velocity (45/month), reorder 15 days before stockout │
└─────────────────────────────────────────────────────────────────────────────┘
```

**SEO Tab:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SEARCH ENGINE OPTIMIZATION                                                  │
│                                                                             │
│ Page Title                                                                  │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Premium Tee - Acme Corp                                               │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│ 32 of 60 characters                                                         │
│                                                                             │
│ Meta Description                                                            │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Our best-selling premium cotton tee. Comfortable, durable, and...    │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│ 78 of 160 characters                                                        │
│                                                                             │
│ URL Handle                                                                  │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ premium-tee                                                           │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│ https://acmecorp.com/products/premium-tee                                   │
│                                                                             │
│ [✨ Generate with AI]  ← Auto-generates title, description, handle          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Categories

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Categories                             [+ Add Category]│
│                    ├─────────────────────────────────────────────────────────┤
│ All Products       │                                                         │
│ ● Categories (12)  │  ┌─────────────────────────────────────────────────────┐│
│ Inventory          │  │ ⋮⋮ Apparel (45)                              [Edit] ││
│                    │  │    ├── T-Shirts (23)                                ││
│                    │  │    ├── Hoodies (12)                                 ││
│                    │  │    └── Accessories (10)                             ││
│                    │  ├─────────────────────────────────────────────────────┤│
│                    │  │ ⋮⋮ Drinkware (28)                            [Edit] ││
│                    │  │    ├── Mugs (18)                                    ││
│                    │  │    └── Bottles (10)                                 ││
│                    │  ├─────────────────────────────────────────────────────┤│
│                    │  │ ⋮⋮ Bags (15)                                 [Edit] ││
│                    │  ├─────────────────────────────────────────────────────┤│
│                    │  │ ⋮⋮ Electronics (8)                           [Edit] ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  Drag categories to reorder. Drag onto another to nest.│
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Inventory Overview

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Inventory                              [+ Adjust Stock]│
│                    ├─────────────────────────────────────────────────────────┤
│ All Products       │  [🔍 Search...]  [Location ▾] [Stock Level ▾]           │
│ Categories         ├─────────────────────────────────────────────────────────┤
│ ● Inventory        │  🚨 5 products below reorder point. Value at risk:      │
│ ───────────        │     $2,340. [Create Purchase Order →]        [Dismiss] │
│ Low Stock (5)      ├─────────────────────────────────────────────────────────┤
│ Out of Stock (2)   │                                                         │
│ Overstocked (3)    │  ┌──────────────────────────────────────────────────────┐│
│ ───────────        │  │ PRODUCT        │ DOWNTOWN │ ONLINE │ WAREHOUSE│TOTAL││
│ Incoming           │  ├────────────────┼──────────┼────────┼──────────┼─────┤│
│ History            │  │ Premium Tee    │ 15       │ 20     │ 10       │ 45  ││
│                    │  │                │          │        │          │     ││
│                    │  │ ⚠ Coffee Mug   │ 2        │ 3      │ 0        │ 5   ││
│                    │  │   Below reorder point (20)│        │          │     ││
│                    │  │                │          │        │          │     ││
│                    │  │ 🔴 Backpack    │ 0        │ 0      │ 0        │ 0   ││
│                    │  │   On order: 50 │ Due: Jan 15       │          │     ││
│                    │  │                │          │        │          │     ││
│                    │  │ ⚠ Water Bottle │ 3        │ 2      │ 0        │ 5   ││
│                    │  │   Below reorder│          │        │          │     ││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  💡 AI: Based on sales velocity, Backpack will be back │
│                    │     in stock Jan 15. Coffee Mug needs immediate reorder.│
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Customers

### Sidebar Structure

```
┌─────────────────────┐
│ Customers           │
│ ─────────────────── │
│ All Customers (2.8k)│
│ ─────────────────── │
│ SEGMENTS            │
│   VIP (127)         │
│   At Risk (23)      │
│   New (89)          │
│   Repeat (456)      │
│   + Create Segment  │
│ ─────────────────── │
│ Loyalty             │
│ ─────────────────── │
│ + Add Customer      │
└─────────────────────┘
```

### 3.1 Customer List

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Customers                                [+ Add]       │
│                    ├─────────────────────────────────────────────────────────┤
│ All (2,847)        │  [🔍 Search by name, email, phone...]                   │
│ ───────────        │  [Segment ▾] [Location ▾] [Last Order ▾] [LTV ▾]       │
│ SEGMENTS           ├─────────────────────────────────────────────────────────┤
│   VIP (127)        │  💡 12 VIP customers haven't ordered in 45+ days.      │
│   At Risk (23)     │     [Send Re-engagement Campaign →]         [Dismiss]  │
│   New (89)         ├─────────────────────────────────────────────────────────┤
│   Repeat (456)     │                                                         │
│ ───────────        │  ┌────────────────────────────────────────────────────┐ │
│ Loyalty            │  │ CUSTOMER           │ LTV      │ ORDERS │ LAST     │ │
│ ───────────        │  ├────────────────────┼──────────┼────────┼──────────┤ │
│ + Add              │  │ 👤 John Smith      │ $4,250   │ 23     │ 2d ago   │ │
│                    │  │   john@email.com   │ ⭐ VIP   │        │          │ │
│                    │  ├────────────────────┼──────────┼────────┼──────────┤ │
│                    │  │ 👤 Maria Garcia    │ $1,890   │ 12     │ 45d ago  │ │
│                    │  │   maria@email.com  │ ⚠ Risk  │        │ ⚠        │ │
│                    │  ├────────────────────┼──────────┼────────┼──────────┤ │
│                    │  │ 👤 Alex Johnson    │ $245     │ 2      │ 7d ago   │ │
│                    │  │   alex@email.com   │ 🆕 New   │        │          │ │
│                    │  └────────────────────┴──────────┴────────┴──────────┘ │
│                    │                                                         │
│                    │  [< Prev] [1] [2] [3] [Next >]   Showing 1-25 of 2,847 │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### AI Row Expansion

```
│ 👤 Maria Garcia    │ $1,890   │ 12     │ 45d ago  │ [⌄]  │
├────────────────────┴──────────┴────────┴──────────┴──────┤
│                                                          │
│ 🤖 CUSTOMER INTELLIGENCE                                │
│ ─────────────────────────────────────────────────────────│
│                                                          │
│ ⚠ CHURN RISK: HIGH                                      │
│                                                          │
│ Maria typically orders every 18 days but hasn't ordered │
│ in 45 days. This is unusual for her pattern.            │
│                                                          │
│ BEHAVIORAL INSIGHTS:                                     │
│ • Prefers premium products                              │
│ • Peak buying: First week of month                      │
│ • Responds well to email (42% open rate)                │
│ • Average order: $157                                   │
│                                                          │
│ 💡 RECOMMENDED ACTION:                                   │
│ Send personalized "We miss you" email with 15% off.     │
│ Based on her history, this has 68% chance of conversion.│
│                                                          │
│ [Send Re-engagement Email]  [View Full Profile]         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 3.2 Customer Detail

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Customers]                        [Edit]  [Create Order]  [Send Message]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ ┌──────┐                                                                ││
│  │ │  JS  │  John Smith                                    ⭐ VIP Customer ││
│  │ └──────┘  john@email.com  •  (555) 123-4567  •  Since Jan 2024         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  [Overview] [Orders (23)] [Subscriptions (2)] [Notes (5)] [Activity]        │
│  ═══════════════════════════════════════════════════════════════════════════│
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │  $4,250     │ │    23       │ │  $184.78    │ │   580 pts   │            │
│  │ Lifetime    │ │  Orders     │ │ Avg Order   │ │  Loyalty    │            │
│  │ Value       │ │             │ │             │ │  Points     │            │
│  │ Top 5%      │ │ ↑3 this mo  │ │ ↑12% vs avg │ │ = $58 value │            │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                                              │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────────┐│
│  │ 🤖 AI CUSTOMER SUMMARY             │  │ CONTACT INFO                     ││
│  │                                    │  │                                  ││
│  │ John is a high-value customer who  │  │ 📧 john@email.com                ││
│  │ orders every 2-3 weeks, typically  │  │ 📱 (555) 123-4567                ││
│  │ on weekends.                       │  │ 📍 123 Main St                   ││
│  │                                    │  │    New York, NY 10001            ││
│  │ KEY PATTERNS:                      │  │                                  ││
│  │ • Prefers premium products         │  │ [Edit Contact Info]              ││
│  │ • Peak buying: Saturday afternoons │  └──────────────────────────────────┘│
│  │ • Responds to 10-15% discounts     │                                      │
│  │ • Often buys matching items        │  ┌──────────────────────────────────┐│
│  │                                    │  │ QUICK ACTIONS                    ││
│  │ NEXT ORDER PREDICTION:             │  │                                  ││
│  │ ~3 days (based on 18-day cycle)    │  │ [📧 Send Email]                  ││
│  │                                    │  │ [🛒 Create Order]                ││
│  │ [Ask AI About This Customer]       │  │ [🎁 Send Gift Card]              ││
│  └────────────────────────────────────┘  │ [📝 Add Note]                    ││
│                                          │ [🏷️ Add to Segment]              ││
│  ┌────────────────────────────────────┐  │                                  ││
│  │ PURCHASE HISTORY CHART             │  └──────────────────────────────────┘│
│  │                                    │                                      │
│  │  $400 │    ╭╮                      │  ┌──────────────────────────────────┐│
│  │       │   ╱  ╲   ╭╮               │  │ SEGMENTS                         ││
│  │  $200 │  ╱    ╲ ╱  ╲  ╭─          │  │                                  ││
│  │       │ ╱      ╳    ╲╱            │  │ ⭐ VIP                            ││
│  │  $0   │╱                          │  │ 🔄 Repeat Buyer                  ││
│  │       └───────────────────────    │  │ 👔 Premium Shopper               ││
│  │       Jan  Feb  Mar  Apr  May     │  │                                  ││
│  └────────────────────────────────────┘  │ [+ Add to Segment]               ││
│                                          └──────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ RECENT ORDERS                                               [View All →]││
│  │                                                                         ││
│  │ ┌────────────┬────────────┬──────────┬─────────────────┬───────────────┐││
│  │ │ ORDER      │ DATE       │ TOTAL    │ STATUS          │ ITEMS         │││
│  │ ├────────────┼────────────┼──────────┼─────────────────┼───────────────┤││
│  │ │ #1234      │ Jan 8      │ $124.00  │ ✓ Delivered     │ 3 items       │││
│  │ │ #1198      │ Dec 22     │ $89.50   │ ✓ Delivered     │ 2 items       │││
│  │ │ #1156      │ Dec 5      │ $215.00  │ ✓ Delivered     │ 5 items       │││
│  │ │ #1089      │ Nov 18     │ $178.00  │ ✓ Delivered     │ 4 items       │││
│  │ └────────────┴────────────┴──────────┴─────────────────┴───────────────┘││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Segment Builder

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Create Segment                                              [Cancel] [Save]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Segment Name *                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ High-Value At-Risk Customers                                             ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  Description                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ Customers with LTV > $1000 who haven't purchased in 30+ days            ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ CONDITIONS                                                               ││
│  │ ─────────────────────────────────────────────────────────────────────────││
│  │ Customers who match ALL of these conditions:                             ││
│  │                                                                          ││
│  │ ┌────────────────────────────────────────────────────────────────────┐  ││
│  │ │ [Lifetime Value ▾] [is greater than ▾] [$1,000        ]       [✕] │  ││
│  │ └────────────────────────────────────────────────────────────────────┘  ││
│  │                                    AND                                   ││
│  │ ┌────────────────────────────────────────────────────────────────────┐  ││
│  │ │ [Last Order Date ▾] [is more than ▾] [30 days ago    ]        [✕] │  ││
│  │ └────────────────────────────────────────────────────────────────────┘  ││
│  │                                                                          ││
│  │ [+ Add Condition]                                                        ││
│  │                                                                          ││
│  │ ─────────────────────────────────────── OR ─────────────────────────────││
│  │                                                                          ││
│  │ [+ Add OR Group]                                                         ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ PREVIEW                                               23 customers match ││
│  │ ─────────────────────────────────────────────────────────────────────────││
│  │                                                                          ││
│  │ John Smith      •  $4,250 LTV  •  Last order: 45 days ago               ││
│  │ Maria Garcia    •  $1,890 LTV  •  Last order: 38 days ago               ││
│  │ Alex Kim        •  $1,245 LTV  •  Last order: 32 days ago               ││
│  │ [+ 20 more customers]                                                    ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ 💡 AI SUGGESTION                                                         ││
│  │                                                                          ││
│  │ Consider adding "Email engagement < 14 days" to focus on customers who  ││
│  │ are both valuable AND haven't engaged with your emails. This narrows to ││
│  │ 15 customers with 72% predicted response rate.                          ││
│  │                                                                          ││
│  │ [Apply Suggestion]                                                       ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Payments

### Sidebar Structure

```
┌─────────────────────────┐
│ Payments                │
│ ─────────────────────── │
│ Transactions            │
│ Settlements             │
│ Payouts                 │
│ ─────────────────────── │
│ DISPUTES                │
│   Open (3)              │
│   Pending Response (1)  │
│   Won/Lost              │
│ ─────────────────────── │
│ GATEWAY                 │
│   MIDs                  │
│   Gateway Health        │
└─────────────────────────┘
```

### 4.1 Transactions

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Transactions                          [Export] [⋮]     │
│                    ├─────────────────────────────────────────────────────────┤
│ ● Transactions     │  [🔍 Search by ID, customer, amount, card...]          │
│ Settlements        │  [Date: Today ▾] [Status ▾] [Store ▾] [Amount ▾]       │
│ Payouts            ├─────────────────────────────────────────────────────────┤
│ ───────────        │  🚨 Decline rate spiked to 8% (avg: 2%). Likely cause: │
│ Open (3)           │     Card network issue on Visa. [See Details →]        │
│ Pending (1)        ├─────────────────────────────────────────────────────────┤
│ Won/Lost           │                                                         │
│ ───────────        │  ┌─────────────────────────────────────────────────────┐│
│ MIDs               │  │ TIME     │ CUSTOMER    │ AMOUNT  │ STATUS │ STORE  ││
│ Gateway Health     │  ├──────────┼─────────────┼─────────┼────────┼────────┤│
│                    │  │ 2:34 PM  │ John Smith  │ $124.00 │ ✓ Paid │Downtown││
│                    │  │          │ ****1234    │         │        │        ││
│                    │  ├──────────┼─────────────┼─────────┼────────┼────────┤│
│                    │  │ 2:21 PM  │ Maria Lee   │ $89.50  │ ✓ Paid │ Online ││
│                    │  │          │ ****5678    │         │        │        ││
│                    │  ├──────────┼─────────────┼─────────┼────────┼────────┤│
│                    │  │ 2:15 PM  │ Guest       │ $42.00  │ ✗ Decl │Downtown││
│                    │  │          │ ****9012 [▼ EXPANDED]                   ││
│                    │  │ ┌───────────────────────────────────────────────┐  ││
│                    │  │ │ 💳 DECLINE ANALYSIS                           │  ││
│                    │  │ │                                               │  ││
│                    │  │ │ Decline Code: 51 - Insufficient Funds         │  ││
│                    │  │ │ Card: Visa ****9012 (Debit)                   │  ││
│                    │  │ │ AVS: Match  •  CVV: Match                     │  ││
│                    │  │ │                                               │  ││
│                    │  │ │ 🤖 AI ANALYSIS:                               │  ││
│                    │  │ │ This is the 3rd decline today from cards     │  ││
│                    │  │ │ ending 9012. Pattern suggests the customer   │  ││
│                    │  │ │ has reached their debit card daily limit.    │  ││
│                    │  │ │                                               │  ││
│                    │  │ │ SUGGESTED ACTIONS:                            │  ││
│                    │  │ │ • Send payment link for alternative method   │  ││
│                    │  │ │ • Offer to split into smaller amounts        │  ││
│                    │  │ │                                               │  ││
│                    │  │ │ [Send Payment Link]  [View Card History]      │  ││
│                    │  │ └───────────────────────────────────────────────┘  ││
│                    │  ├──────────┼─────────────┼─────────┼────────┼────────┤│
│                    │  │ 2:08 PM  │ Alex Kim    │ $215.00 │ ◐ Auth │ Online ││
│                    │  │          │ ****3456    │         │        │        ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  [< Prev] [1] [2] [3] [Next >]   Showing 1-50 of 1,234 │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Transaction Detail

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Transactions]                                          [Refund] [Void]    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Transaction #TXN-2026011-12345                            ✓ Paid            │
│  Jan 11, 2026 at 2:34 PM  •  Downtown Store  •  Staff: Jamie                │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                                                                         ││
│  │                           $124.00                                       ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  [Details] [Customer] [Timeline] [Related]                                  │
│  ═══════════════════════════════════════════════════════════════════════════│
│                                                                              │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────────┐│
│  │ PAYMENT METHOD                     │  │ 🤖 AI ANALYSIS                   ││
│  │                                    │  │                                  ││
│  │ 💳 Visa ****1234                   │  │ ✓ LOW FRAUD RISK                 ││
│  │                                    │  │                                  ││
│  │ Type: Credit                       │  │ This transaction matches the     ││
│  │ Auth Code: 123456                  │  │ customer's typical behavior:     ││
│  │ Network: Visa                      │  │ • Similar amount to past orders  ││
│  │                                    │  │ • Same card used previously      ││
│  │ AVS Result: ✓ Match                │  │ • Consistent location            ││
│  │ CVV Result: ✓ Match                │  │                                  ││
│  │ 3DS: Not required                  │  │ No action needed.                ││
│  │                                    │  │                                  ││
│  └────────────────────────────────────┘  └──────────────────────────────────┘│
│                                                                              │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────────┐│
│  │ CUSTOMER                           │  │ ORDER ITEMS                      ││
│  │                                    │  │                                  ││
│  │ 👤 John Smith                      │  │ Premium Tee (L, Blue)   $29.99  ││
│  │    john@email.com                  │  │ Coffee Mug (x2)         $24.00  ││
│  │    VIP Customer • $4,250 LTV       │  │ Leather Backpack        $70.01  ││
│  │                                    │  │ ─────────────────────────────── ││
│  │ [View Customer Profile →]          │  │ Subtotal               $124.00  ││
│  │                                    │  │ Tax (included)           $8.89  ││
│  │                                    │  │ Total                  $124.00  ││
│  └────────────────────────────────────┘  └──────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ TIMELINE                                                                ││
│  │                                                                         ││
│  │ ● 2:34:00 PM   Authorization requested                                 ││
│  │ │                                                                       ││
│  │ ● 2:34:02 PM   Authorization approved (code: 123456)                   ││
│  │ │                                                                       ││
│  │ ● 2:34:02 PM   Capture completed                                       ││
│  │ │                                                                       ││
│  │ ● 2:34:05 PM   Receipt sent to john@email.com                          ││
│  │ │                                                                       ││
│  │ ○ Pending      Settlement (expected: Jan 12)                           ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Settlements

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Settlements                                [Export]    │
│                    ├─────────────────────────────────────────────────────────┤
│ Transactions       │  [Date Range ▾] [MID ▾] [Status ▾]                      │
│ ● Settlements      ├─────────────────────────────────────────────────────────┤
│ Payouts            │                                                         │
│                    │  ┌──────────────────────────────────────────────────────┐│
│                    │  │ DATE       │ MID        │ GROSS    │ FEES  │ NET    ││
│                    │  ├────────────┼────────────┼──────────┼───────┼────────┤│
│                    │  │ Jan 11     │ QorPay     │ $12,450  │ $312  │$12,138 ││
│                    │  │ Today      │            │ 156 txns │ 2.5%  │ ◐ Pend ││
│                    │  │            │            │          │       │        ││
│                    │  │ ─ Breakdown:                                        ││
│                    │  │   Visa: $8,200 (102 txns)                           ││
│                    │  │   Mastercard: $3,100 (42 txns)                      ││
│                    │  │   Amex: $1,150 (12 txns)                            ││
│                    │  ├────────────┼────────────┼──────────┼───────┼────────┤│
│                    │  │ Jan 10     │ QorPay     │ $10,890  │ $272  │$10,618 ││
│                    │  │            │            │ 142 txns │ 2.5%  │ ✓ Settl││
│                    │  │            │            │          │       │ → Bank ││
│                    │  ├────────────┼────────────┼──────────┼───────┼────────┤│
│                    │  │ Jan 9      │ QorPay     │ $11,230  │ $281  │$10,949 ││
│                    │  │            │            │ 148 txns │ 2.5%  │ ✓ Settl││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌──────────────────────────────────────────────────────┐│
│                    │  │ 💡 AI INSIGHT                                        ││
│                    │  │                                                      ││
│                    │  │ Your effective rate this week is 2.48%, down from   ││
│                    │  │ 2.52% last week. This is due to a higher proportion ││
│                    │  │ of Visa debit transactions which have lower fees.   ││
│                    │  │                                                      ││
│                    │  │ [View Fee Analysis →]                                ││
│                    │  └──────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.4 Chargebacks

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Chargebacks                                            │
│                    ├─────────────────────────────────────────────────────────┤
│ Transactions       │  [Status ▾] [Date ▾] [Amount ▾]                         │
│ Settlements        ├─────────────────────────────────────────────────────────┤
│ Payouts            │                                                         │
│ ───────────        │  🚨 1 chargeback requires response by Jan 15 (3 days). │
│ ● Open (3)         │     [Respond Now →]                                     │
│ Pending (1)        ├─────────────────────────────────────────────────────────┤
│ Won/Lost           │                                                         │
│                    │  ┌──────────────────────────────────────────────────────┐│
│                    │  │ DISPUTE     │ AMOUNT  │ REASON        │ DEADLINE    ││
│                    │  ├─────────────┼─────────┼───────────────┼─────────────┤│
│                    │  │ #CB-12345   │ $245.00 │ Not Received  │ ⚠ Jan 15   ││
│                    │  │ Filed: Jan 8│         │               │ (3 days)    ││
│                    │  │             │         │               │ [Respond →] ││
│                    │  ├─────────────┼─────────┼───────────────┼─────────────┤│
│                    │  │ #CB-12344   │ $89.00  │ Not Described │ Jan 20      ││
│                    │  │ Filed: Jan 6│         │               │ (8 days)    ││
│                    │  │             │         │               │ [Respond →] ││
│                    │  ├─────────────┼─────────┼───────────────┼─────────────┤│
│                    │  │ #CB-12343   │ $156.00 │ Fraud         │ ◐ Awaiting  ││
│                    │  │ Filed: Jan 4│         │               │ Decision    ││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌──────────────────────────────────────────────────────┐│
│                    │  │ 📊 CHARGEBACK STATS (Last 30 Days)                   ││
│                    │  │                                                      ││
│                    │  │ Total: 5  •  Won: 2  •  Lost: 1  •  Pending: 2      ││
│                    │  │ Rate: 0.4%  (Industry avg: 0.6%)                    ││
│                    │  │                                                      ││
│                    │  │ 💡 Your win rate is 67% which is above average.    ││
│                    │  └──────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.5 MIDs (Gateway Accounts)

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  MIDs (Merchant IDs)                      [+ Add MID]   │
│                    ├─────────────────────────────────────────────────────────┤
│ Transactions       │                                                         │
│ Settlements        │  ┌─────────────────────────────────────────────────────┐│
│ Payouts            │  │ 🟢 QorPay Production                      [Active]  ││
│ ───────────        │  │                                                     ││
│ Open (3)           │  │ MID: 1234567890                                     ││
│ Pending (1)        │  │ Gateway: QorPay  •  Status: Live                    ││
│ Won/Lost           │  │                                                     ││
│ ───────────        │  │ MONTHLY VOLUME                                      ││
│ ● MIDs             │  │ ████████████████████████░░░░░░░  $85,230 / $100,000 ││
│ Gateway Health     │  │                                  85% utilized       ││
│                    │  │                                                     ││
│                    │  │ Transactions: 1,234 this month                      ││
│                    │  │ Assigned to: Downtown Store, Online Shop            ││
│                    │  │                                                     ││
│                    │  │ [Configure]  [View Transactions]  [Pause]           ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌─────────────────────────────────────────────────────┐│
│                    │  │ 🟡 QorPay Backup                          [Standby] ││
│                    │  │                                                     ││
│                    │  │ MID: 0987654321                                     ││
│                    │  │ Gateway: QorPay  •  Status: Ready                   ││
│                    │  │                                                     ││
│                    │  │ MONTHLY VOLUME                                      ││
│                    │  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  $0 / $50,000        ││
│                    │  │                                  0% utilized        ││
│                    │  │                                                     ││
│                    │  │ Fallback for: Downtown Store, Online Shop           ││
│                    │  │                                                     ││
│                    │  │ [Configure]  [Test Connection]  [Remove]            ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌─────────────────────────────────────────────────────┐│
│                    │  │ 💡 AI ALERT                                          ││
│                    │  │                                                      ││
│                    │  │ QorPay Production is at 85% of monthly limit. At    ││
│                    │  │ current velocity, you'll hit the limit by Jan 18.   ││
│                    │  │                                                      ││
│                    │  │ Options:                                             ││
│                    │  │ • Request limit increase (typically 3-5 days)       ││
│                    │  │ • Activate backup MID for overflow                  ││
│                    │  │                                                      ││
│                    │  │ [Request Limit Increase]  [Activate Backup]         ││
│                    │  └─────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Stores

### 5.1 Store List

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Stores                                   [+ Add Store] │
│                    ├─────────────────────────────────────────────────────────┤
│ ● All Stores       │                                                         │
│ ───────────        │  ┌─────────────────────────────────────────────────────┐│
│ Downtown Store →   │  │ 🏪 DOWNTOWN STORE                          ● Open   ││
│ Online Shop →      │  │                                                     ││
│ Warehouse →        │  │ 123 Main Street, New York, NY 10001                 ││
│ ───────────        │  │ Hours: 9 AM - 9 PM  •  Staff on shift: 4            ││
│ + Add Store        │  │                                                     ││
│                    │  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     ││
│                    │  │ │   $6,420    │ │     78      │ │   $82.31    │     ││
│                    │  │ │ Today's Rev │ │   Txns      │ │  Avg Order  │     ││
│                    │  │ │  ↑ 8%       │ │  ↑ 12%      │ │  ↓ 3%       │     ││
│                    │  │ └─────────────┘ └─────────────┘ └─────────────┘     ││
│                    │  │                                                     ││
│                    │  │ [Open Dashboard →]         [Configure]  [⋯]         ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌─────────────────────────────────────────────────────┐│
│                    │  │ 🌐 ONLINE SHOP                            ● Online  ││
│                    │  │                                                     ││
│                    │  │ www.acmecorp.com/shop                               ││
│                    │  │ 24/7  •  No staff assigned                          ││
│                    │  │                                                     ││
│                    │  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     ││
│                    │  │ │   $4,890    │ │     62      │ │   $78.87    │     ││
│                    │  │ │ Today's Rev │ │   Txns      │ │  Avg Order  │     ││
│                    │  │ │  ↑ 23%      │ │  ↑ 18%      │ │  ↑ 5%       │     ││
│                    │  │ └─────────────┘ └─────────────┘ └─────────────┘     ││
│                    │  │                                                     ││
│                    │  │ [Open Dashboard →]         [Configure]  [⋯]         ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌─────────────────────────────────────────────────────┐│
│                    │  │ 💡 AI INSIGHT                                        ││
│                    │  │                                                      ││
│                    │  │ Downtown Store is 15% below forecast today. Weather ││
│                    │  │ data shows rain which typically reduces foot traffic ││
│                    │  │ by 20%. Online Shop is compensating with +23%.       ││
│                    │  │                                                      ││
│                    │  │ [View Weather Impact Analysis →]                     ││
│                    │  └─────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Store Configuration

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Stores]                        Downtown Store              [Save Changes] │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  [General] [Payments] [Hardware] [Staff] [Settings]                         │
│  ═══════════════════════════════════════════════════════════════════════════│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ GENERAL INFORMATION                                                     ││
│  │                                                                         ││
│  │ Store Name *                                                            ││
│  │ ┌─────────────────────────────────────────────────────────────────────┐ ││
│  │ │ Downtown Store                                                      │ ││
│  │ └─────────────────────────────────────────────────────────────────────┘ ││
│  │                                                                         ││
│  │ Store Type                                                              ││
│  │ ┌─────────────────────────────────────────────────────────────────────┐ ││
│  │ │ Retail (Physical) ▾                                                 │ ││
│  │ └─────────────────────────────────────────────────────────────────────┘ ││
│  │                                                                         ││
│  │ Address                                                                 ││
│  │ ┌─────────────────────────────────────────────────────────────────────┐ ││
│  │ │ 123 Main Street                                                     │ ││
│  │ └─────────────────────────────────────────────────────────────────────┘ ││
│  │ ┌──────────────────┐ ┌──────────────┐ ┌─────────────────────────────┐  ││
│  │ │ New York         │ │ NY ▾         │ │ 10001                       │  ││
│  │ └──────────────────┘ └──────────────┘ └─────────────────────────────┘  ││
│  │                                                                         ││
│  │ Phone                                Contact Email                      ││
│  │ ┌───────────────────────────┐       ┌───────────────────────────────┐  ││
│  │ │ (555) 123-4567            │       │ downtown@acmecorp.com         │  ││
│  │ └───────────────────────────┘       └───────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ OPERATING HOURS                                                         ││
│  │                                                                         ││
│  │ ┌───────────────┬──────────────────────────────────────────────────────┐││
│  │ │ Monday        │ ○ Closed   ● Open  [9:00 AM ▾] to [9:00 PM ▾]      │ ││
│  │ │ Tuesday       │ ○ Closed   ● Open  [9:00 AM ▾] to [9:00 PM ▾]      │ ││
│  │ │ Wednesday     │ ○ Closed   ● Open  [9:00 AM ▾] to [9:00 PM ▾]      │ ││
│  │ │ Thursday      │ ○ Closed   ● Open  [9:00 AM ▾] to [9:00 PM ▾]      │ ││
│  │ │ Friday        │ ○ Closed   ● Open  [9:00 AM ▾] to [10:00 PM ▾]     │ ││
│  │ │ Saturday      │ ○ Closed   ● Open  [10:00 AM ▾] to [10:00 PM ▾]    │ ││
│  │ │ Sunday        │ ● Closed   ○ Open                                  │ ││
│  │ └───────────────┴──────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 6-8. Orders, Reports, Team, Settings

*(Abbreviated for document length - follows same detailed patterns)*

### Orders
- List with status tabs (New, Processing, Ready, Shipped, Completed)
- Detail view with line items, shipping, payment, timeline
- Kanban view option
- Fulfillment batch actions

### Reports
- Sales: Period comparison, store breakdown, product performance
- Payments: Volume, fees, methods, decline analysis
- Customers: Acquisition, retention, LTV trends
- Inventory: Stock levels, turnover, dead stock
- Custom: Build your own with saved views

### Team
- User list with role badges
- Invite flow with role selection
- Role templates (Owner, Admin, Manager, Staff, Custom)
- Activity log with filters

### Settings
- Business: Legal name, tax IDs, addresses
- Branding: Logo, colors, email templates
- Notifications: Email/SMS preferences
- Integrations: Accounting, shipping, marketing
- Billing: Subscription, usage metrics, invoices
- API: Keys, webhooks, logs

---

## AI Integration Patterns

### Intelligence Bar (⌘K)

Available on every page with context-aware queries.

| Context | Example Queries | Action |
|---------|-----------------|--------|
| Dashboard | "show failed transactions" | Navigate to filtered view |
| Products | "low stock items" | Filter products by stock |
| Customers | "john smith" | Jump to customer profile |
| Payments | "declines today" | Filter transactions |
| Any | "create invoice for acme" | Open invoice builder |

### Proactive Insights

Each page can show AI insights when relevant:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 💡 AI INSIGHT                                                    [Dismiss] │
│                                                                             │
│ [Observation with data]                                                     │
│ [Root cause or pattern]                                                     │
│ [Actionable recommendation]                                                 │
│                                                                             │
│ [Primary Action]  [Secondary Action]                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Micro-AI (Row Expansion)

Tables support row expansion to show AI analysis:

```
│ [Row data...]                                                    [⌄] │
├──────────────────────────────────────────────────────────────────────┤
│ 🤖 AI ANALYSIS                                                       │
│                                                                      │
│ [Key metrics]                                                        │
│ [Patterns detected]                                                  │
│ [Recommendations]                                                    │
│                                                                      │
│ [Action Button 1]  [Action Button 2]                                │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Empty States

Each list view has a designed empty state:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                              [Illustration]                                  │
│                                                                             │
│                         No products yet                                     │
│                                                                             │
│                  Add your first product to start selling.                   │
│                                                                             │
│                         [+ Add Product]                                     │
│                                                                             │
│                     or [Import from CSV]                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Requirements

### Required New Components

| Component | Usage | Props |
|-----------|-------|-------|
| `page_header` | Every page top | title, actions, breadcrumbs |
| `section_sidebar` | List views | items, active, collapsed |
| `data_table` | All lists | columns, rows, sortable, expandable |
| `card_grid` | Products, stores | items, columns, selectable |
| `filter_bar` | List views | filters, search, view_toggle |
| `insight_card` | AI insights | message, actions, dismissable |
| `micro_ai_panel` | Row expansion | content, actions |
| `stat_card` | Dashboards | value, label, trend, comparison |
| `empty_state` | Empty lists | icon, title, description, action |
| `timeline` | Detail views | events, expandable |

---

## Implementation Priority

| Phase | Features | Estimated Scope |
|-------|----------|-----------------|
| 1 | Dashboard, Products (list/detail), Customers (list/detail) | Foundation |
| 2 | Payments (transactions, settlements), Orders (list/detail) | Commerce |
| 3 | Stores, Inventory, Categories | Operations |
| 4 | Reports, Chargebacks, MIDs | Analytics |
| 5 | Team, Settings, Integrations | Administration |

---

*Document generated 2026-01-11 - Complete Merchant Portal specification*
