# AI Portal UX Design

> **Created**: 2026-01-10 | **Status**: Design Complete
> **Track**: AI UX | **Depends On**: [AI Usage Infrastructure](2026-01-10-ai-usage-infrastructure-design.md)
> **Related**: [Portal UI Design](2026-01-10-portal-ui-design.md)

## Design Philosophy

**AI is not a feature - it's the intelligence layer.**

The best AI UX doesn't feel like "using AI" - it feels like the product is just
smarter. Every surface understands natural language and anticipates user needs.

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Ambient Intelligence** | AI insights surface automatically in context, not just when asked |
| **Progressive Depth** | Quick answers inline → deeper exploration in focused mode |
| **Visual Output** | AI shows data (charts, highlights), doesn't just describe it |
| **Zero Friction** | No mode switching, no "ask AI" buttons - intelligence is native |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Portal Intelligence Architecture                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LAYER 1: Universal Intelligence Bar                                         │
│  ├── Persistent in header (always visible)                                   │
│  ├── Instant visual insights + search + actions                              │
│  └── Gateway to deep analysis mode                                           │
│                                                                              │
│  LAYER 2: Contextual Intelligence Annotations                                │
│  ├── Proactive inline insights on dashboards                                 │
│  ├── Pattern detection and anomaly alerts                                    │
│  └── Actionable recommendations in context                                   │
│                                                                              │
│  LAYER 3: Inline Micro-AI                                                    │
│  ├── In-place expansion on data rows                                         │
│  ├── Contextual explanation without modals                                   │
│  └── One-click actions from AI suggestions                                   │
│                                                                              │
│  LAYER 4: Deep Analysis Mode                                                 │
│  ├── Full-page visual analysis                                               │
│  ├── Charts primary, AI explanation supporting                               │
│  └── Follow-up questions for exploration                                     │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                        Shared Infrastructure                                 │
│                                                                              │
│  PortalAiContext → Mcp.Ai.Gateway → Mcp.Chat Domain                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Layer 1: Universal Intelligence Bar

### Purpose

The primary interface for interacting with the platform. Always visible,
instantly responsive, shows visual results not just text.

### Position in Header

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [▾ Acme Corp]                                                                │
│                                                                              │
│  ╭────────────────────────────────────────────────────────────────────────╮  │
│  │ ⌘  Ask anything, search, or take action...                             │  │
│  ╰────────────────────────────────────────────────────────────────────────╯  │
│                                                                              │
│  Dashboard    Products    Stores    Payments    Customers    [?] [🔔] [👤]  │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**
- Bar is **always visible**, not hidden behind an icon
- Signals that intelligence is core to the product
- Keyboard shortcut: `⌘K` / `Ctrl+K`

