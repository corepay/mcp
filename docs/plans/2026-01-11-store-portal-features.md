# Store Portal Features Design

> **Created**: 2026-01-11 | **Status**: Complete Design Specification
> **Portal Route**: `/app/stores/:store_slug/*`
> **User**: Store staff, cashiers, shift managers
> **Purpose**: Frontend/Operations - RUN the business day-to-day

## Executive Summary

The Store Portal is the operational command center for staff working in a specific store. It prioritizes speed, simplicity, and task completion. Every feature is optimized for the reality of serving customers while managing operations. AI assists by surfacing relevant information at the right moment.

---

## Navigation Architecture

### Top Header Bar (48px - Slimmer than Merchant)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [▾ Downtown Store]                               [⌘K] [?] [🔔] [👤 Jamie]    │
└──────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Element | Behavior |
|------|---------|----------|
| Left | Context Switcher | Switch stores or return to Merchant Portal |
| Right | Global Actions | Intelligence Bar, Help, Notifications, User Menu |

### Context Switcher Dropdown

```
┌──────────────────────────┐
│ ← Acme Corp              │  ← Return to Merchant Portal
│ ────────────────────────│
│ STORES                   │
│ ● Downtown Store         │  ← Current (highlighted)
│   Online Shop            │
│   Warehouse              │
└──────────────────────────┘
```

### Left Sidebar (240px, persistent)

```
┌─────────────────────────┐
│                         │
│  ◉ Dashboard            │  ← Active highlight
│                         │
│  SELL                   │  ← Group label (muted)
│  □ POS                  │
│  □ Terminal             │
│  □ Orders               │
│  □ Invoices             │
│                         │
│  MANAGE                 │
│  □ Customers            │
│  □ Products             │  ← Read-only badge
│  □ Inventory            │
│  □ Subscriptions        │
│  □ Loyalty              │
│                         │
│  SCHEDULE               │  ← Vertical-dependent
│  □ Appointments         │
│  □ Tables               │
│  □ Staff                │
│                         │
│  MONEY                  │
│  □ Refunds              │
│  □ Tips                 │
│  □ Reports              │
│                         │
│  ─────────────────────  │
│  □ Settings             │
│  □ Close Shift          │  ← Always visible
│                         │
└─────────────────────────┘
```

### Vertical Configuration

Sidebar items show/hide based on store vertical:

| Feature | Retail | Restaurant | Services | Subscription |
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
| Tips | ○ | ✓ | ✓ | - |

---

## Page Layout Templates

All content pages follow one of five layout templates. Every page has a **Stats Row** at the top showing key metrics for that context. The Store Portal uses the persistent left sidebar for navigation.

### Template A: Full-Width Dashboard

Used for: Dashboard, Reports with cards/charts

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Left Sidebar]     │                                                         │
│                    │  Page Title                             [Date] [Export] │
│ ◉ Dashboard        │                                                         │
│                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│ SELL               │  │ Stat 1  │ │ Stat 2  │ │ Stat 3  │ │ Stat 4  │       │
│   POS              │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │
│   Terminal         │                                                         │
│   Orders           │  ┌─────────────────────────────────────────────────────┐│
│   ...              │  │                                                     ││
│                    │  │           Full-Width Content Area                   ││
│ MANAGE             │  │     (Quick Actions, Cards, Charts, Grids)           ││
│   Customers        │  │                                                     ││
│   ...              │  └─────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Template B: 2/3 + 1/3 Split (List View)

Used for: List pages with contextual actions

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Left Sidebar]     │                                                         │
│                    │  Page Title                       [Search] [+ Add New]  │
│   Dashboard        │                                                         │
│                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│ SELL               │  │ Stat 1  │ │ Stat 2  │ │ Stat 3  │ │ Stat 4  │       │
│   POS              │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │
│   Terminal         │                                                         │
│ • Orders           │  ┌─────────────────────────────────┐ ┌─────────────────┐│
│   Invoices         │  │                                 │ │ QUICK ACTIONS   ││
│   ...              │  │        Main Content (2/3)       │ │                 ││
│                    │  │                                 │ │ [New Order]     ││
│                    │  │   List / Table / Cards          │ │ [Quick Lookup]  ││
│                    │  │   - Row 1                       │ │                 ││
│                    │  │   - Row 2                       │ │ ─────────────── ││
│                    │  │   - Row 3                       │ │ FILTERS         ││
│                    │  │   ...                           │ │ [Status ▾]      ││
│                    │  │                                 │ │                 ││
│                    │  │                                 │ │ ─────────────── ││
│                    │  │                                 │ │ AI INSIGHTS     ││
│                    │  │                                 │ │ 💡 2 ready      ││
│                    │  └─────────────────────────────────┘ └─────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Template C: 2/3 + 1/3 Split (Detail View)

Used for: Detail pages with contextual actions

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Left Sidebar]     │                                                         │
│                    │  ← Back          Order #1234                    [···]   │
│   Dashboard        │                                                         │
│                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│ SELL               │  │ Total   │ │ Items   │ │ Status  │ │ Time    │       │
│   POS              │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │
│   Terminal         │                                                         │
│ • Orders           │  ┌─────────────────────────────────┐ ┌─────────────────┐│
│   Invoices         │  │                                 │ │ ACTIONS         ││
│   ...              │  │        Main Content (2/3)       │ │                 ││
│                    │  │                                 │ │ [Mark Ready]    ││
│                    │  │   Detail Information            │ │ [Print Ticket]  ││
│                    │  │   - Order items                 │ │ [Refund]        ││
│                    │  │   - Customer info               │ │                 ││
│                    │  │   - Payment info                │ │ ─────────────── ││
│                    │  │                                 │ │ CUSTOMER        ││
│                    │  │   Timeline / Activity           │ │ John Smith      ││
│                    │  │   - Created at...               │ │ 12 orders       ││
│                    │  │   - Paid at...                  │ │ [View Profile]  ││
│                    │  └─────────────────────────────────┘ └─────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Template D: Full-Width Table

Used for: Dense data needing all columns visible

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Left Sidebar]     │                                                         │
│                    │  Page Title                       [Filter] [Export]     │
│   Dashboard        │                                                         │
│                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│ MANAGE             │  │ Stat 1  │ │ Stat 2  │ │ Stat 3  │ │ Stat 4  │       │
│   Customers        │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │
│   Products         │                                                         │
│ • Inventory        │  [Search...                    ] [Category ▾] [Stock ▾] │
│   ...              │                                                         │
│                    │  ┌─────────────────────────────────────────────────────┐│
│                    │  │ SKU    │ Product  │ On Hand │ Reserved │ Available ││
│                    │  │────────│──────────│─────────│──────────│───────────││
│                    │  │ SKU001 │ Widget A │ 45      │ 3        │ 42        ││
│                    │  │ SKU002 │ Widget B │ 12      │ 0        │ 12        ││
│                    │  │ SKU003 │ Gadget X │ 0       │ 0        │ 0  ⚠️     ││
│                    │  │ ...    │ ...      │ ...     │ ...      │ ...       ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │  Showing 1-25 of 234                        [< 1 2 3 >] │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Template E: Focused Mode

