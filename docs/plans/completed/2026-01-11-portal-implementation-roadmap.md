# Portal Implementation Roadmap

> **Created**: 2026-01-11 | **Status**: Active
> **Purpose**: Phased rollout plan for Merchant and Store portal features

## Overview

This document outlines the implementation sequence for portal features across six phases. Each phase builds on the previous, with clear dependencies and deliverables.

**Related Design Documents:**
- `2026-01-10-ai-portal-ux-design.md` - AI-first UX patterns
- `2026-01-10-ai-usage-infrastructure-design.md` - AI billing/metering
- `2026-01-11-merchant-portal-features.md` - Merchant portal specification
- `2026-01-11-store-portal-features.md` - Store portal specification

---

## Phase Summary

| Phase | Focus | Est. Effort | Dependencies |
|-------|-------|-------------|--------------|
| **1** | Layout Foundation | 2-3 days | None |
| **2** | Core Commerce | 1-2 weeks | Phase 1 |
| **3** | Order Flow | 1 week | Phase 2 |
| **4** | AI Infrastructure | 1 week | Phase 2 |
| **5** | AI UX Features | 1-2 weeks | Phase 4 |
| **6** | Remaining Features | 2-3 weeks | Phase 1-3 |

---

## Phase 1: Layout Foundation

**Goal:** Build reusable layout components that all feature pages use.

### Deliverables

| Component | Description | Used By |
|-----------|-------------|---------|
| `PageLayout` | Main content area with layout variants | All pages |
| `StatsRow` | 4-card metric row at top of pages | All pages |
| `ActionSidebar` | Quick actions + filters for 2/3+1/3 layouts | List/Detail pages |
| `DataTable` | Full-width table with pagination | Transaction, Inventory pages |
| `FocusedLayout` | No-sidebar layout for POS, Terminal | POS, Terminal, Wizards |

### Layout Variants

```
Template A: Full-Width Dashboard  → PageLayout.dashboard/1
Template B: 2/3 + 1/3 List        → PageLayout.list/1
Template C: 2/3 + 1/3 Detail      → PageLayout.detail/1
Template D: Full-Width Table      → PageLayout.table/1
Template E: Focused Mode          → PageLayout.focused/1
Template F: Calendar/Map          → PageLayout.calendar/1
```

### Success Criteria
- [ ] Each layout variant renders correctly
- [ ] Stats row displays 4 metrics with trends
- [ ] Action sidebar supports Quick Actions, Filters, AI Insights sections
- [ ] Layouts responsive on mobile (sidebar collapses)

---

## Phase 2: Core Commerce

**Goal:** Implement the critical path for taking payments.

### Deliverables

| Feature | Portal | Layout | Priority |
|---------|--------|--------|----------|
| **POS** | Store | E (Focused) | P0 |
| **Terminal** | Store | E (Focused) | P0 |
| **Customer List** | Both | B (2/3+1/3 List) | P0 |
| **Customer Detail** | Both | C (2/3+1/3 Detail) | P0 |
| **Transactions List** | Merchant | D (Full-Width Table) | P0 |
| **Transaction Detail** | Merchant | C (2/3+1/3 Detail) | P0 |

### POS Flow
```
Product Grid → Add to Cart → Customer Lookup (optional) → Payment → Receipt
```

### Terminal Flow
```
Enter Amount → Customer Info (optional) → Card Entry → Process → Receipt
```

### Success Criteria
- [ ] Complete a POS sale with card payment
- [ ] Complete a Terminal transaction
- [ ] Create and view customers
- [ ] View transaction list with filters
- [ ] View transaction detail with timeline

---

## Phase 3: Order Flow

**Goal:** Complete the commerce cycle with orders, invoices, refunds.

### Deliverables

| Feature | Portal | Layout | Priority |
|---------|--------|--------|----------|
| **Order Queue** | Store | B (2/3+1/3 List) | P0 |
| **Order Detail** | Store | C (2/3+1/3 Detail) | P0 |
| **Order List** | Merchant | B (2/3+1/3 List) | P0 |
| **Invoice List** | Store | B (2/3+1/3 List) | P0 |
| **Invoice Builder** | Store | E (Focused) | P0 |
| **Invoice Detail** | Store | C (2/3+1/3 Detail) | P0 |
| **Refund List** | Store | B (2/3+1/3 List) | P0 |
| **Process Refund** | Store | E (Focused) | P0 |

### Success Criteria
- [ ] Create order from POS sale
- [ ] View and manage order queue
- [ ] Create and send invoice
- [ ] Process refund for transaction

