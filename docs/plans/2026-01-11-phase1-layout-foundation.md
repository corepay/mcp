# Phase 1: Layout Foundation Implementation Plan

> **Created**: 2026-01-11 | **Status**: Ready for Implementation
> **Estimated Effort**: 2-3 days
> **Dependencies**: None (foundational)

## Overview

Build the reusable layout components that all portal feature pages will use. This phase creates the structural foundation for Templates A-F defined in the portal feature specifications.

---

## Task Breakdown

### Task 1: StatsRow Component

**Purpose:** Display 4 key metrics at the top of every content page.

**File:** `lib/mcp_web/components/portal/stats_row.ex`

**Interface:**
```elixir
<.stats_row>
  <.stat label="Revenue" value="$12,847" trend={+12} comparison="vs yesterday" />
  <.stat label="Transactions" value="156" trend={+8} comparison="vs yesterday" />
  <.stat label="Customers" value="89" trend={-3} comparison="vs yesterday" />
  <.stat label="Avg Order" value="$82.35" trend={+5} comparison="vs yesterday" />
</.stats_row>
```

**Props:**
| Prop | Type | Description |
|------|------|-------------|
| `label` | string | Metric name |
| `value` | string | Formatted value |
| `trend` | integer | Percentage change (+/-) |
| `comparison` | string | Comparison period text |
| `icon` | atom | Optional icon |
| `href` | string | Optional link to detail |

**Styling:**
- 4-column grid, responsive to 2x2 on mobile
- Trend arrow: green up, red down, gray neutral
- Subtle card with hover state if clickable

**Verification:**
```bash
# Add to Storybook or create test page
mix phx.server
# Visit /dev/components/stats-row
```

---

### Task 2: ActionSidebar Component

**Purpose:** Quick Actions + Filters + AI Insights panel for 2/3+1/3 layouts.

**File:** `lib/mcp_web/components/portal/action_sidebar.ex`

**Interface:**
```elixir
<.action_sidebar>
  <:actions>
    <.sidebar_action icon={:plus} label="Add New" href={~p"/products/new"} />
    <.sidebar_action icon={:upload} label="Import" phx-click="open_import" />
    <.sidebar_action icon={:pencil_square} label="Bulk Edit" href={~p"/products/bulk"} />
  </:actions>

  <:filters>
    <.sidebar_filter label="Status" options={@status_options} field={:status} />
    <.sidebar_filter label="Category" options={@category_options} field={:category} />
  </:filters>

  <:insights>
    <.ai_insight
      message="3 products are low on stock"
      action="View low stock"
      href={~p"/products?filter=low_stock"}
    />
  </:insights>
</.action_sidebar>
```

**Sections:**
1. **QUICK ACTIONS** - Primary action buttons (icon + label)
2. **FILTERS** - Dropdown/checkbox filters
3. **AI INSIGHTS** - Proactive insight cards (optional)

**Styling:**
- Fixed width: 280px
- Sticky positioning (scrolls with page)
- Section dividers with muted headers
- Collapses to drawer on mobile

**Verification:**
```bash
mix phx.server
# Visit /dev/components/action-sidebar
```

---

### Task 3: PageLayout Component

**Purpose:** Main layout wrapper with variants for all template types.

**File:** `lib/mcp_web/components/portal/page_layout.ex`

**Variants:**

#### A: Dashboard Layout
```elixir
<.page_layout variant={:dashboard} title="Dashboard">
  <:stats>
    <.stats_row>...</.stats_row>
  </:stats>

  <:content>
    <!-- Full-width content area -->
  </:content>
</.page_layout>
```

#### B: List Layout (2/3 + 1/3)
```elixir
<.page_layout variant={:list} title="Products">
  <:stats>
    <.stats_row>...</.stats_row>
  </:stats>

  <:toolbar>
    <.search_input placeholder="Search products..." />
    <.button>+ Add Product</.button>
  </:toolbar>

  <:content>
    <!-- 2/3 width main content -->
    <.data_table rows={@products}>...</.data_table>
  </:content>

  <:sidebar>
    <.action_sidebar>...</.action_sidebar>
  </:sidebar>
</.page_layout>
```