Used for: POS, Terminal, Invoice Builder - No sidebar, maximum focus

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ← Exit                        POS                            [⌘K] [👤 Jamie] │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────┐ ┌──────────────────────────┐│
│  │                                             │ │                          ││
│  │          Full-Height Left Panel             │ │   Full-Height Right      ││
│  │                                             │ │         Panel            ││
│  │   (Product Grid / Form / Content)           │ │                          ││
│  │                                             │ │   (Cart / Summary)       ││
│  │                                             │ │                          ││
│  │                                             │ │                          ││
│  │                                             │ │   ┌──────────────────┐   ││
│  │                                             │ │   │  [Pay $124.00]   │   ││
│  │                                             │ │   └──────────────────┘   ││
│  └─────────────────────────────────────────────┘ └──────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Template F: Full-Width Calendar/Map

Used for: Appointments, Tables, Schedule - Visual layouts needing full space

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Left Sidebar]     │                                                         │
│                    │  Appointments          [Today] [< Week >] [+ New]       │
│   Dashboard        │                                                         │
│                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│ SCHEDULE           │  │ Today   │ │ This Wk │ │ Pending │ │ Revenue │       │
│ • Appointments     │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │
│   Tables           │                                                         │
│   Staff            │  ┌─────────────────────────────────────────────────────┐│
│   ...              │  │  9am │ 10am │ 11am │ 12pm │ 1pm │ 2pm │ 3pm │ 4pm  ││
│                    │  │──────│──────│──────│──────│─────│─────│─────│──────││
│                    │  │      │▓▓▓▓▓▓│▓▓▓▓▓▓│      │     │▓▓▓▓▓│▓▓▓▓▓│      ││
│                    │  │      │ Smith│ Smith│      │     │ Lee │ Lee │      ││
│                    │  │──────│──────│──────│──────│─────│─────│─────│──────││
│                    │  │▓▓▓▓▓▓│      │      │▓▓▓▓▓▓│▓▓▓▓▓│     │     │▓▓▓▓▓▓││
│                    │  │ Chen │      │      │ Park │ Park│     │     │ Jones││
│                    │  └─────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Layout Selection Guide

| Layout | Use When | Examples |
|--------|----------|----------|
| **A: Full-Width Dashboard** | Cards, charts, overview | Dashboard, Reports |
| **B: 2/3 + 1/3 List** | List with actions sidebar | Orders, Invoices, Customers |
| **C: 2/3 + 1/3 Detail** | Detail with actions | Order Detail, Customer Card |
| **D: Full-Width Table** | Dense data, many columns | Inventory, Time Log |
| **E: Focused Mode** | Single-purpose, no distractions | POS, Terminal, Invoice Builder |
| **F: Calendar/Map** | Visual layouts | Appointments, Tables, Schedule |

---

## Feature Inventory

### Complete Feature List

| Section | Feature | Priority | Layout | LiveView Module |
|---------|---------|----------|--------|-----------------|
| **Dashboard** | Shift Overview | P0 | A (Dashboard) | `Store.DashboardLive` |
| | Quick Actions | P0 | (component) | |
| | Today's Stats | P0 | (component) | |
| | Pending Items | P0 | (component) | |
| **POS** | Point of Sale | P0 | E (Focused) | `Store.PosLive` |
| | Product Grid | P0 | (component) | |
| | Cart | P0 | (component) | |
| | Payment Flow | P0 | (component) | |
| | Receipt | P0 | (component) | |
| **Terminal** | Virtual Terminal | P0 | E (Focused) | `Store.TerminalLive` |
| | Card Entry | P0 | Modal | |
| | Payment Link | P1 | (component) | |
| **Orders** | Order Queue | P0 | B (2/3+1/3 List) | `Store.Orders.IndexLive` |
| | Order Detail | P0 | C (2/3+1/3 Detail) | `Store.Orders.ShowLive` |
| | Fulfillment | P1 | (component) | |
| | Returns | P1 | Modal | |
| **Invoices** | Invoice List | P0 | B (2/3+1/3 List) | `Store.Invoices.IndexLive` |
| | Invoice Builder | P0 | E (Focused) | `Store.Invoices.NewLive` |
| | Invoice Detail | P0 | C (2/3+1/3 Detail) | `Store.Invoices.ShowLive` |
| | Send/Remind | P1 | Modal | |
| **Customers** | Customer Lookup | P0 | B (2/3+1/3 List) | `Store.Customers.IndexLive` |
| | Customer Card | P0 | C (2/3+1/3 Detail) | `Store.Customers.ShowLive` |
| | Quick Add | P1 | Modal | |
| **Products** | Product Search | P1 | B (2/3+1/3 List) | `Store.Products.IndexLive` |
| | Product Detail | P1 | C (2/3+1/3 Detail) | `Store.Products.ShowLive` |
| **Inventory** | Stock Levels | P1 | D (Full-Width Table) | `Store.InventoryLive` |
| | Adjust Stock | P1 | Modal | |
| | Receive Stock | P2 | Modal | |
| **Subscriptions** | Active List | P1 | B (2/3+1/3 List) | `Store.Subscriptions.IndexLive` |
| | Subscription Detail | P1 | C (2/3+1/3 Detail) | `Store.Subscriptions.ShowLive` |
| | Renewal Flow | P2 | Modal | |
| **Loyalty** | Points Lookup | P1 | B (2/3+1/3 List) | `Store.LoyaltyLive` |
| | Redemption | P1 | Modal | |
| | Enrollment | P2 | Modal | |
| **Appointments** | Calendar View | P1 | F (Calendar) | `Store.Appointments.IndexLive` |
| | Booking | P1 | Modal | `Store.Appointments.NewLive` |
| | Check In/Out | P1 | (component) | |
| **Tables** | Table Map | P2 | F (Map) | `Store.TablesLive` |
| | Assign/Transfer | P2 | Modal | |
| **Staff** | Clock In/Out | P1 | (component) | `Store.Staff.ClockLive` |
| | Schedule View | P2 | F (Calendar) | `Store.Staff.ScheduleLive` |
| | Time Log | P2 | D (Full-Width Table) | `Store.Staff.TimeLive` |
| **Refunds** | Refund List | P0 | B (2/3+1/3 List) | `Store.Refunds.IndexLive` |
| | Process Refund | P0 | E (Focused) | `Store.Refunds.NewLive` |
| **Tips** | Tip Entry | P1 | B (2/3+1/3 List) | `Store.TipsLive` |
| | Tip Distribution | P2 | (component) | |
| **Reports** | Daily Summary | P1 | A (Dashboard) | `Store.Reports.DailyLive` |
| | Shift Report | P1 | A (Dashboard) | `Store.Reports.ShiftLive` |
| | Close Register | P1 | E (Focused) | `Store.Reports.CloseLive` |
| **Settings** | Store Settings | P2 | C (2/3+1/3 Detail) | `Store.SettingsLive` |

---

## 1. Dashboard

### Purpose
Answer: "What's happening right now and what do I need to do?"

### Layout
Full-width with large quick actions

### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │                                                         │
│                    │  Good afternoon, Jamie                                  │
│ ◉ Dashboard        │  Shift: 2:00 PM - Close  •  4 hours remaining          │
│                    │                                                         │
│ SELL               │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│   POS              │  │   $2,847    │ │     34      │ │   $83.74    │        │
│   Terminal         │  │ Today's     │ │Transactions │ │  Avg Ticket │        │
│   Orders           │  │  Sales      │ │             │ │             │        │
│   Invoices         │  │  ↑ 12%      │ │  ↑ 8%       │ │  ↓ 3%       │        │
│                    │  └─────────────┘ └─────────────┘ └─────────────┘        │
│ MANAGE             │                                                         │
│   Customers        │  ┌─────────────────────────────────────────────────────┐│
│   Products         │  │                    QUICK ACTIONS                    ││
│   ...              │  │                                                     ││
│                    │  │  ┌───────────────┐  ┌───────────────┐  ┌───────────┐││
│ MONEY              │  │  │               │  │               │  │           │││
│   Refunds          │  │  │   NEW SALE    │  │   INVOICE     │  │ CUSTOMER  │││
│   Tips             │  │  │      💳       │  │      📄       │  │  LOOKUP   │││
│   Reports          │  │  │               │  │               │  │    👤     │││
│                    │  │  │   Start POS   │  │  Create New   │  │  Search   │││
│ ─────────────      │  │  └───────────────┘  └───────────────┘  └───────────┘││
│   Settings         │  │                                                     ││
│   Close Shift      │  │  ┌───────────────┐  ┌───────────────┐  ┌───────────┐││
│                    │  │  │               │  │               │  │           │││
│                    │  │  │   TERMINAL    │  │   REFUND      │  │  LOYALTY  │││
│                    │  │  │      ⌨️       │  │      ↩️       │  │    ⭐     │││
│                    │  │  │               │  │               │  │           │││
│                    │  │  │  Phone Order  │  │  Process      │  │  Lookup   │││
│                    │  │  └───────────────┘  └───────────────┘  └───────────┘││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ┌───────────────────────────┐ ┌───────────────────────┐│
│                    │  │ RECENT TRANSACTIONS       │ │ ⚡ PENDING            ││
│                    │  │                           │ │                       ││
│                    │  │ 2:34 PM  J. Smith $124 ✓  │ │ 🟡 2 orders ready     ││
│                    │  │ 2:21 PM  M. Lee   $89  ✓  │ │    to ship            ││
│                    │  │ 2:15 PM  Guest    $42  ✗  │ │                       ││
│                    │  │ 2:08 PM  A. Kim  $215  ✓  │ │ 📄 1 invoice due      ││
│                    │  │                           │ │    today              ││
│                    │  │ [View All Transactions →] │ │                       ││
│                    │  │                           │ │ ↩️ 1 refund request   ││
│                    │  └───────────────────────────┘ │    pending            ││
│                    │                                │                       ││
│                    │                                │ [View All →]          ││
│                    │                                └───────────────────────┘│
│                    │                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Quick Actions Grid

| Action | Icon | Destination | Description |
|--------|------|-------------|-------------|
| New Sale | 💳 | POS | Open point of sale |
| Invoice | 📄 | Invoice Builder | Create new invoice |
| Customer Lookup | 👤 | Customer Search | Find customer |
| Terminal | ⌨️ | Virtual Terminal | Phone/mail order |
| Refund | ↩️ | Refund Flow | Process return |
| Loyalty | ⭐ | Loyalty Lookup | Check points |

### AI Enhancement

Show AI insight when relevant:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 💡 It's unusually slow for this time on Saturday. Last 3 Saturdays had 50+ │
│    transactions by now. Consider: Staff could stock shelves or online orders│
│                                                     [Dismiss]               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. POS (Point of Sale)

### Purpose
Fast in-person checkout with customer present

### Layout
Template D (Focused Mode) - Full screen, no sidebar

### Wireframe - Main Screen

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [✕ Exit]   Downtown Store                        [Staff: Jamie] [🔔] [?]    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────┐  ┌────────────────────────────┐│
│  │                                         │  │ CART                       ││
│  │  [🔍 Search or scan...              ]   │  │                            ││
│  │                                         │  │ Customer: [+ Add Customer] ││
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌───┐ │  │ ─────────────────────────  ││
│  │  │        │ │        │ │        │ │   │ │  │                            ││
│  │  │Premium │ │ Coffee │ │ Back-  │ │...│ │  │ Premium Tee (L, Blue)      ││
│  │  │  Tee   │ │  Mug   │ │  pack  │ │   │ │  │ $29.99       [−] 1 [+] [🗑]││
│  │  │        │ │        │ │        │ │   │ │  │                            ││
│  │  │ $29.99 │ │ $12.00 │ │ $49.00 │ │   │ │  │ Coffee Mug                 ││
│  │  └────────┘ └────────┘ └────────┘ └───┘ │  │ $12.00       [−] 2 [+] [🗑]││
│  │                                         │  │ ─ Note: Gift wrap          ││
│  │  CATEGORIES                             │  │                            ││
│  │  [All] [Apparel] [Drinkware] [Bags]    │  │ ─────────────────────────  ││
│  │  [Electronics] [Accessories]            │  │ + Discount                 ││
│  │                                         │  │ + Note                     ││
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌───┐ │  │ ─────────────────────────  ││
│  │  │        │ │        │ │        │ │   │ │  │                            ││
│  │  │ Water  │ │ Cap    │ │ Tote   │ │...│ │  │ Subtotal          $53.99   ││
│  │  │ Bottle │ │        │ │  Bag   │ │   │ │  │ Tax (8.25%)        $4.45   ││
│  │  │        │ │        │ │        │ │   │ │  │ ═══════════════════════    ││
│  │  │ $24.99 │ │ $19.99 │ │ $35.00 │ │   │ │  │ TOTAL             $58.44   ││
│  │  └────────┘ └────────┘ └────────┘ └───┘ │  │                            ││
│  │                                         │  │ ┌────────────────────────┐ ││
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌───┐ │  │ │                        │ ││
│  │  │        │ │        │ │        │ │   │ │  │ │   💳 PAY  $58.44       │ ││
│  │  │ Phone  │ │ Laptop │ │ Head-  │ │...│ │  │ │                        │ ││
│  │  │ Case   │ │ Stand  │ │phones  │ │   │ │  │ └────────────────────────┘ ││
│  │  │        │ │        │ │        │ │   │ │  │                            ││
│  │  │ $15.00 │ │ $45.00 │ │ $79.00 │ │   │ │  │ [Hold Order]  [Clear Cart] ││
│  │  └────────┘ └────────┘ └────────┘ └───┘ │  │                            ││
│  │                                         │  └────────────────────────────┘│
│  │  [📷 Scan Barcode]  [+ Custom Item]     │                                │
│  │                                         │                                │
│  └─────────────────────────────────────────┘                                │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Product Tile Interaction

**Tap → Add to cart (quantity 1)**
**Long press → Open variant selector**

```
┌──────────────────────────────────────────────────────────────────┐
│ Premium Tee                                          [✕ Close]  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐   Premium Tee                                      │
│  │          │   $29.99                                           │
│  │  [IMG]   │   45 in stock                                      │
│  │          │                                                    │
│  └──────────┘                                                    │
│                                                                  │
│  Size                                                            │
│  [S] [M] [L ✓] [XL]                                              │
│                                                                  │
│  Color                                                           │
│  [● Blue ✓] [● Black] [● White]                                  │
│                                                                  │
│  Quantity                                                        │
│  [−]  1  [+]                                                     │
│                                                                  │
│                                      [Cancel]  [Add to Cart]     │
└──────────────────────────────────────────────────────────────────┘
```