### Expanded State (On Focus)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [▾ Acme Corp]                                                                │
│                                                                              │
│  ╭────────────────────────────────────────────────────────────────────────╮  │
│  │ ⌘  revenue trend_                                                      │  │
│  ╰────────────────────────────────────────────────────────────────────────╯  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  📊 INSIGHTS                          🔍 SEARCH                        │  │
│  │  ┌─────────────────────────────┐     ┌─────────────────────────────┐  │  │
│  │  │ Revenue Trend (7 days)      │     │ "revenue" in Transactions   │  │  │
│  │  │ ████████████▄▄▄▄           │     │ "revenue" in Reports        │  │  │
│  │  │ $84K → $71K (↓15%)         │     │ "revenue" in Help Docs      │  │  │
│  │  │                             │     │                             │  │  │
│  │  │ 📉 Down 15% vs last week   │     └─────────────────────────────┘  │  │
│  │  │ Top factor: Downtown store  │                                      │  │
│  │  │ had 2 slow days            │     ⚡ ACTIONS                        │  │
│  │  │                             │     ├─ Generate revenue report       │  │
│  │  │ [Deep Dive] [Compare]      │     ├─ Set revenue alert             │  │
│  │  └─────────────────────────────┘     └─ Export revenue data           │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  Dashboard    Products    Stores    Payments    Customers    [?] [🔔] [👤]  │
└──────────────────────────────────────────────────────────────────────────────┘
```

**What Makes This Exceptional:**
- **Instant visual insights** - Charts render immediately, not "let me think..."
- **Parallel results** - Insights, search, and actions shown simultaneously
- **AI explains visually** - The chart IS the answer, text supplements
- **One-click depth** - [Deep Dive] opens focused analysis mode

### Result Types

| Input | Response |
|-------|----------|
| "revenue" | Mini chart + trend + factors + related searches |
| "John Smith" | Customer card preview + recent orders + actions |
| "create invoice" | Action form inline or direct execution |
| "failed transactions" | Filtered list preview + count + deep dive |
| "why is X down" | Analysis card with factors + recommendations |

### States

| State | Behavior |
|-------|----------|
| **Idle** | Placeholder text, subtle glow on focus |
| **Typing** | Live suggestions appear as user types |
| **Loading** | Skeleton cards, typing indicator in insights |
| **Results** | Three-column layout (insights, search, actions) |
| **Deep Query** | Expanded analysis card with follow-up input |
| **Error** | Inline error with retry, fallback to search |

---

## Layer 2: Contextual Intelligence Annotations

### Purpose

Proactive insights that appear inline with content when AI detects something
noteworthy. User doesn't ask - AI observes and surfaces.

### Trigger Conditions

| Trigger | Example |
|---------|---------|
| **Anomaly** | Revenue down but transactions up |
| **Pattern** | 3rd decline from same card today |
| **Threshold** | Inventory below reorder point |
| **Correlation** | Weather affecting foot traffic |
| **Milestone** | Customer reached loyalty tier |

### Design: Dashboard Insight

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Dashboard                                                                   │
│  ─────────────────────────────────────────────────────────────────────────── │
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ $12,847     │ │ 156         │ │ 89          │ │ $82.35      │            │
│  │ Today's Rev │ │ Transactions│ │ Customers   │ │ Avg Order   │            │
│  │ ↓ 12%       │ │ ↑ 8%        │ │ ↓ 3%        │ │ ↑ 5%        │            │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘            │
│        │                                                                     │
│        ▼                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 💡 AI INSIGHT                                                   [×]  │   │
│  │                                                                      │   │
│  │ Revenue is down but transactions are up. Your average order value   │   │
│  │ dropped from $94 to $82 today. This is driven by:                   │   │
│  │                                                                      │   │
│  │ • 23 small orders under $20 (unusual spike)                         │   │
│  │ • Your top customer (Acme Industries) hasn't ordered yet today      │   │
│  │                                                                      │   │
│  │ [View Small Orders]  [Check Acme Industries]              [Dismiss] │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Insight Anatomy

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Icon] [Title]                                              [Dismiss Button] │
│                                                                              │
│ [Primary Observation - what AI noticed]                                      │
│                                                                              │
│ [Contributing Factors - bulleted list]                                       │
│ • Factor 1                                                                   │
│ • Factor 2                                                                   │
│                                                                              │
│ [Action Buttons - investigate or act]                    [Secondary Action]  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Insight Types

| Type | Icon | Color | Purpose |
|------|------|-------|---------|
| **Insight** | 💡 | Blue | Observation worth noting |
| **Alert** | ⚠️ | Amber | Needs attention soon |
| **Warning** | 🚨 | Red | Requires immediate action |
| **Success** | ✅ | Green | Positive milestone reached |
| **Tip** | 💬 | Gray | Suggestion for improvement |

### Behavior

- Insights queue - max 1 visible at a time, others in notification center
- Auto-dismiss after 30 seconds of no interaction (configurable)
- Dismissed insights don't reappear for same data
- "Don't show this type" option for user preferences

---

## Layer 3: Inline Micro-AI

### Purpose

Contextual AI that expands in-place on specific elements. No modals, no
context switching - understanding appears where you need it.

### Design: Transaction Row Expansion

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Recent Transactions                                                         │
├──────────────────────────────────────────────────────────────────────────────┤
│  Time     │ Customer      │ Amount   │ Status       │                        │
│  ─────────┼───────────────┼──────────┼──────────────┼─────────────────────── │
│  2:15 PM  │ Guest         │ $42.00   │ ✗ Declined   │                        │
│           │               │          │              │                        │
│           │ ┌─────────────────────────────────────────────────────────────┐ │
│           │ │ 💳 DECLINE ANALYSIS                                        │ │
│           │ │                                                             │ │
│           │ │ Reason: Insufficient funds (code: 51)                      │ │
│           │ │                                                             │ │
│           │ │ This is the 3rd decline from this card today.              │ │
│           │ │ Pattern suggests customer may have reached credit limit.   │ │
│           │ │                                                             │ │
│           │ │ SUGGESTED ACTIONS                                          │ │
│           │ │ ├─ Send payment link (alternative method)                  │ │
│           │ │ ├─ Offer payment plan                                      │ │
│           │ │ └─ View full card history                                  │ │
│           │ │                                                             │ │
│           │ └─────────────────────────────────────────────────────────────┘ │
│  2:21 PM  │ M. Lee        │ $89.50   │ ✓ Completed  │                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Trigger Methods

| Method | When |
|--------|------|
| **Auto-expand** | Failed transactions, anomalies |
| **Click row** | User clicks to see details |
| **Hover + delay** | 500ms hover shows preview |
| **Keyboard** | Arrow keys + Enter to expand |

### Design: Customer Card Micro-AI

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Customer: John Smith                                                       │
│  ───────────────────────────────────────────────────────────────────────── │
│                                                                             │
│  ┌─────────────────────────┐  ┌──────────────────────────────────────────┐ │
│  │ 👤 John Smith           │  │ 🤖 AI SUMMARY                            │ │
│  │                         │  │                                          │ │
│  │ $4,250 lifetime value   │  │ High-value customer (top 5%)             │ │
│  │ 23 orders               │  │ Orders every 2-3 weeks (consistent)      │ │
│  │ Member since 2024       │  │ Prefers premium products                 │ │
│  │                         │  │                                          │ │
│  │ Status: ⚠️ At Risk      │  │ ⚠️ Last order was 45 days ago            │ │
│  │                         │  │ (Usually orders every 18 days)           │ │
│  │ [View Profile]          │  │                                          │ │
│  │ [Create Order]          │  │ [Send Re-engagement Email]               │ │
│  └─────────────────────────┘  └──────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Design: Stat Card Expansion

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐│
│  │  $12,847                                                               ││
│  │  Today's Revenue                                                       ││
│  │  ↓ 12% vs yesterday                                                    ││
│  │                                                                        ││
│  │  ┌──────────────────────────────────────────────────────────────────┐ ││
│  │  │ 📉 WHY IS REVENUE DOWN?                                          │ ││
│  │  │                                                                  │ ││
│  │  │ Three factors contributing to today's 12% decline:               │ ││
│  │  │                                                                  │ ││
│  │  │ 1. Downtown store opened late (lost $800 morning sales)          │ ││
│  │  │ 2. 4 large B2B orders from yesterday didn't repeat               │ ││
│  │  │ 3. Higher decline rate (8% vs usual 3%)                          │ ││
│  │  │                                                                  │ ││
│  │  │ ███████████░░░░░░░░░░░░ Yesterday: $14,592                      │ ││
│  │  │ █████████░░░░░░░░░░░░░░ Today:     $12,847                      │ ││
│  │  │                                                                  │ ││
│  │  │ [Deep Dive]  [View Declined]  [Compare Stores]                   │ ││
│  │  └──────────────────────────────────────────────────────────────────┘ ││
│  └────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Layer 4: Deep Analysis Mode

### Purpose

Full-page exploration for complex questions. Charts and data are primary,
AI explanation supports. Allows follow-up questions for deeper investigation.

### Design

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  ← Back to Dashboard                          Revenue Analysis    [Export]   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────┐  ┌──────────────────────────────┐  │
│  │         REVENUE TREND               │  │  KEY FINDINGS                │  │
│  │                                     │  │                              │  │
│  │  $100K ┤                            │  │  1. Downtown store revenue   │  │
│  │        │    ╭───╮                   │  │     down 23% this week       │  │
│  │   $75K ┤   ╱    ╲    ╭──           │  │                              │  │
│  │        │  ╱      ╲  ╱              │  │  2. Online store up 15%      │  │
│  │   $50K ┤─╱        ╲╱               │  │     (offsetting some loss)   │  │
│  │        │                            │  │                              │  │
│  │        ├────┬────┬────┬────┬────┤  │  │  3. Avg ticket down $12      │  │
│  │        Mon  Tue  Wed  Thu  Fri      │  │     (more small purchases)   │  │
│  │                                     │  │                              │  │
│  └─────────────────────────────────────┘  └──────────────────────────────┘  │
│                                                                              │
│  ┌─────────────────────────────────────┐  ┌──────────────────────────────┐  │
│  │         BY STORE                    │  │  BY CATEGORY                 │  │
│  │                                     │  │                              │  │
│  │  Downtown   ████████████░░  $42K    │  │  Electronics  ████████ $38K  │  │
│  │  Online     ██████████████  $51K    │  │  Apparel      ██████   $29K  │  │
│  │  Mall       ████████░░░░░░  $28K    │  │  Accessories  ████     $18K  │  │
│  │                                     │  │  Other        ██       $8K   │  │
│  └─────────────────────────────────────┘  └──────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  🤖 ANALYSIS                                                          │  │
│  │                                                                       │  │
│  │  The revenue dip on Wednesday correlates with severe weather in your │  │
│  │  downtown area. Foot traffic data shows 40% fewer visitors. Your     │  │
│  │  online store picked up some slack but not enough to compensate.     │  │
│  │                                                                       │  │
│  │  RECOMMENDATION: Consider a "rainy day" promotion for downtown that  │  │
│  │  triggers automatically based on weather forecasts.                  │  │
│  │                                                                       │  │
│  │  ╭─────────────────────────────────────────────────────────────────╮ │  │
│  │  │ Ask a follow-up question...                                     │ │  │
│  │  ╰─────────────────────────────────────────────────────────────────╯ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Key Elements

| Element | Purpose |
|---------|---------|
| **Back navigation** | Return to origin (Dashboard, etc.) |
| **Export** | Download charts, data, analysis as PDF/CSV |
| **Primary charts** | Visual data is the main content |
| **Key findings** | AI-extracted bullet points |
| **Analysis section** | Longer-form AI explanation |
| **Follow-up input** | Ask deeper questions without leaving |

---

## Component Architecture

```
lib/mcp_web/
├── components/
│   └── ai/
│       ├── intelligence_bar.ex       # Layer 1: Header search/AI bar
│       ├── intelligence_results.ex   # Results panel (insights, search, actions)
│       ├── insight_card.ex           # Layer 2: Proactive insight annotations
│       ├── micro_ai.ex               # Layer 3: Inline expansions
│       ├── analysis_view.ex          # Layer 4: Deep analysis page
│       ├── ai_chart.ex               # Mini charts for AI responses
│       └── ai_action.ex              # Action buttons in AI responses
│
├── live/
│   ├── components/
│   │   └── portal_ai_context.ex      # Shared AI state management
│   │
│   └── analysis/
│       ├── revenue_analysis_live.ex  # Deep dive: Revenue
│       ├── customer_analysis_live.ex # Deep dive: Customer
│       └── transaction_analysis_live.ex
│
└── hooks/
    └── intelligence_bar_hook.js      # Keyboard shortcuts, focus management
