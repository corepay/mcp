# Virtual Terminal Redesign

> **Created**: 2026-01-11 | **Status**: Design Complete
> **Track**: Store Portal | **Depends On**: [AI Portal UX](docs/plans/2026-01-10-ai-portal-ux-design.md)
> **Related**: [AI Usage Infrastructure](docs/plans/2026-01-10-ai-usage-infrastructure-design.md)

## Overview

Complete redesign of the Virtual Terminal from a 4-step wizard to a single-screen,
feature-rich payment interface. Supports products, customers, fees, discounts, tips,
and multiple payment methods (card, payment link, email request).

**Design Philosophy**: The best virtual terminals feel like premium fintech apps -
fast, confident, and provide immediate feedback. Density with clarity.

---

## Architecture

### Single-Screen Layout

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ← Exit    Virtual Terminal    [⌘ Ask AI...]            [History] [?]      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─ CUSTOMER (optional, collapsible) ────────────────────────────────────┐ │
│  │ [🔍 Search or add customer...]                      [+ New Customer]  │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
├──────────────────────────────────────┬─────────────────────────────────────┤
│  LINE ITEMS (60%)                    │  ORDER SUMMARY (40%)                │
│                                      │                                     │
│  [🔍 Search products, fees...]       │  Subtotal              $71.98      │
│  [+ Custom Line Item]                │  Summer Sale           −$7.20      │
│                                      │  Rush Delivery         $25.00      │
│  ┌────────────────────────────────┐  │  Tax (8.25%)            $7.41      │
│  │ 📦 Premium Tee      $59.98  ✕ │  │  Tip                   $10.00      │
│  │    $29.99 × 2    [−] [+]      │  │  ────────────────────────────      │
│  ├────────────────────────────────┤  │  TOTAL                $107.19      │
│  │ 📦 Coffee Mug      $12.00  ✕ │  │                                     │
│  │    $12.00 × 1    [−] [+]      │  │  ┌─────────────────────────────┐   │
│  ├────────────────────────────────┤  │  │ 💳 Charge Card $107.19     │   │
│  │ 🏷️ Summer Sale    −$7.20  ✕ │  │  └─────────────────────────────┘   │
│  ├────────────────────────────────┤  │  ┌──────────────┐ ┌────────────┐  │
│  │ 🚚 Rush Delivery  $25.00  ✕ │  │  │ 🔗 Send Link │ │ 📧 Email  │  │
│  ├────────────────────────────────┤  │  └──────────────┘ └────────────┘  │
│  │ 💰 Tip            $10.00  ✕ │  │                                     │
│  └────────────────────────────────┘  │                                     │
│                                      │                                     │
│  [+ Add note to order]               │                                     │
│                                      │                                     │
└──────────────────────────────────────┴─────────────────────────────────────┘
```

---

## Entity Interaction Pattern

Consistent pattern across all entity types (Customer, Products, Fees, Discounts):

| Action | Behavior |
|--------|----------|
| **Search** | Type-ahead search of existing entities |
| **Select** | Click to add to order |
| **Quick-create** | Modal to create new + add to order |
| **Save option** | Checkbox to persist to catalog |
| **Optional** | All entities optional - can skip any/all |

---

## Customer Section

### Search State
```
┌─ CUSTOMER ───────────────────────────────────────────────────────────────┐
│ [🔍 Search customers by name, email, phone...]           [+ New Customer]│
└──────────────────────────────────────────────────────────────────────────┘
```

### Selected State (with AI insight)
```
┌─ CUSTOMER ───────────────────────────────────────────────────────────────┐
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 👤 Sarah Chen                                                  ✕  │  │
│  │    sarah@example.com · 555-123-4567                                │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │ 💡 High-value customer · $4,250 lifetime · Orders monthly    │ │  │
│  │  │    Last order: 12 days ago · Usually buys: Apparel, Drinkware│ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