### Customer Recognition (AI)

When customer added to cart:

```
│ Customer: John Smith                     ││
│ ⭐ VIP • 580 pts ($58 value)             ││
│                                          ││
│ 💡 Usually orders Premium Tee. Consider  ││
│    Coffee Mug bundle (+$12).             ││
│ ─────────────────────────────────────    ││
```

### Cart Features

| Feature | Description |
|---------|-------------|
| Quantity Adjust | +/- buttons, direct edit |
| Remove Item | Trash icon |
| Add Discount | Opens discount modal (% or $ or code) |
| Add Note | Per-item or order note |
| Hold Order | Save cart for later (named) |
| Clear Cart | Empty cart (confirmation if items) |

### Wireframe - Payment Screen

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           PAYMENT                              [← Back]      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                           Total Due: $58.44                                  │
│                                                                              │
│     ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐           │
│     │                 │  │                 │  │                 │           │
│     │   CARD READER   │  │      CASH       │  │      SPLIT      │           │
│     │                 │  │                 │  │                 │           │
│     │ 💳 Tap, Insert, │  │   💵 Bills &    │  │   ½+½ Multiple  │           │
│     │   or Swipe      │  │      Coins      │  │     Methods     │           │
│     │                 │  │                 │  │                 │           │
│     └─────────────────┘  └─────────────────┘  └─────────────────┘           │
│                                                                              │
│     ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐           │
│     │                 │  │                 │  │                 │           │
│     │  MANUAL ENTRY   │  │  PAYMENT LINK   │  │      OTHER      │           │
│     │                 │  │                 │  │                 │           │
│     │ ⌨️ Type Card #  │  │ 📱 Send to      │  │ 🎁 Gift Card,   │           │
│     │                 │  │    Customer     │  │    Check, etc   │           │
│     │                 │  │                 │  │                 │           │
│     └─────────────────┘  └─────────────────┘  └─────────────────┘           │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ LOYALTY                                                                  ││
│  │                                                                          ││
│  │ John Smith has 580 points (= $58.00 value)                              ││
│  │ ☐ Apply points (-$58.00)  Remaining: $0.44                              ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ TIP                                                                      ││
│  │                                                                          ││
│  │ [No Tip] [15% $8.77] [18% $10.52] [20% $11.69] [Custom]                 ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Cash Payment Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          CASH PAYMENT                          [← Back]      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                           Total: $58.44                                      │
│                                                                              │
│  Amount Tendered                                                             │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                              $60.00                                      ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                                        │
│  │ $20  │ │ $50  │ │ $60  │ │ $100 │      Quick amounts                     │
│  └──────┘ └──────┘ └──────┘ └──────┘                                        │
│                                                                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                                        │
│  │  1   │ │  2   │ │  3   │ │  ⌫   │      Keypad                            │
│  ├──────┤ ├──────┤ ├──────┤ ├──────┤                                        │
│  │  4   │ │  5   │ │  6   │ │  C   │                                        │
│  ├──────┤ ├──────┤ ├──────┤ ├──────┤                                        │
│  │  7   │ │  8   │ │  9   │ │ .00  │                                        │
│  ├──────┤ ├──────┤ ├──────┤ ├──────┤                                        │
│  │  .   │ │  0   │ │ 00   │ │ENTER │                                        │
│  └──────┘ └──────┘ └──────┘ └──────┘                                        │
│                                                                              │
│  ═══════════════════════════════════════════════════════════════════════════│
│                                                                              │
│                        Change Due: $1.56                                     │
│                                                                              │
│                     [Complete Transaction]                                   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Receipt Options

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           ✓ PAYMENT COMPLETE                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                              $58.44                                          │
│                        Visa ****1234                                         │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                                                                         ││
│  │  RECEIPT OPTIONS                                                        ││
│  │                                                                         ││
│  │  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐   ││
│  │  │                   │  │                   │  │                   │   ││
│  │  │   📧 EMAIL        │  │   📱 SMS          │  │   🖨️ PRINT        │   ││
│  │  │                   │  │                   │  │                   │   ││
│  │  │ john@email.com    │  │  (555) 123-4567   │  │  Receipt Printer  │   ││
│  │  │                   │  │                   │  │                   │   ││
│  │  └───────────────────┘  └───────────────────┘  └───────────────────┘   ││
│  │                                                                         ││
│  │                      [No Receipt]                                       ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│                        [New Sale]                                            │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Terminal (Virtual Terminal)

### Purpose
Card-not-present orders (phone, mail, remote)

### Layout
Template D (Focused Mode) - Similar to POS but with shipping

### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [✕ Exit]   Virtual Terminal                      [Staff: Jamie] [🔔] [?]    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────┐  ┌────────────────────────────┐│
│  │                                         │  │ ORDER DETAILS              ││
│  │  [🔍 Search products...              ]  │  │                            ││
│  │                                         │  │ CUSTOMER *                 ││
│  │  [Same product grid as POS]             │  │ ┌────────────────────────┐ ││
│  │                                         │  │ │ John Smith           ▾│ ││
│  │                                         │  │ └────────────────────────┘ ││
│  │                                         │  │ john@email.com             ││
│  │                                         │  │ (555) 123-4567             ││
│  │                                         │  │ [+ New Customer]           ││
│  │                                         │  │                            ││
│  │                                         │  │ ORDER TYPE                 ││
│  │                                         │  │ ○ Phone Order              ││
│  │                                         │  │ ● Email Request            ││
│  │                                         │  │ ○ Custom Order             ││
│  │                                         │  │ ─────────────────────────  ││
│  │                                         │  │                            ││
│  │                                         │  │ ITEMS                      ││
│  │                                         │  │ Premium Tee (L)   $29.99   ││
│  │                                         │  │ Coffee Mug (x2)   $24.00   ││
│  │                                         │  │ + Discount  + Note         ││
│  │                                         │  │ ─────────────────────────  ││
│  │                                         │  │                            ││
│  │                                         │  │ DELIVERY                   ││
│  │                                         │  │ ● Ship to customer         ││
│  │                                         │  │ ○ Local delivery           ││
│  │                                         │  │ ○ Customer pickup          ││
│  │                                         │  │                            ││
│  │                                         │  │ Shipping Address           ││
│  │                                         │  │ 123 Main St, NY 10001      ││
│  │                                         │  │ [Edit Address]             ││
│  │                                         │  │                            ││
│  │                                         │  │ Shipping Method            ││
│  │                                         │  │ [Standard ($8.99)       ▾] ││
│  │                                         │  │ ─────────────────────────  ││
│  │  [📷 Scan] [+ Custom Item]              │  │ Subtotal          $53.99   ││
│  │                                         │  │ Shipping           $8.99   ││
│  └─────────────────────────────────────────┘  │ Tax                $4.45   ││
│                                               │ TOTAL             $67.43   ││
│                                               │                            ││
│                                               │ [💳 Charge Card $67.43]    ││
│                                               │ [📱 Send Payment Link]     ││
│                                               │ [💾 Save as Quote]         ││
│                                               └────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Card Entry Modal

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          ENTER CARD DETAILS                     [✕ Cancel]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Card Number *                                                               │
│  ┌──────────────────────────────────────────────────────────────┐  [VISA]   │
│  │ 4242 4242 4242 4242                                          │           │
│  └──────────────────────────────────────────────────────────────┘           │
│                                                                              │
│  Expiry *                  CVC *                  ZIP *                      │
│  ┌──────────────┐          ┌──────────────┐       ┌──────────────────┐      │
│  │ 12 / 28      │          │ 123          │       │ 10001            │      │
│  └──────────────┘          └──────────────┘       └──────────────────┘      │
│                                                                              │
│  Billing Address *                                                           │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ 123 Main Street                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│  ┌────────────────────┐  ┌──────────┐  ┌────────────────────────────────────┐│
│  │ New York           │  │ NY    ▾  │  │ 10001                              ││
│  └────────────────────┘  └──────────┘  └────────────────────────────────────┘│
│                                                                              │
│  ☐ Save card for future purchases (with customer consent)                   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                        Charge $67.43                                     ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Send Payment Link

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        SEND PAYMENT LINK                        [✕ Cancel]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Send payment link for $67.43 to John Smith                                 │
│                                                                              │
│  Delivery Method                                                             │
│  ● Email: john@email.com                                                    │
│  ○ SMS: (555) 123-4567                                                      │
│                                                                              │
│  Link Expires                                                                │
│  [24 hours ▾]                                                                │
│                                                                              │
│  Message (optional)                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ Hi John, here's the payment link for your phone order...                ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│                                                  [Cancel]  [Send Link]       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Orders

