# Portal Components - Responsive Behavior Guide

This guide documents the responsive behavior of all portal components created for the MSP platform.

## Quick Reference

| Component | Mobile (<768px) | Tablet (768-1023px) | Desktop (≥1024px) |
|-----------|-----------------|---------------------|-------------------|
| **StatsRow** | 2x2 grid | 4 columns | 4 columns |
| **PageLayout (list/detail)** | Stacked | Stacked | 2/3 + 1/3 split |
| **ActionSidebar** | Below content | Below content | Right column |
| **DataTable** | Horizontal scroll | Horizontal scroll | Full table |
| **FocusedLayout (two_panel)** | Stacked | 60/40 split | 60/40 split |

## Detailed Breakdowns

### StatsRow Component

**Purpose:** Display key metrics in a responsive grid

**Responsive Classes:**
```elixir
"grid grid-cols-2 md:grid-cols-4 gap-4"
```

**Behavior:**
- **Mobile (<768px):** 2 columns in a 2x2 grid
- **Tablet (≥768px):** 4 columns in a single row
- **Desktop (≥1024px):** 4 columns in a single row

**Example Usage:**
```elixir
<.stats_row>
  <.stat label="Revenue" value="$12,847" trend={12} />
  <.stat label="Transactions" value="156" trend={8} />
  <.stat label="Customers" value="89" trend={-3} />
  <.stat label="Avg Order" value="$82.35" trend={5} />
</.stats_row>
```

**Testing:** Resize browser to see stats reflow from 4 columns → 2x2 grid

---

### PageLayout Component

**Purpose:** Consistent page structure with multiple variants

**Responsive Classes (list/detail variants):**
```elixir
"grid grid-cols-1 lg:grid-cols-3 gap-6"
```

**Behavior:**

#### Dashboard Variant (`:dashboard`)
- **All breakpoints:** Full-width content area
- No sidebar support

#### List Variant (`:list`)
- **Mobile/Tablet (<1024px):** Single column (content stacks above sidebar)
- **Desktop (≥1024px):** 2/3 width content + 1/3 width sidebar

#### Detail Variant (`:detail`)
- **Mobile/Tablet (<1024px):** Single column with back button
- **Desktop (≥1024px):** 2/3 width content + 1/3 width sidebar
- Back navigation button always visible

#### Table Variant (`:table`)
- **All breakpoints:** Full-width content area
- No sidebar support

**Example Usage:**
```elixir
<.page_layout variant={:list} title="Products">
  <:toolbar>
    <.search_input placeholder="Search..." />
    <.button>+ Add</.button>
  </:toolbar>

  <:content>Product list</:content>

  <:sidebar>
    <.action_sidebar>...</.action_sidebar>
  </:sidebar>
</.page_layout>
```

**Testing:** Resize browser to see sidebar move from right column → below content

---

### ActionSidebar Component

**Purpose:** Fixed-width sidebar with actions, filters, and AI insights

**Responsive Classes:**
```elixir
"w-72 sticky top-20"
```

**Behavior:**
- **Fixed width:** 288px (w-72) at all breakpoints
- **Sticky positioning:** Stays visible during scroll (desktop only)
- **Layout integration:** Controlled by parent PageLayout component
  - Mobile/Tablet: Stacks below main content
  - Desktop: Right column in 2/3 + 1/3 layout

**Sections:**
1. **QUICK ACTIONS** - Primary action buttons with icons
2. **FILTERS** - Dropdown/select filters
3. **AI INSIGHTS** - Proactive insight cards

**Example Usage:**
```elixir
<.action_sidebar>
  <:actions>
    <.sidebar_action icon="hero-plus" label="Add New" href="/new" />
    <.sidebar_action icon="hero-arrow-up-tray" label="Import" phx-click="import" />
  </:actions>

  <:filters>
    <.sidebar_filter
      label="Status"
      options={[{"All", ""}, {"Active", "active"}]}
      field={:status}
    />
  </:filters>

  <:insights>
    <.ai_insight
      message="3 products are low on stock"
      action="View low stock"
      href="/products?filter=low_stock"
    />
  </:insights>
</.action_sidebar>
```