#### C: Detail Layout (2/3 + 1/3)
```elixir
<.page_layout variant={:detail} title={@product.name} back={~p"/products"}>
  <:stats>
    <.stats_row>...</.stats_row>
  </:stats>

  <:toolbar>
    <.button variant={:secondary}>Edit</.button>
    <.dropdown_menu>...</.dropdown_menu>
  </:toolbar>

  <:content>
    <!-- 2/3 width detail content -->
  </:content>

  <:sidebar>
    <.action_sidebar>...</.action_sidebar>
  </:sidebar>
</.page_layout>
```

#### D: Table Layout (Full-Width)
```elixir
<.page_layout variant={:table} title="Transactions">
  <:stats>
    <.stats_row>...</.stats_row>
  </:stats>

  <:toolbar>
    <.search_input />
    <.filter_dropdown field={:status} options={@status_options} />
    <.date_range_picker />
    <.button variant={:secondary} icon={:arrow_down_tray}>Export</.button>
  </:toolbar>

  <:content>
    <!-- Full-width table -->
    <.data_table rows={@transactions} columns={@columns}>...</.data_table>
  </:content>
</.page_layout>
```

#### E: Focused Layout (No Sidebar)
```elixir
<.page_layout variant={:focused} title="Point of Sale" exit={~p"/dashboard"}>
  <:content>
    <!-- Full-screen focused content -->
  </:content>
</.page_layout>
```

#### F: Calendar Layout
```elixir
<.page_layout variant={:calendar} title="Appointments">
  <:stats>
    <.stats_row>...</.stats_row>
  </:stats>

  <:toolbar>
    <.calendar_nav date={@current_date} view={@view} />
    <.button>+ New Appointment</.button>
  </:toolbar>

  <:content>
    <!-- Full-width calendar -->
    <.calendar events={@appointments} />
  </:content>
</.page_layout>
```

**Verification:**
```bash
mix phx.server
# Visit /dev/layouts to see all variants
```

---

### Task 4: DataTable Component

**Purpose:** Full-featured data table for list and table layouts.

**File:** `lib/mcp_web/components/portal/data_table.ex`

**Interface:**
```elixir
<.data_table
  id="transactions-table"
  rows={@streams.transactions}
  row_click={fn txn -> JS.navigate(~p"/payments/transactions/#{txn.id}") end}
>
  <:col :let={txn} label="ID" field={:id}>
    <span class="font-mono text-sm"><%= txn.reference_id %></span>
  </:col>

  <:col :let={txn} label="Customer" field={:customer}>
    <%= txn.customer_name || "Guest" %>
  </:col>

  <:col :let={txn} label="Amount" field={:amount} align={:right}>
    <.money value={txn.amount} />
  </:col>

  <:col :let={txn} label="Status" field={:status}>
    <.status_badge status={txn.status} />
  </:col>

  <:col :let={txn} label="Method" field={:payment_method}>
    <.payment_method_icon method={txn.payment_method} />
  </:col>

  <:col :let={txn} label="Time" field={:inserted_at} align={:right}>
    <.relative_time datetime={txn.inserted_at} />
  </:col>

  <:action :let={txn}>
    <.dropdown_menu>
      <:item href={~p"/payments/transactions/#{txn.id}"}>View</:item>
      <:item phx-click="refund" phx-value-id={txn.id}>Refund</:item>
    </.dropdown_menu>
  </:action>
</.data_table>

<.pagination
  page={@page}
  total_pages={@total_pages}
  total_count={@total_count}
/>
```

**Features:**
- Sortable columns (click header)
- Row click navigation
- Streaming support (`phx-update="stream"`)
- Empty state
- Loading state
- Bulk selection (optional)
- Row actions dropdown

**Verification:**
```bash
mix test test/mcp_web/components/portal/data_table_test.exs
```

---

### Task 5: FocusedLayout Component

**Purpose:** Distraction-free layout for POS, Terminal, Wizards.

**File:** `lib/mcp_web/components/portal/focused_layout.ex`

**Interface:**
```elixir
<.focused_layout
  title="Point of Sale"
  exit={~p"/dashboard"}
  show_intelligence_bar={true}
>
  <:left_panel>
    <!-- Product grid, form, etc. -->
  </:left_panel>

  <:right_panel>
    <!-- Cart, summary, etc. -->
  </:right_panel>
</.focused_layout>
```