### Purpose
View and fulfill orders created from this store

### Sidebar
Uses main store sidebar

### 4.1 Order Queue

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Orders                                                 │
│                    ├─────────────────────────────────────────────────────────┤
│ Dashboard          │  [All] [New (8)] [Processing (12)] [Ready (5)] [Shipped]│
│                    ├─────────────────────────────────────────────────────────┤
│ SELL               │  [🔍 Search orders...]  [Date ▾] [Type ▾]               │
│   POS              ├─────────────────────────────────────────────────────────┤
│   Terminal         │                                                         │
│ ● Orders           │  ┌──────────────────────────────────────────────────────┐│
│   Invoices         │  │ ORDER     │ CUSTOMER    │ ITEMS │ TOTAL  │ STATUS   ││
│                    │  ├───────────┼─────────────┼───────┼────────┼──────────┤│
│ MANAGE             │  │ #1234     │ John Smith  │ 3     │$124.00 │ 🟡 New   ││
│   Customers        │  │ 2:34 PM   │             │       │        │[Fulfill] ││
│   Products         │  ├───────────┼─────────────┼───────┼────────┼──────────┤│
│   ...              │  │ #1233     │ Maria Lee   │ 2     │ $89.50 │ 🔵 Proc  ││
│                    │  │ 2:21 PM   │             │       │        │ [Pack]   ││
│ MONEY              │  ├───────────┼─────────────┼───────┼────────┼──────────┤│
│   Refunds          │  │ #1232     │ Guest       │ 1     │ $42.00 │ 🟢 Ready ││
│   ...              │  │ 2:15 PM   │             │       │        │ [Ship]   ││
│                    │  ├───────────┼─────────────┼───────┼────────┼──────────┤│
│ ─────────────      │  │ #1231     │ Alex Kim    │ 5     │$215.00 │ ✓ Shipped││
│ Settings           │  │ 1:45 PM   │             │       │        │Tracking: ││
│ Close Shift        │  │           │             │       │        │1Z999...  ││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  Batch Actions: [☐ Select All]                         │
│                    │  [📋 Print Packing Slips]  [📦 Mark as Packed]         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Order Detail

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Orders]                                     [Print] [Refund ▾] [Cancel]   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Order #1234                                               🟡 New            │
│  Jan 11, 2026 at 2:34 PM  •  Terminal Order  •  Staff: Jamie               │
│                                                                              │
│  ┌───────────────────────────────────────────┐  ┌──────────────────────────┐│
│  │ ITEMS                                     │  │ CUSTOMER                 ││
│  │                                           │  │                          ││
│  │ Premium Tee (L, Blue)                     │  │ 👤 John Smith            ││
│  │   SKU: TEE-001-L-BL                       │  │    john@email.com        ││
│  │   $29.99 × 1 = $29.99                     │  │    (555) 123-4567        ││
│  │   ☐ Packed                                │  │                          ││
│  │                                           │  │ [View Customer →]        ││
│  │ Coffee Mug                                │  └──────────────────────────┘│
│  │   SKU: MUG-001                            │                              │
│  │   $12.00 × 2 = $24.00                     │  ┌──────────────────────────┐│
│  │   Note: Gift wrap                         │  │ SHIPPING                 ││
│  │   ☐ Packed                                │  │                          ││
│  │                                           │  │ Standard Shipping        ││
│  │ Leather Backpack                          │  │                          ││
│  │   SKU: BAG-001                            │  │ 📍 123 Main Street       ││
│  │   $70.01 × 1 = $70.01                     │  │    New York, NY 10001    ││
│  │   ☐ Packed                                │  │                          ││
│  │                                           │  └──────────────────────────┘│
│  └───────────────────────────────────────────┘                              │
│                                                 ┌──────────────────────────┐│
│  ┌───────────────────────────────────────────┐  │ PAYMENT                  ││
│  │ ORDER SUMMARY                             │  │                          ││
│  │                                           │  │ 💳 Visa ****1234         ││
│  │ Subtotal                      $124.00     │  │    Auth: 123456          ││
│  │ Shipping (Standard)             $8.99     │  │    Status: ✓ Captured    ││
│  │ Tax (8.25%)                    $10.23     │  │                          ││
│  │ ─────────────────────────────────────     │  │ [View Transaction →]     ││
│  │ Total                         $143.22     │  └──────────────────────────┘│
│  └───────────────────────────────────────────┘                              │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ FULFILLMENT                                                             ││
│  │                                                                         ││
│  │ ● Step 1: Pack Items                                                    ││
│  │   ☐ Premium Tee  ☐ Coffee Mug (x2)  ☐ Leather Backpack                 ││
│  │                                                                         ││
│  │ ○ Step 2: Enter Tracking                                                ││
│  │   Carrier: [──Select──▾]  Tracking #: [                    ]           ││
│  │                                                                         ││
│  │ ○ Step 3: Ship & Notify                                                 ││
│  │   ☑ Send shipping notification to customer                              ││
│  │                                                                         ││
│  │                               [Mark as Ready]  [Mark as Shipped]        ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Invoices

### Purpose
Create and send invoices, track payment status