```

---

## Shared State: PortalAiContext

```elixir
defmodule McpWeb.PortalAiContext do
  @moduledoc """
  Manages AI state across all portal LiveViews.
  Provides context to AI for relevant responses.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign(:ai_context, build_context(session, socket))
      |> assign(:ai_insights, [])           # Queued proactive insights
      |> assign(:ai_expanded_items, [])     # Currently expanded micro-AI
      |> assign(:intelligence_bar_open, false)
      |> assign(:intelligence_bar_query, "")
      |> assign(:intelligence_bar_results, nil)

    {:cont, socket}
  end

  defp build_context(session, socket) do
    %{
      # Identity
      tenant_id: session["tenant_id"],
      merchant_id: socket.assigns[:merchant_id],
      store_id: socket.assigns[:store_id],
      user_id: session["current_user_id"],

      # Current location
      page: nil,              # :dashboard, :transactions, :customers, etc.
      page_data: %{},         # Page-specific metrics for AI context

      # User state
      selected_entities: [],  # For bulk AI actions
      filters_applied: %{},   # Current filters for context

      # Session
      conversation_id: nil,   # Persists for follow-ups
      last_query: nil,
      timestamp: DateTime.utc_now()
    }
  end

  # Called by each LiveView to set page context
  def set_page(socket, page, page_data \\ %{}) do
    context =
      socket.assigns.ai_context
      |> Map.put(:page, page)
      |> Map.put(:page_data, page_data)
      |> Map.put(:timestamp, DateTime.utc_now())

    # Trigger insight generation for new page
    insights = generate_insights_for_page(context)

    socket
    |> assign(:ai_context, context)
    |> assign(:ai_insights, insights)
  end

  defp generate_insights_for_page(context) do
    # This calls the AI to check for noteworthy patterns
    # Returns list of insight structs to display
    Mcp.Ai.Insights.generate_for_context(context)
  end
end
```

---

## AI Tools for Portal

New tools to add to LangChain for portal actions:

```elixir
# lib/mcp/portal/tools/

# Search & Query
defmodule Mcp.Portal.Tools.SearchTransactions do
  @doc "Search transactions with natural language"
  # "failed transactions last week" → filtered query
end

defmodule Mcp.Portal.Tools.SearchCustomers do
  @doc "Find customers by name, email, or attributes"
end

defmodule Mcp.Portal.Tools.SearchProducts do
  @doc "Find products by name, SKU, or description"
end

# Analysis
defmodule Mcp.Portal.Tools.AnalyzeRevenue do
  @doc "Analyze revenue trends and find contributing factors"
end

defmodule Mcp.Portal.Tools.AnalyzeCustomer do
  @doc "Generate customer profile summary and predictions"
end

defmodule Mcp.Portal.Tools.CompareMetrics do
  @doc "Compare two time periods or entities"
end

# Actions
defmodule Mcp.Portal.Tools.CreateInvoice do
  @doc "Create a new invoice"
end

defmodule Mcp.Portal.Tools.ProcessRefund do
  @doc "Process a refund for a transaction"
end

defmodule Mcp.Portal.Tools.SendPaymentLink do
  @doc "Send a payment link to a customer"
end

# Navigation
defmodule Mcp.Portal.Tools.NavigateTo do
  @doc "Navigate to a specific page or entity"
end
```

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Create `PortalAiContext` on_mount hook
- [ ] Add AI context to MerchantShell and StoreShell
- [ ] Create `IntelligenceBar` component (search only first)
- [ ] Wire `⌘K` keyboard shortcut via JS hook
- [ ] Create basic results panel layout

### Phase 2: Intelligence Bar Full
- [ ] Add AI query processing via Gateway
- [ ] Implement instant visual results (mini charts)
- [ ] Add search results column
- [ ] Add actions column
- [ ] Implement loading/error states

### Phase 3: Proactive Insights
- [ ] Create `InsightCard` component
- [ ] Implement `Mcp.Ai.Insights` module
- [ ] Add insight generation on page load
- [ ] Add insight queue management
- [ ] Implement dismiss/preferences

### Phase 4: Micro-AI
- [ ] Create `MicroAi` component for row expansion
- [ ] Add to transaction tables
- [ ] Add to customer cards
- [ ] Add to stat cards
- [ ] Implement auto-expand for anomalies

### Phase 5: Deep Analysis
- [ ] Create `AnalysisView` layout component
- [ ] Implement Revenue analysis page
- [ ] Implement Customer analysis page
- [ ] Add follow-up question capability
- [ ] Add export functionality

### Phase 6: Portal Tools
- [ ] Implement search tools
- [ ] Implement analysis tools
- [ ] Implement action tools
- [ ] Add tool result rendering
- [ ] Test end-to-end flows

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Time to insight | < 500ms for common queries |
| AI usage rate | > 40% of sessions use AI features |
| Insight relevance | > 80% of insights not dismissed |
| Action completion | > 60% of AI-suggested actions taken |
| User satisfaction | NPS > 50 for AI features |

---

## Related Documents

- [AI Usage Infrastructure](2026-01-10-ai-usage-infrastructure-design.md)
- [Portal UI Design](2026-01-10-portal-ui-design.md)
- [Portal Skeleton Implementation](2026-01-10-portal-skeleton-implementation.md)
- [AshAi Strategy](../implement/ASH_AI_STRATEGY.md)