### Quick-Create Modal
```
┌─────────────────────────────────────────────────┐
│  New Customer                              [✕] │
├─────────────────────────────────────────────────┤
│                                                 │
│  Name *                                         │
│  ┌───────────────────────────────────────────┐  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Email                                          │
│  ┌───────────────────────────────────────────┐  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Phone                                          │
│  ┌───────────────────────────────────────────┐  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ┌─────────────────┐ ┌─────────────────────┐   │
│  │     Cancel      │ │   Add to Order      │   │
│  └─────────────────┘ └─────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Line Items

### Unified List

Products, fees, discounts, and tips all live in a single list:

| Type | Icon | Color | Behavior |
|------|------|-------|----------|
| Product | 📦 | neutral | Has quantity controls |
| Fee | 🚚 | neutral | Fixed or percentage |
| Discount | 🏷️ | `text-success` | Negative amount |
| Tip | 💰 | subtle accent | Always one-off |

### Search Dropdown

```
┌───────────────────────────────────────────────────┐
│  🔍 Search products, fees, discounts...          │
├───────────────────────────────────────────────────┤
│                                                   │
│  PRODUCTS                              [Browse →] │
│  ┌─────────────────────────────────────────────┐  │
│  │ 📦 Premium Tee                      $29.99  │  │
│  │ 📦 Coffee Mug                       $12.00  │  │
│  └─────────────────────────────────────────────┘  │
│                                                   │
│  FEES                                  [Browse →] │
│  ┌─────────────────────────────────────────────┐  │
│  │ 🚚 Rush Delivery                    $25.00  │  │
│  └─────────────────────────────────────────────┘  │
│                                                   │
│  DISCOUNTS                             [Browse →] │
│  ┌─────────────────────────────────────────────┐  │
│  │ 🏷️ Summer Sale                        −10%  │  │
│  └─────────────────────────────────────────────┘  │
│                                                   │
│  ──────────────────────────────────────────────   │
│  │ ✚ Create custom line item...                │  │
└───────────────────────────────────────────────────┘
```

### Browse Drawer (Right Slide)

```
┌─────────────────────────────────────┬──────────────────────────────────────┐
│                                     │                                      │
│  (Terminal still visible,           │  Browse Products                [✕] │
│   slightly dimmed)                  │                                      │
│                                     │  ┌──────────────────────────────┐   │
│                                     │  │ 🔍 Search products...        │   │
│                                     │  └──────────────────────────────┘   │
│                                     │                                      │
│                                     │  ┌─────────────┐ ┌─────────────┐    │
│                                     │  │ Category ▼  │ │ Price ▼     │    │
│                                     │  └─────────────┘ └─────────────┘    │
│                                     │                                      │
│                                     │  ┌────────────────────────────────┐ │
│                                     │  │ ┌────┐ Premium Tee             │ │
│                                     │  │ │ img│ Apparel · $29.99   [+]  │ │
│                                     │  ├────────────────────────────────┤ │
│                                     │  │ ┌────┐ Coffee Mug              │ │
│                                     │  │ │ img│ Drinkware · $12.00 [+]  │ │
│                                     │  └────────────────────────────────┘ │
│                                     │                                      │
│                                     │  [✚ Create New Product]              │
│                                     │                                      │
└─────────────────────────────────────┴──────────────────────────────────────┘
```

### Quick-Create Modal (Tabbed)

```
┌─────────────────────────────────────────────────┐
│  Add Line Item                             [✕] │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────┬──────────┬──────────┬─────────┐  │
│  │ Product  │   Fee    │ Discount │   Tip   │  │
│  └──────────┴──────────┴──────────┴─────────┘  │
│                                                 │
│  Name *                                         │
│  ┌───────────────────────────────────────────┐  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Price *                                        │
│  ┌───────────────────────────────────────────┐  │
│  │  $                                        │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ☑ Save to product catalog                      │
│                                                 │
│  ┌─────────────────┐ ┌─────────────────────┐   │
│  │     Cancel      │ │   Add to Order      │   │
│  └─────────────────┘ └─────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Tab variations:**
- **Fee**: Name, Amount (toggle: Fixed $ / Percentage), Save checkbox
- **Discount**: Name, Amount (toggle: Fixed $ / Percentage), Save checkbox
- **Tip**: Amount only, quick buttons (15%, 18%, 20%, Custom), no save