### 5.1 Invoice List

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Invoices                              [+ New Invoice]  │
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │  [All] [Draft (2)] [Pending (5)] [Overdue (3)] [Paid]  │
│   Terminal         ├─────────────────────────────────────────────────────────┤
│   Orders           │  [🔍 Search...]  [Date ▾] [Customer ▾]                  │
│ ● Invoices         ├─────────────────────────────────────────────────────────┤
│                    │  🚨 3 invoices are overdue. Total: $2,340.              │
│ ...                │     [Send Reminders →]                       [Dismiss] │
│                    ├─────────────────────────────────────────────────────────┤
│                    │                                                         │
│                    │  ┌───────────┬───────────┬─────────┬────────┬─────────┐│
│                    │  │ INVOICE   │ CUSTOMER  │ AMOUNT  │ DUE    │ STATUS  ││
│                    │  ├───────────┼───────────┼─────────┼────────┼─────────┤│
│                    │  │ INV-1234  │ Acme Inc  │ $1,250  │ Jan 15 │ 🟡 Pend ││
│                    │  │           │           │         │ 4 days │ [Send]  ││
│                    │  ├───────────┼───────────┼─────────┼────────┼─────────┤│
│                    │  │ INV-1233  │ Beta Corp │ $890    │ Jan 10 │ 🔴 Over ││
│                    │  │           │           │         │ -1 day │[Remind] ││
│                    │  ├───────────┼───────────┼─────────┼────────┼─────────┤│
│                    │  │ INV-1232  │ J. Smith  │ $124    │ Jan 8  │ ✓ Paid  ││
│                    │  │           │           │         │ Paid 1/8│[Recpt] ││
│                    │  └───────────┴───────────┴─────────┴────────┴─────────┘│
│                    │                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Invoice Builder

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [✕ Exit]   Create Invoice                       [Save Draft] [Preview] [Send]│
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────┐  ┌──────────────────────────────┐│
│  │ INVOICE DETAILS                       │  │ PREVIEW                      ││
│  │                                       │  │                              ││
│  │ Customer *                            │  │  ┌────────────────────────┐  ││
│  │ [Acme Inc                          ▾] │  │  │    INVOICE #1235      │  ││
│  │ contact@acmeinc.com                   │  │  │    ────────────────    │  ││
│  │ [+ New Customer]                      │  │  │    Acme Inc           │  ││
│  │                                       │  │  │    123 Business St    │  ││
│  │ Invoice Number                        │  │  │                        │  ││
│  │ [INV-1235         ]  (auto)           │  │  │    Items:              │  ││
│  │                                       │  │  │    - Consulting $500  │  ││
│  │ Issue Date          Due Date          │  │  │    - Design     $750  │  ││
│  │ [Jan 11, 2026   ]   [Jan 25, 2026  ]  │  │  │                        │  ││
│  │                     Net 14            │  │  │    Subtotal: $1,250   │  ││
│  │                                       │  │  │    Tax:         $0   │  ││
│  │ ─────────────────────────────────     │  │  │    Total:   $1,250   │  ││
│  │                                       │  │  │                        │  ││
│  │ LINE ITEMS                            │  │  │    Due: Jan 25, 2026  │  ││
│  │                                       │  │  │                        │  ││
│  │ ┌─────────────────────────────────┐   │  │  │    [Pay Now]          │  ││
│  │ │ Description      │ Qty │ Price  │   │  │  └────────────────────────┘  ││
│  │ ├─────────────────────────────────┤   │  │                              ││
│  │ │ Consulting Hours │ 5   │ $100   │   │  │  Mobile-friendly preview    ││
│  │ │ Design Services  │ 1   │ $750   │   │  │                              ││
│  │ │ [+ Add Line Item]               │   │  └──────────────────────────────┘│
│  │ └─────────────────────────────────┘   │                                  │
│  │                                       │                                  │
│  │ Subtotal                    $1,250    │                                  │
│  │ Tax (0%)                        $0    │                                  │
│  │ Discount  [+ Add]               $0    │                                  │
│  │ ─────────────────────────────────     │                                  │
│  │ Total                       $1,250    │                                  │
│  │                                       │                                  │
│  │ Notes (appears on invoice)            │                                  │
│  │ ┌─────────────────────────────────┐   │                                  │
│  │ │ Payment due upon receipt...     │   │                                  │
│  │ └─────────────────────────────────┘   │                                  │
│  │                                       │                                  │
│  └───────────────────────────────────────┘                                  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Customers (Store View)

### Purpose
Quick customer lookup during service

### Key Differences from Merchant Portal
- Read-focused, not full CRM
- Quick actions for immediate service needs
- Recent transactions at THIS store only

### 6.1 Customer Lookup

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Customers                             [+ Quick Add]    │
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │  [🔍 Search by name, email, phone, or loyalty #...]     │
│ MANAGE             ├─────────────────────────────────────────────────────────┤
│ ● Customers        │                                                         │
│   Products         │  ┌──────────────────────────────────────────────────────┐│
│   Inventory        │  │ CUSTOMER           │ VISITS │ LAST VISIT │ LOYALTY  ││
│   ...              │  ├────────────────────┼────────┼────────────┼──────────┤│
│                    │  │ 👤 John Smith      │ 23     │ Today      │ 580 pts  ││
│ ...                │  │   john@email.com   │        │            │ ⭐ VIP   ││
│                    │  ├────────────────────┼────────┼────────────┼──────────┤│
│                    │  │ 👤 Maria Garcia    │ 12     │ 3 days ago │ 245 pts  ││
│                    │  │   maria@email.com  │        │            │          ││
│                    │  ├────────────────────┼────────┼────────────┼──────────┤│
│                    │  │ 👤 Alex Kim        │ 5      │ 1 week ago │ 89 pts   ││
│                    │  │   alex@email.com   │        │            │ 🆕 New   ││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  💡 AI: John Smith is here frequently. Consider VIP     │
│                    │     treatment - he responds well to personal attention. │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Customer Card (Quick View)

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Customers]                              [Start Sale] [Create Invoice]     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ ┌──────┐                                                                ││
│  │ │  JS  │  John Smith                                    ⭐ VIP          ││
│  │ └──────┘  john@email.com  •  (555) 123-4567                            ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │    23       │ │   $1,245    │ │  580 pts    │ │   $54.13    │            │
│  │ Visits Here │ │ Spent Here  │ │  Loyalty    │ │ Avg Order   │            │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────────┐ │
│  │ 🤖 AI INSIGHT                    │  │ QUICK ACTIONS                    │ │
│  │                                  │  │                                  │ │
│  │ John usually orders Premium Tee  │  │ [🛒 Start New Sale]              │ │
│  │ and Coffee Mugs together.        │  │ [📄 Create Invoice]              │ │
│  │                                  │  │ [⭐ Check Loyalty Points]        │ │
│  │ He was here 2 hours ago and      │  │ [📝 Add Note]                    │ │
│  │ mentioned looking for a gift.    │  │                                  │ │
│  │                                  │  └──────────────────────────────────┘ │
│  │ Suggest: Gift wrapping option.   │                                       │
│  └──────────────────────────────────┘                                       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ RECENT TRANSACTIONS AT THIS STORE                        [View All →]   ││
│  │                                                                         ││
│  │ Today, 12:34 PM      Premium Tee, Coffee Mug           $53.99   ✓ Paid ││
│  │ Jan 8, 3:15 PM       Leather Backpack                  $89.00   ✓ Paid ││
│  │ Jan 2, 11:20 AM      Water Bottle (x2)                 $49.98   ✓ Paid ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ NOTES                                                       [+ Add]     ││
│  │                                                                         ││
│  │ Jan 11 - Looking for birthday gift for wife. Likes blue.    - Jamie    ││
│  │ Jan 2 - Requested we carry larger sizes. Noted for catalog. - Sam      ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Refunds

### Purpose
Process returns and refunds for store transactions