**Testing:** Check that sidebar remains 288px width and stacks appropriately

---

### DataTable Component

**Purpose:** Feature-rich table with sorting, pagination, and row actions

**Responsive Classes:**
```elixir
"overflow-x-auto"
```

**Behavior:**
- **Mobile (<768px):** Horizontal scroll within container
- **Tablet (≥768px):** Horizontal scroll if content exceeds viewport
- **Desktop (≥1024px):** Full table display (no scroll unless very wide)

**Features:**
- Sortable columns (click header to sort)
- Pagination controls
- Row actions dropdown
- Empty and loading states
- Selectable rows (optional)

**Pagination Responsive Behavior:**
- **Mobile:** Item count and controls stack vertically if needed
- **Desktop:** Item count on left, page controls on right

**Example Usage:**
```elixir
<.data_table
  id="transactions-table"
  rows={@transactions}
  sort_by={@sort_by}
  sort_dir={@sort_dir}
>
  <:col :let={txn} label="ID" field={:id} sortable>
    <span class="font-mono text-sm">{txn.id}</span>
  </:col>
  <:col :let={txn} label="Amount" field={:amount} align={:right} sortable>
    ${txn.amount}
  </:col>
  <:action :let={txn}>
    <.button variant="ghost" size="sm">View</.button>
  </:action>
</.data_table>

<.pagination
  page={@page}
  total_pages={@total_pages}
  total_count={@total_count}
/>
```

**Testing:** Resize browser to see horizontal scrollbar appear on narrow viewports

---

### FocusedLayout Component

**Purpose:** Full-screen, distraction-free layouts for POS, terminals, wizards

**Responsive Behavior by Variant:**

#### Two-Panel Variant (`:two_panel`)
```elixir
"flex w-full h-full"
# Left panel: "w-3/5" (60%)
# Right panel: "w-2/5" (40%)
```

**Behavior:**
- **Mobile (<768px):** Panels stack vertically (not implemented in current version - relies on parent for responsive behavior)
- **Tablet/Desktop (≥768px):** Side-by-side 60/40 split

**Use case:** POS systems (product grid + cart)

#### Centered Variant (`:centered`)
```elixir
"flex-1 flex items-center justify-center p-6"
# Content: "w-full max-w-2xl mx-auto"
```

**Behavior:**
- **All breakpoints:** Centered content with max-width constraint (672px)
- Responsive padding adjusts based on viewport

**Use case:** Payment terminals, single-focus tasks

#### Wizard Variant (`:wizard`)
```elixir
# Same as centered variant
# Additional progress bar at top
```

**Behavior:**
- **All breakpoints:** Centered content with progress indicator
- Progress bar adapts to mobile with smaller text/icons if needed

**Use case:** Multi-step checkout, onboarding flows

**Example Usage:**
```elixir
# Two-panel POS
<.focused_layout title="Point of Sale" exit="/dashboard" variant={:two_panel}>
  <:left_panel>Product grid</:left_panel>
  <:right_panel>Cart summary</:right_panel>
</.focused_layout>

# Centered terminal
<.focused_layout title="Terminal" exit="/dashboard" variant={:centered}>
  <:content>Terminal interface</:content>
</.focused_layout>

# Wizard
<.focused_layout title="Checkout" exit="/cart" variant={:wizard}>
  <:progress>Step 1 of 3</:progress>
  <:content>Wizard step content</:content>
</.focused_layout>
```

**Testing:** Verify centered content stays constrained and two-panel split is maintained

---

## Tailwind Breakpoints

The components use Tailwind CSS breakpoints:

| Prefix | Min Width | Description |
|--------|-----------|-------------|
| (none) | 0px | Mobile-first base styles |
| `sm:` | 640px | Small devices |
| `md:` | 768px | Medium devices (tablets) |
| `lg:` | 1024px | Large devices (desktops) |
| `xl:` | 1280px | Extra large screens |
| `2xl:` | 1536px | 2X large screens |

**Portal components primarily use:**
- `md:` for tablet breakpoint (768px)
- `lg:` for desktop breakpoint (1024px)

## Testing Responsive Behavior

### Browser DevTools
1. Open Chrome DevTools (Cmd+Option+I on Mac)
2. Click "Toggle device toolbar" (Cmd+Shift+M)
3. Select device presets or enter custom dimensions

### Recommended Test Viewports
- **Mobile:** 375x667 (iPhone SE)
- **Tablet:** 768x1024 (iPad Mini)
- **Desktop:** 1440x900 (MacBook Air)
- **Large Desktop:** 1920x1080 (Full HD)

### Manual Resize Testing
1. Open `/dev/portal-components` in browser
2. Drag browser window edge to resize
3. Observe component reflow at breakpoints:
   - Watch StatsRow change from 4→2 columns at 768px
   - Watch PageLayout sidebar move at 1024px
   - Watch DataTable horizontal scroll appear

### Checklist
- [ ] StatsRow shows 2x2 grid on mobile, 4 columns on tablet+
- [ ] PageLayout sidebar stacks on mobile/tablet, right column on desktop
- [ ] ActionSidebar maintains 288px width at all breakpoints
- [ ] DataTable scrolls horizontally on mobile when content is wide
- [ ] FocusedLayout centered content never exceeds max-width
- [ ] All text remains readable at all breakpoints
- [ ] Touch targets are at least 44x44px on mobile
- [ ] No horizontal page scroll at any breakpoint

## Common Patterns

### Mobile-First Approach
All components use mobile-first CSS:

```elixir
# Base styles apply to mobile
"grid grid-cols-2"

# Add tablet/desktop styles with prefixes
"md:grid-cols-4 lg:grid-cols-6"
```

### Container Queries (Future Enhancement)
Currently using viewport-based breakpoints. Consider container queries for better component isolation:

```elixir
# Future enhancement
"@container (min-width: 768px) grid-cols-4"
```

### Responsive Spacing
Use responsive gap and padding utilities:

```elixir
"gap-4 md:gap-6 lg:gap-8"
"p-4 md:p-6 lg:p-8"
```

## Accessibility Considerations

### Mobile
- Touch targets ≥44x44px
- Adequate spacing between interactive elements
- Readable font sizes (minimum 16px for body text)

### Keyboard Navigation
- All interactive elements keyboard accessible
- Focus states visible at all breakpoints
- Logical tab order maintained

### Screen Readers
- Semantic HTML structure
- ARIA labels for icon-only buttons
- Table headers properly associated with data

## Performance Notes

### Mobile Optimization
- Tables use horizontal scroll instead of hiding columns
- Images lazy-load below the fold
- Critical CSS inlined for faster initial render

### Desktop Optimization
- Sticky positioning for ActionSidebar improves UX
- Grid layouts for efficient rendering
- Minimal JavaScript for responsive behavior

## Future Enhancements

### Planned Improvements
1. **ActionSidebar overlay mode** - Slide-in drawer on mobile
2. **DataTable column hiding** - Responsive column visibility
3. **StatsRow carousel** - Swipeable stats on mobile
4. **Container queries** - Better component isolation

### Experimental Features
- Bottom sheet for ActionSidebar on mobile
- Collapsible table rows for complex data
- Progressive enhancement for older browsers

---

## Quick Access

Visit `/dev/portal-components` to see all components with live examples and responsive behavior testing.

**Navigation sections:**
- StatsRow
- ActionSidebar
- PageLayout
- DataTable
- FocusedLayout
- Responsive Behavior (reference table)

**Last Updated:** 2026-01-11