---

## Order Summary

### Tax Calculation
- Applied to: Products + Fees
- NOT applied to: Tips, Discounts
- Rate from store settings (e.g., 8.25%)

### Button States

| Button | Enabled When | Disabled Helper Text |
|--------|--------------|---------------------|
| Charge Card | Total > $0 | "Add items to charge" |
| Send Payment Link | Total > $0 | "Add items to send link" |
| Email Payment Request | Total > $0 AND customer email | "Add items and customer email" |

---

## Payment Flows

### Card Entry (Bottom Drawer)

Two-column layout: order summary on left, card form on right.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              ─────                                         │
│  Complete Payment                                               [✕]       │
├────────────────────────────────────────┬───────────────────────────────────┤
│                                        │                                   │
│  ┌──────────────────────────────────┐  │  Card information                 │
│  │  👤 Sarah Chen                   │  │                                   │
│  │  sarah@example.com               │  │  ┌─────────────────────────────┐  │
│  └──────────────────────────────────┘  │  │ 💳  4242 4242 4242 4242     │  │
│                                        │  └─────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │                                   │
│  │ ┌────┐                           │  │  ┌────────────┐ ┌────────────┐   │
│  │ │ img│ Premium Tee          × 2  │  │  │ MM / YY    │ │ CVC        │   │
│  │ └────┘ $29.99              $59.98│  │  └────────────┘ └────────────┘   │
│  ├──────────────────────────────────┤  │                                   │
│  │ ┌────┐                           │  │  ┌─────────────────────────────┐  │
│  │ │ img│ Coffee Mug           × 1  │  │  │ Billing ZIP (optional)      │  │
│  │ └────┘ $12.00              $12.00│  │  └─────────────────────────────┘  │
│  └──────────────────────────────────┘  │                                   │
│                                        │  ☑ Save card for Sarah            │
│  Subtotal                     $71.98   │                                   │
│  Summer Sale                  −$7.20   │                                   │
│  Rush Delivery                $25.00   │  ┌─────────────────────────────┐  │
│  Tax                           $7.41   │  │                             │  │
│  Tip                          $10.00   │  │      Pay $107.19            │  │
│  ────────────────────────────────────  │  │                             │  │
│  Total                       $107.19   │  └─────────────────────────────┘  │
│                                        │                                   │
└────────────────────────────────────────┴───────────────────────────────────┘
```

**Card form features:**
- Auto-detect card type (Visa/MC/Amex) from first digits
- Auto-format with spaces
- Auto-advance focus: card → expiry → cvv → zip
- `inputmode="numeric"` for mobile
- Luhn validation before enabling Pay
- "Save card" only visible when customer attached

**AI Integration - Risk Warning:**
```
┌──────────────────────────────────────────────────────────────────────────┐
│ ⚠️ This card was declined 2 times today (insufficient funds)             │
│    Consider: [Send Payment Link] or [Try Different Card]                 │
└──────────────────────────────────────────────────────────────────────────┘
```

### Success State

```
┌────────────────────────────────────────┬───────────────────────────────────┐
│                                        │                                   │
│  (Order summary - same as before)      │  ┌─────────────────────────────┐  │
│                                        │  │                             │  │
│                                        │  │           ✓                 │  │
│                                        │  │                             │  │
│                                        │  │       Approved              │  │
│                                        │  │                             │  │
│                                        │  │       $107.19               │  │
│                                        │  │                             │  │
│                                        │  │  Visa •••• 4242             │  │
│                                        │  │                             │  │
│                                        │  └─────────────────────────────┘  │
│                                        │                                   │
│                                        │  Transaction ID                   │
│                                        │  TXN-2024-ABC123XYZ               │
│                                        │                                   │
│                                        │  January 11, 2026 · 3:42 PM       │
│                                        │                                   │
│                                        │  ┌─────────────────────────────┐  │
│                                        │  │  📧 Email Receipt           │  │
│                                        │  └─────────────────────────────┘  │
│                                        │  ┌─────────────────────────────┐  │
│                                        │  │  🖨️  Print Receipt           │  │
│                                        │  └─────────────────────────────┘  │
│                                        │  ┌─────────────────────────────┐  │
│                                        │  │  ✚ New Transaction          │  │
│                                        │  └─────────────────────────────┘  │
│                                        │                                   │
└────────────────────────────────────────┴───────────────────────────────────┘
```

**AI Integration - Post-Transaction Insight:**
```
┌──────────────────────────────────────────────────────────────────────────┐
│ 💡 Sarah's 24th order · Now in top 5% of customers                       │
│    Consider: [Send Thank You Email] [Add Loyalty Points]                 │
└──────────────────────────────────────────────────────────────────────────┘
```

### Declined State

Same layout but:
- `text-error` styling with ✕ icon
- "Declined" status with reason
- "Try Again" button instead of receipt actions
- Option to try different card

---

## Send Payment Link (Modal)

```
┌─────────────────────────────────────────────────┐
│  Send Payment Link                         [✕] │
├─────────────────────────────────────────────────┤
│                                                 │
│  $107.19 due                                    │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  📋 Copy Link                             │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ── or send directly ──                         │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  📱 SMS to 555-123-4567                   │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  📧 Email to sarah@example.com            │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Link expires in  [7 days ▼]                    │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Email Payment Request (Modal)