### 7.1 Refund List

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Refunds                               [+ New Refund]   │
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │  [Pending (3)] [Completed] [All]                        │
│ MONEY              ├─────────────────────────────────────────────────────────┤
│ ● Refunds          │                                                         │
│   Tips             │  ┌──────────────────────────────────────────────────────┐│
│   Reports          │  │ REFUND    │ ORIGINAL  │ AMOUNT  │ REASON   │STATUS  ││
│                    │  ├───────────┼───────────┼─────────┼──────────┼────────┤│
│ ...                │  │ REF-123   │ #1230     │ $29.99  │ Defective│🟡 Pend ││
│                    │  │ Today     │ J. Smith  │         │          │[Process]│
│                    │  ├───────────┼───────────┼─────────┼──────────┼────────┤│
│                    │  │ REF-122   │ #1225     │ $12.00  │ Wrong    │🟡 Pend ││
│                    │  │ Today     │ M. Lee    │         │ Item     │[Process]│
│                    │  ├───────────┼───────────┼─────────┼──────────┼────────┤│
│                    │  │ REF-121   │ #1220     │ $89.00  │ Changed  │✓ Done  ││
│                    │  │ Yesterday │ A. Kim    │         │ Mind     │        ││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Process Refund

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Process Refund                                              [Cancel] [Submit]│
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ORIGINAL TRANSACTION                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ Order #1230  •  Jan 10, 2:34 PM  •  John Smith                           ││
│  │ Payment: Visa ****1234  •  Total: $124.00                                ││
│  │                                                                          ││
│  │ [View Original Order →]                                                  ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ITEMS TO REFUND                                                             │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                                                                          ││
│  │ ☑ Premium Tee (L, Blue)                                                  ││
│  │   Original: 1 × $29.99                                                   ││
│  │   Refund:   [1 ▾] × $29.99 = $29.99                                      ││
│  │                                                                          ││
│  │ ☐ Coffee Mug                                                             ││
│  │   Original: 2 × $12.00 = $24.00                                          ││
│  │   (Not selected)                                                         ││
│  │                                                                          ││
│  │ ☐ Leather Backpack                                                       ││
│  │   Original: 1 × $70.01                                                   ││
│  │   (Not selected)                                                         ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  REFUND REASON *                                                             │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ Defective Product                                                      ▾ ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  INTERNAL NOTES                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ Customer reported seam was coming apart after first wash.               ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  REFUND SUMMARY                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                                                                          ││
│  │ Refund Amount:        $29.99                                             ││
│  │ Refund To:            Visa ****1234 (original payment)                   ││
│  │                                                                          ││
│  │ ☑ Return item to inventory                                               ││
│  │ ☐ Exchange for different size/color                                      ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│                                                    [Cancel]  [Process Refund]│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Reports (Store Level)

### Purpose
Daily and shift performance tracking

### 8.1 Daily Summary

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Daily Report                          [Jan 11 ▾] [PDF] │
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │                                                         │
│ MONEY              │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│   Refunds          │  │   $6,420    │ │     78      │ │   $82.31    │        │
│   Tips             │  │ Total Sales │ │Transactions │ │  Avg Order  │        │
│ ● Reports          │  │  ↑ 12%      │ │  ↑ 8%       │ │  ↑ 3%       │        │
│                    │  └─────────────┘ └─────────────┘ └─────────────┘        │
│ ...                │                                                         │
│                    │  ┌───────────────────────────────────────────────────┐  │
│                    │  │ SALES BY HOUR                                     │  │
│                    │  │                                                   │  │
│                    │  │  $800│         ▄▄                                │  │
│                    │  │      │      ▄▄▄██▄▄                              │  │
│                    │  │  $400│   ▄▄▄██████████▄                          │  │
│                    │  │      │▄▄▄██████████████▄▄                        │  │
│                    │  │  $0  └────────────────────────────────            │  │
│                    │  │      9  10  11  12  1   2   3   4   5            │  │
│                    │  │           AM                PM                    │  │
│                    │  └───────────────────────────────────────────────────┘  │
│                    │                                                         │
│                    │  ┌─────────────────────────┐ ┌─────────────────────────┐│
│                    │  │ TOP PRODUCTS            │ │ PAYMENT METHODS         ││
│                    │  │                         │ │                         ││
│                    │  │ 1. Premium Tee    23    │ │ Card     $5,420  84%   ││
│                    │  │ 2. Coffee Mug     18    │ │ Cash       $890  14%   ││
│                    │  │ 3. Water Bottle   12    │ │ Other      $110   2%   ││
│                    │  │ 4. Cap             9    │ │                         ││
│                    │  │ 5. Tote Bag        7    │ │                         ││
│                    │  │                         │ │                         ││
│                    │  │ [View All Products →]   │ │ [View Breakdown →]      ││
│                    │  └─────────────────────────┘ └─────────────────────────┘│
│                    │                                                         │
│                    │  ┌─────────────────────────────────────────────────────┐│
│                    │  │ STAFF PERFORMANCE                                   ││
│                    │  │                                                     ││
│                    │  │ Jamie     $2,450  32 txns  $76.56 avg               ││
│                    │  │ Sam       $2,120  28 txns  $75.71 avg               ││
│                    │  │ Alex      $1,850  18 txns  $102.78 avg 🏆           ││
│                    │  │                                                     ││
│                    │  └─────────────────────────────────────────────────────┘│
│                    │                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Close Shift / Register

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Close Shift                                                   [Cancel] [Done]│
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Shift Summary: Jamie  •  2:00 PM - 10:00 PM (8 hours)                      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ CASH DRAWER RECONCILIATION                                               ││
│  │                                                                          ││
│  │ Expected Cash          Actual Count          Difference                  ││
│  │                                                                          ││
│  │ $890.00               [$890.00      ]         $0.00 ✓                    ││
│  │                                                                          ││
│  │ Breakdown:                                                               ││
│  │ Starting float         $200.00                                           ││
│  │ Cash sales            +$745.00                                           ││
│  │ Cash refunds           -$55.00                                           ││
│  │ ─────────────────────────────────                                        ││
│  │ Expected               $890.00                                           ││
│  │                                                                          ││
│  │ ☐ Count is different (explain below)                                     ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ SHIFT SUMMARY                                                            ││
│  │                                                                          ││
│  │ Total Sales                           $2,450.00                          ││
│  │ Transactions                                32                           ││
│  │ Average Order                            $76.56                          ││
│  │ ───────────────────────────────────────────────                          ││
│  │ Card Payments                         $1,705.00                          ││
│  │ Cash Payments                           $745.00                          ││
│  │ ───────────────────────────────────────────────                          ││
│  │ Refunds Processed                         $55.00 (2 refunds)             ││
│  │ ───────────────────────────────────────────────                          ││
│  │ Tips Collected                           $180.00                         ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  Notes (optional)                                                            │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ Busy Saturday. Card reader had issues around 4pm, rebooted.             ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│                                                                              │
│                                           [Print Report]  [Close Shift]      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Additional Features

### 9.1 Inventory (Stock Levels)