---

## Phase 4: AI Infrastructure

**Goal:** Build the foundation for AI features (metering, billing, rate limits).

### Deliverables

From `ai-usage-infrastructure-design.md`:

| Component | Description |
|-----------|-------------|
| `LlmUsage` resource | Track all AI interactions |
| `AiPlan` configuration | Define plan limits (tokens, requests) |
| Rate limiter | Enforce per-tenant limits |
| Usage aggregation | Oban job for billing period summaries |
| Billing hooks | Integration points for Stripe metering |

### Success Criteria
- [ ] All AI calls logged to LlmUsage
- [ ] Rate limiting enforced per tenant/plan
- [ ] Usage visible in Settings > Billing
- [ ] Overage handling (soft limit, hard limit)

---

## Phase 5: AI UX Features

**Goal:** Implement AI-first UX patterns from `ai-portal-ux-design.md`.

### Deliverables

| Feature | Description | Integration Points |
|---------|-------------|-------------------|
| **Intelligence Bar** | ⌘K command palette | Global (both portals) |
| **Proactive Insights** | AI-generated cards | Dashboard pages |
| **Inline Micro-AI** | Row expansion insights | List pages |
| **Deep Analysis** | Full-page AI view | Detail pages |

### Rollout Strategy
1. Intelligence Bar first (universal entry point)
2. Dashboard insights (high visibility)
3. Inline micro-AI (per-feature enhancement)
4. Deep analysis (advanced users)

### Success Criteria
- [ ] ⌘K opens Intelligence Bar from anywhere
- [ ] Natural language queries return results
- [ ] Dashboard shows AI insight cards
- [ ] Usage tracked and rate-limited correctly

---

## Phase 6: Remaining Features

**Goal:** Complete all P1/P2 features from portal specifications.

### Merchant Portal

| Section | Features |
|---------|----------|
| **Products** | List, Detail, Categories, Inventory, Import/Export |
| **Stores** | List, Configuration, Hardware |
| **Payments** | Settlements, Payouts, Chargebacks, MIDs |
| **Reports** | Sales, Payments, Inventory, Customers |
| **Team** | Users, Roles, Activity Log |
| **Settings** | Business, Branding, Notifications, Integrations, API |

### Store Portal

| Section | Features |
|---------|----------|
| **Products** | Search (read-only view) |
| **Inventory** | Stock Levels, Adjust, Receive |
| **Subscriptions** | List, Detail, Renewal |
| **Loyalty** | Points Lookup, Redemption, Enrollment |
| **Appointments** | Calendar, Booking (Services vertical) |
| **Tables** | Map, Assign (Restaurant vertical) |
| **Staff** | Clock, Schedule, Time Log |
| **Tips** | Entry, Distribution |
| **Reports** | Daily Summary, Shift Report, Close Register |

---

## Implementation Notes

### Component Reuse Strategy

Many components are shared between portals:

| Component | Merchant | Store |
|-----------|----------|-------|
| CustomerList | ✓ | ✓ (simplified) |
| CustomerDetail | ✓ | ✓ (card view) |
| OrderList | ✓ | ✓ (queue view) |
| OrderDetail | ✓ | ✓ |
| ProductList | ✓ (full) | ✓ (read-only) |

### Vertical Configuration

Store portal features vary by vertical:

| Feature | Retail | Restaurant | Services | Subscription |
|---------|--------|------------|----------|--------------|
| Orders | ✓ | ✓ | - | - |
| Invoices | ✓ | - | ✓ | ✓ |
| Appointments | - | - | ✓ | - |
| Tables | - | ✓ | - | - |
| Subscriptions | - | - | - | ✓ |

### Testing Strategy

Each phase should include:
- Unit tests for components
- Integration tests for flows (POS sale, refund, etc.)
- LiveView tests for interactive features
- AI feature tests with mocked LLM responses

---

## Current Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Layout Foundation | **NOT STARTED** | Next up |
| 2 - Core Commerce | NOT STARTED | |
| 3 - Order Flow | NOT STARTED | |
| 4 - AI Infrastructure | NOT STARTED | |
| 5 - AI UX Features | NOT STARTED | |
| 6 - Remaining Features | NOT STARTED | |

---

## Quick Reference

**Start here:** Phase 1 implementation plan at `2026-01-11-phase1-layout-foundation.md`

**Design specs:**
- Layouts: See "Page Layout Templates" section in portal feature docs
- AI UX: See `2026-01-10-ai-portal-ux-design.md`
- AI Billing: See `2026-01-10-ai-usage-infrastructure-design.md`