**Variations:**
- Two-panel (POS): 60/40 split
- Centered (Terminal): Single centered panel
- Wizard (multi-step): Progress indicator + centered content

**Header:**
- Exit button (← Back or X)
- Title (centered)
- Minimal actions (⌘K, user menu only)

**Verification:**
```bash
mix phx.server
# Visit /dev/layouts/focused
```

---

### Task 6: Integration with Existing Shells

**Purpose:** Ensure layouts work within MerchantShell and StoreShell.

**Files to modify:**
- `lib/mcp_web/components/layouts/merchant_shell.ex`
- `lib/mcp_web/components/layouts/store_shell.ex`

**Changes:**
1. Shells provide navigation (top nav / sidebar)
2. PageLayout provides content structure
3. FocusedLayout replaces shell entirely (exits to dashboard)

**Pattern:**
```elixir
# Normal pages use shell + page_layout
defmodule McpWeb.Merchant.Products.IndexLive do
  use McpWeb, :live_view

  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Products">
      ...
    </.page_layout>
    """
  end
end

# Focused pages bypass shell
defmodule McpWeb.Store.PosLive do
  use McpWeb, :live_view

  # Use focused layout instead of shell
  layout {McpWeb.Layouts, :focused}

  def render(assigns) do
    ~H"""
    <.focused_layout title="POS" exit={~p"/dashboard"}>
      ...
    </.focused_layout>
    """
  end
end
```

---

### Task 7: Responsive Behavior

**Purpose:** Ensure all layouts work on tablet and mobile.

**Breakpoints:**
| Breakpoint | Width | Behavior |
|------------|-------|----------|
| Desktop | ≥1024px | Full layout |
| Tablet | 768-1023px | Sidebar collapses to overlay |
| Mobile | <768px | Single column, bottom sheet actions |

**Changes:**
1. ActionSidebar → Slide-out drawer on mobile
2. StatsRow → 2x2 grid on mobile
3. DataTable → Horizontal scroll or card view
4. FocusedLayout → Stack panels vertically

**Implementation:**
- Use Tailwind responsive classes
- Add `useMediaQuery` hook for JS-driven changes
- Test with browser dev tools

---

## File Structure

```
lib/mcp_web/components/portal/
├── stats_row.ex          # Task 1
├── action_sidebar.ex     # Task 2
├── page_layout.ex        # Task 3
├── data_table.ex         # Task 4
├── focused_layout.ex     # Task 5
├── pagination.ex         # Supporting component
├── filter_dropdown.ex    # Supporting component
└── search_input.ex       # Supporting component
```

---

## Testing Strategy

### Unit Tests
```elixir
# test/mcp_web/components/portal/stats_row_test.exs
describe "stats_row" do
  test "renders 4 stats with trends"
  test "shows positive trend in green"
  test "shows negative trend in red"
  test "links to detail when href provided"
end

# test/mcp_web/components/portal/page_layout_test.exs
describe "page_layout" do
  test "renders dashboard variant"
  test "renders list variant with sidebar"
  test "renders detail variant with back link"
  test "renders table variant full-width"
  test "renders focused variant without shell"
end
```

### Visual Tests (Storybook or Dev Page)
Create `/dev/components` route with all components displayed:
- Stats row with various trend values
- Action sidebar with all section types
- Each page layout variant
- Data table with sample data
- Responsive behavior at each breakpoint

---

## Definition of Done

- [ ] All 5 core components implemented
- [ ] Components follow DaisyUI/Tailwind patterns from DESIGN_GUIDE.md
- [ ] Unit tests passing
- [ ] Visual dev page created at `/dev/components`
- [ ] Responsive behavior verified at all breakpoints
- [ ] Integration with shells verified
- [ ] Documentation in component files

---

## Next Steps After Phase 1

Once complete, move to **Phase 2: Core Commerce**:
1. Implement POS using FocusedLayout
2. Implement Terminal using FocusedLayout
3. Implement Customer List using PageLayout variant :list
4. Implement Transactions using PageLayout variant :table

See `2026-01-11-portal-implementation-roadmap.md` for full phase plan.