```
┌─────────────────────────────────────────────────┐
│  Email Payment Request                     [✕] │
├─────────────────────────────────────────────────┤
│                                                 │
│  To                                             │
│  ┌───────────────────────────────────────────┐  │
│  │  sarah@example.com                        │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Subject                                        │
│  ┌───────────────────────────────────────────┐  │
│  │  Payment request from Acme Store          │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Message (optional)                             │
│  ┌───────────────────────────────────────────┐  │
│  │                                           │  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  ☑ Include itemized order details              │
│  ☐ Allow partial payments                       │
│                                                 │
│  Payment due in  [7 days ▼]                     │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │           Send Payment Request            │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## History Drawer (Right Slide)

```
┌──────────────────────────────────────┐
│  Recent Transactions            [✕] │
├──────────────────────────────────────┤
│                                      │
│  Today                               │
│  ┌────────────────────────────────┐  │
│  │ ✓ $107.19 · Visa 4242         │  │
│  │   Sarah Chen · 3:42 PM        │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ✓ $45.00 · Mastercard 8888    │  │
│  │   Anonymous · 2:15 PM         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 🔗 $250.00 · Pending          │  │
│  │   John Doe · 11:30 AM         │  │
│  └────────────────────────────────┘  │
│                                      │
│  Yesterday                           │
│  ┌────────────────────────────────┐  │
│  │ ✓ $89.50 · Amex 1234          │  │
│  │   Anonymous · 4:20 PM         │  │
│  └────────────────────────────────┘  │
│                                      │
│  [View All Transactions →]           │
│                                      │
└──────────────────────────────────────┘
```

---

## AI Integration

### Feature Registry Entry

```elixir
:terminal_ai  # New feature key for terminal-specific AI
```

### Integration Points

| Feature | Layer | Trigger | Value |
|---------|-------|---------|-------|
| Customer intelligence | 3 | Customer attached | Context for upsell |
| Product suggestions | 2 | Customer + history | Faster order building |
| Card risk warnings | 2 | Card entry + history | Fraud prevention |
| Post-transaction insights | 3 | Payment success | Relationship building |
| Intelligence bar | 1 | Always available | Quick actions |
| Natural language entry | 1 | Search box | Speed for power users |

### Natural Language Line Item Entry

```
┌───────────────────────────────────────────────────────────────────────────┐
│  🔍 "2 premium tees and a coffee mug with 10% off"                       │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  AI understood:                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │ ✓ 2× Premium Tee                                           $59.98  │  │
│  │ ✓ 1× Coffee Mug                                            $12.00  │  │
│  │ ✓ 10% Discount                                             −$7.20  │  │
│  │                                                                     │  │
│  │                                           [Add All] [Edit First]   │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────┘
```

### What AI Does NOT Do
- Generate pricing (compliance risk)
- Auto-apply discounts (merchant controls)
- Block transactions (warns only)
- Chat interface (wrong context)

---

## States & Edge Cases

### Empty State
- Helper text: "Search or add products, fees, and discounts to build an order"
- All payment buttons disabled

### Pending Payment Link/Email
```
┌────────────────────────────────────────────────────────────────────────┐
│ 🔗 Payment link sent · Expires Jan 18                                  │
│    Waiting for payment...                        [Copy Link] [✕]       │
└────────────────────────────────────────────────────────────────────────┘
```

### Processing State
- Spinner replaces Pay button
- All inputs disabled
- Drawer cannot be dismissed
- 30s timeout with cancel option

### Validation Errors
- Inline under inputs
- `text-error` styling
- Pay button disabled until valid

---

## Component Architecture

```
lib/mcp_web/
├── live/
│   └── store/
│       └── terminal_live.ex           # Main LiveView
│
├── components/
│   └── terminal/
│       ├── customer_section.ex        # Customer search/display
│       ├── line_items.ex              # Unified line items list
│       ├── order_summary.ex           # Summary + action buttons
│       ├── search_dropdown.ex         # Unified search with browse
│       ├── browse_drawer.ex           # Full browse with filters
│       ├── quick_create_modal.ex      # Tabbed create modal
│       ├── payment_drawer.ex          # Bottom drawer for card entry
│       ├── payment_success.ex         # Success state in drawer
│       ├── send_link_modal.ex         # Payment link modal
│       ├── email_request_modal.ex     # Email request modal
│       └── history_drawer.ex          # Recent transactions
```

---

## Implementation Checklist

### Phase 1: Core Layout
- [ ] Refactor `terminal_live.ex` to single-screen layout
- [ ] Implement customer section with search
- [ ] Implement line items list (unified)
- [ ] Implement order summary with totals

### Phase 2: Entity Management
- [ ] Implement search dropdown with grouped results
- [ ] Implement browse drawer for products
- [ ] Implement browse drawer for fees/discounts
- [ ] Implement quick-create modal (tabbed)
- [ ] Implement customer quick-create

### Phase 3: Payment Flows
- [ ] Implement payment drawer (bottom, two-column)
- [ ] Card validation and formatting
- [ ] Processing and success states
- [ ] Declined state handling
- [ ] Send payment link modal
- [ ] Email payment request modal

### Phase 4: Polish
- [ ] History drawer
- [ ] Empty states and helper text
- [ ] Button disabled states
- [ ] Pending payment status display
- [ ] Animations and transitions

### Phase 5: AI Integration
- [ ] Customer intelligence card
- [ ] Product suggestions (when customer attached)
- [ ] Card risk warnings
- [ ] Post-transaction insights
- [ ] Natural language line item entry
- [ ] Intelligence bar integration

---

## Design Tokens (DaisyUI)

| Element | Classes |
|---------|---------|
| Customer card | `bg-base-200/50 rounded-xl` |
| Line item row | `border-b border-base-300` |
| Product icon | `text-base-content` |
| Discount amount | `text-success` |
| Total row | `text-xl font-bold` |
| Primary button | `btn btn-primary btn-lg w-full` |
| Secondary button | `btn btn-outline` |
| AI insight | `bg-info/10 border border-info/20 rounded-lg` |
| Warning | `bg-warning/10 border border-warning/20` |
| Drawer | `bg-base-100 shadow-xl rounded-t-2xl` |
| Modal | `modal modal-open` with `modal-box` |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Time to first charge | < 30 seconds (with known product) |
| Clicks to charge | < 5 (product + card + confirm) |
| Error rate | < 2% (validation catches issues) |
| AI suggestion acceptance | > 30% |
| Payment link conversion | > 60% |

---

## Related Documents

- [AI Portal UX Design](docs/plans/2026-01-10-ai-portal-ux-design.md)
- [AI Usage Infrastructure](docs/plans/2026-01-10-ai-usage-infrastructure-design.md)
- [Design Guide](docs/DESIGN_GUIDE.md)
- [POS Live](lib/mcp_web/live/store/pos_live.ex) - Similar patterns