Quick stock check and adjustment for this store only.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Inventory                              [+ Adjust Stock]│
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │  [🔍 Search...]  [Stock Level ▾]                        │
│ MANAGE             ├─────────────────────────────────────────────────────────┤
│   Customers        │                                                         │
│   Products         │  ┌──────────────────────────────────────────────────────┐│
│ ● Inventory        │  │ PRODUCT            │ ON HAND │ COMMITTED │ AVAILABLE││
│   ...              │  ├────────────────────┼─────────┼───────────┼──────────┤│
│                    │  │ Premium Tee (S)    │ 5       │ 1         │ 4        ││
│                    │  │ Premium Tee (M)    │ 12      │ 2         │ 10       ││
│                    │  │ Premium Tee (L)    │ 8       │ 0         │ 8        ││
│                    │  │ ⚠ Coffee Mug       │ 3       │ 1         │ 2   ⚠   ││
│                    │  │ Leather Backpack   │ 6       │ 0         │ 6        ││
│                    │  └──────────────────────────────────────────────────────┘│
│                    │                                                         │
│                    │  ⚠ Low stock alerts are set in Merchant Portal         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Loyalty Lookup

Quick points check and redemption.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Loyalty Lookup                                                      [✕ Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  [🔍 Search by name, email, phone, or card #...]                            │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                                                                          ││
│  │  👤 John Smith                                                           ││
│  │     john@email.com                                                       ││
│  │                                                                          ││
│  │     ┌─────────────────────────────────────────────────────────────────┐  ││
│  │     │                                                                 │  ││
│  │     │                    ⭐ 580 POINTS                                │  ││
│  │     │                    = $58.00 value                               │  ││
│  │     │                                                                 │  ││
│  │     │                    Member since: Jan 2024                       │  ││
│  │     │                    Tier: VIP (500+ points)                      │  ││
│  │     │                                                                 │  ││
│  │     └─────────────────────────────────────────────────────────────────┘  ││
│  │                                                                          ││
│  │     RECENT ACTIVITY                                                      ││
│  │     +50 pts  Jan 11   Purchase: $53.99                                  ││
│  │     +30 pts  Jan 8    Purchase: $32.00                                  ││
│  │     -100 pts Jan 2    Redeemed: $10 off                                 ││
│  │                                                                          ││
│  │     [Apply Points to Current Sale]   [View Full History]                ││
│  │                                                                          ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9.3 Appointments (Services Vertical)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Appointments                          [+ New Booking]  │
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │  [< Jan 11, 2026 >]   [Day] [Week] [Month]             │
│ SCHEDULE           ├─────────────────────────────────────────────────────────┤
│ ● Appointments     │                                                         │
│   Tables           │   9:00  │ John Smith - Haircut (Jamie)    │ ✓ Checked In│
│   Staff            │   9:30  │                                 │             │
│                    │  10:00  │ Maria Garcia - Color (Sam)      │ ◐ Arriving  │
│ ...                │  10:30  │                                 │             │
│                    │  11:00  │ Alex Kim - Cut & Style (Jamie)  │ ○ Scheduled │
│                    │  11:30  │                                 │             │
│                    │  12:00  │ ─── Lunch Break ───             │             │
│                    │   1:00  │ Guest - Consultation (Available)│ ○ Scheduled │
│                    │   1:30  │                                 │             │
│                    │   2:00  │ [+ Add Appointment]             │             │
│                    │                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9.4 Tables (Restaurant Vertical)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Sidebar]          │  Tables                                                 │
│                    ├─────────────────────────────────────────────────────────┤
│ ...                │                                                         │
│ SCHEDULE           │   ┌─────────────────────────────────────────────────┐   │
│   Appointments     │   │                    FLOOR MAP                    │   │
│ ● Tables           │   │                                                 │   │
│   Staff            │   │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐           │   │
│                    │   │  │ T1  │  │ T2  │  │ T3  │  │ T4  │           │   │
│ ...                │   │  │ 🟢  │  │ 🔴  │  │ 🟡  │  │ 🟢  │           │   │
│                    │   │  │ 4   │  │ 2   │  │ 4   │  │ 2   │           │   │
│                    │   │  └─────┘  └─────┘  └─────┘  └─────┘           │   │
│                    │   │                                                 │   │
│                    │   │  ┌─────┐  ┌─────────────┐  ┌─────┐            │   │
│                    │   │  │ T5  │  │     T6      │  │ T7  │            │   │
│                    │   │  │ 🔴  │  │     🟡      │  │ 🟢  │            │   │
│                    │   │  │ 4   │  │     8       │  │ 4   │            │   │
│                    │   │  └─────┘  └─────────────┘  └─────┘            │   │
│                    │   │                                                 │   │
│                    │   │  🟢 Available  🟡 Occupied  🔴 Bill Requested  │   │
│                    │   └─────────────────────────────────────────────────┘   │
│                    │                                                         │
│                    │  T2: Smith party (2) - Seated 45 min - $89.50          │
│                    │      [View Order] [Add Items] [Request Bill] [Clear]   │
│                    │                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## AI Integration Patterns

### Intelligence Bar (⌘K)

Context-aware for store operations:

| Context | Example Queries | Action |
|---------|-----------------|--------|
| Dashboard | "john smith" | Find customer, show card |
| POS | "apply 10% discount" | Apply to current cart |
| Orders | "unfulfilled" | Filter to new orders |
| Any | "what's low stock" | Show inventory alerts |
| Any | "my sales today" | Show personal stats |

### Proactive Insights

Store-specific, actionable insights:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 💡 John Smith is back - he was looking for a gift last time. His wife     │
│    likes the color blue and he usually buys Premium Tees.     [Dismiss]   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Contextual AI in POS

When customer is recognized:

```
│ Customer: John Smith ⭐ VIP                    │
│ ─────────────────────────────────────────────│
│ 💡 Usually orders: Premium Tee + Coffee Mug   │
│    Responds well to: 10-15% discounts         │
│    Note from earlier: Looking for gift        │
```

---

## Empty States

### No Orders

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                               📦                                            │
│                                                                             │
│                        No orders yet today                                  │
│                                                                             │
│                Start a new sale to create your first order.                 │
│                                                                             │
│                         [Start New Sale]                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Empty Cart (POS)

```
┌────────────────────────────────────────┐
│ CART                                   │
│                                        │
│         🛒                             │
│                                        │
│     Cart is empty                      │
│                                        │
│ Search or tap products to add them.   │
│                                        │
└────────────────────────────────────────┘
```

---

## Component Requirements

### Required Components

| Component | Usage | Priority |
|-----------|-------|----------|
| `pos_product_tile` | POS/Terminal grid | P0 |
| `pos_cart` | POS/Terminal cart | P0 |
| `pos_cart_item` | Cart line items | P0 |
| `payment_method_card` | Payment selection | P0 |
| `quick_action_card` | Dashboard actions | P0 |
| `order_status_badge` | Order list/detail | P0 |
| `customer_lookup_row` | Customer search | P0 |
| `shift_timer` | Dashboard header | P1 |
| `cash_keypad` | Cash payment | P1 |
| `receipt_options` | Post-payment | P1 |
| `table_map` | Restaurant tables | P2 |
| `calendar_day` | Appointments | P2 |

---

## Implementation Priority

| Phase | Features | Scope |
|-------|----------|-------|
| 1 | Dashboard, POS (full flow), Terminal | Core Sales |
| 2 | Orders, Invoices, Refunds | Fulfillment |
| 3 | Customers, Inventory, Loyalty | Service |
| 4 | Reports, Close Shift | End of Day |
| 5 | Appointments, Tables, Subscriptions | Verticals |

---

*Document generated 2026-01-11 - Complete Store Portal specification*
