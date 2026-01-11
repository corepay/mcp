# Phase 1-2 Remediation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix critical gaps in Phase 1 layout components and Phase 2 LiveViews to bring them to world-class, production-quality standards.

**Architecture:** Each task addresses a specific gap or deficiency with TDD approach - write test first, verify failure, implement fix, verify pass, commit.

**Tech Stack:** Phoenix LiveView, Phase 1 layout components, DaisyUI, Ash Framework

---

## Executive Summary: What Went Wrong

### Phase 1 Components - Partially Complete (60%)

| Component | Status | Issues |
|-----------|--------|--------|
| StatsRow | ✅ Good | Complete with tests |
| ActionSidebar | ✅ Good | Complete with tests |
| PageLayout | ⚠️ Incomplete | Missing calendar variant, missing some slots |
| DataTable | ⚠️ Issues | Missing row_click JS.navigate, missing selectable checkboxes integration |
| FocusedLayout | ⚠️ Issues | Missing intelligence bar, wizard progress slot incomplete |
| Dev Page | ✅ Good | Exists at /dev/components |

### Phase 2 LiveViews - Poorly Implemented (30%)

| LiveView | Status | Issues |
|----------|--------|--------|
| Store PosLive | ⚠️ Mediocre | Missing ProductGrid, Cart, PaymentModal components - uses inline HTML |
| Store TerminalLive | ⚠️ Mediocre | Missing FocusedLayout import, no focused layout, hardcoded wizard steps |
| Merchant Customers Index | ❌ Bad | NOT using PageLayout/ActionSidebar - raw HTML tables |
| Merchant Customers Show | ⚠️ Partial | Uses components but missing AI insights |
| Store Customers Index | ❌ Bad | Copy of merchant version, NOT using layout components |
| Store Customers Show | ❌ Missing | File doesn't exist |
| Merchant Transactions Index | ⚠️ Partial | NOT using DataTable component - raw HTML table |
| Merchant Transactions Show | ❌ Missing | File doesn't exist |

### Critical Deficiencies

1. **Phase 2 Does Not Use Phase 1 Components**: The whole point of Phase 1 was to create reusable layouts. Phase 2 implementations bypass them entirely with raw HTML.

2. **Missing POS Components**: Phase 2 plan specifies ProductGrid, Cart, PaymentModal as separate components. The current PosLive has everything inline.

3. **No AI Insights Sections**: Design docs specify AI insights in sidebars. None of the implementations include even a placeholder.

4. **Missing Tests**: The existing tests are basic mount/render tests. No behavioral tests for interactions.

5. **Store Customer Show Missing**: This file doesn't exist at all.

6. **Transactions Show Missing**: This file doesn't exist.

7. **Raw HTML Tables**: Customers and Transactions use raw `<table>` instead of DataTable component.

8. **No PageLayout Usage**: IndexLive pages should use `<.page_layout variant={:list}>` but use manual grid layouts.

---

## Remediation Tasks

### Task 1: Remove Existing Broken Phase 2 Files

Before rebuilding, remove the broken implementations so we start clean.

**Step 1: Remove files**

```bash
rm -f lib/mcp_web/live/merchant/customers/index_live.ex \
      lib/mcp_web/live/merchant/customers/show_live.ex \
      lib/mcp_web/live/merchant/payments/transactions/index_live.ex \
      lib/mcp_web/live/merchant/payments/transactions/show_live.ex \
      lib/mcp_web/live/store/customers/index_live.ex \
      lib/mcp_web/live/store/customers/show_live.ex \
      lib/mcp_web/live/store/pos_live.ex \
      lib/mcp_web/live/store/terminal_live.ex
```

**Step 2: Remove test files**

```bash
rm -f test/mcp_web/live/merchant/customers/index_live_test.exs \
      test/mcp_web/live/merchant/customers/show_live_test.exs \
      test/mcp_web/live/merchant/payments/transactions/index_live_test.exs \
      test/mcp_web/live/merchant/payments/transactions/show_live_test.exs \
      test/mcp_web/live/store/customers/index_live_test.exs \
      test/mcp_web/live/store/customers/show_live_test.exs \
      test/mcp_web/live/store/pos_live_test.exs \
      test/mcp_web/live/store/terminal_live_test.exs
```

**Step 3: Comment out routes in router.ex**

Find and comment out routes for deleted files. Add comment: `# Phase 2 routes - will be re-added after rebuild`

**Step 4: Verify compile**

Run: `mix compile --warnings-as-errors`
Expected: No warnings about missing modules

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove broken Phase 2 implementations for complete rebuild"
```

---

### Task 2: Fix FocusedLayout - Add Intelligence Bar Slot

The design docs show an "intelligence bar" at the bottom of focused layouts.

**Files:**
- Modify: `lib/mcp_web/components/portal/focused_layout.ex`
- Test: `test/mcp_web/components/portal/focused_layout_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to test/mcp_web/components/portal/focused_layout_test.exs
describe "focused_layout with intelligence_bar" do
  test "renders intelligence bar slot when provided" do
    assigns = %{}

    html = rendered_to_string(~H"""
    <FocusedLayout.focused_layout title="POS" exit="/dashboard">
      <:content>Main content</:content>
      <:intelligence_bar>
        AI is analyzing 3 items...
      </:intelligence_bar>
    </FocusedLayout.focused_layout>
    """)

    assert html =~ "AI is analyzing 3 items"
    assert html =~ "intelligence-bar"
  end

  test "does not render intelligence bar when not provided" do
    assigns = %{}

    html = rendered_to_string(~H"""
    <FocusedLayout.focused_layout title="POS" exit="/dashboard">
      <:content>Main content</:content>
    </FocusedLayout.focused_layout>
    """)

    refute html =~ "intelligence-bar"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/portal/focused_layout_test.exs -v`
Expected: FAIL

**Step 3: Implement intelligence bar slot**

In `focused_layout.ex`, add slot:

```elixir
slot :intelligence_bar
```

In template, add at bottom before closing:

```elixir
<div :if={@intelligence_bar != []} class="intelligence-bar fixed bottom-0 left-0 right-0 bg-gradient-to-r from-primary/10 to-secondary/10 backdrop-blur-sm border-t border-base-300 px-4 py-3">
  <div class="max-w-7xl mx-auto flex items-center gap-3">
    <.icon name="hero-sparkles" class="size-5 text-primary animate-pulse" />
    <div class="flex-1">
      {render_slot(@intelligence_bar)}
    </div>
  </div>
</div>
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/portal/focused_layout_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/components/portal/focused_layout.ex test/mcp_web/components/portal/focused_layout_test.exs
git commit -m "feat(portal): add intelligence_bar slot to FocusedLayout"
```

---

### Task 3: Fix PageLayout - Add Calendar Variant

The design docs specify a calendar variant for appointments.

**Files:**
- Modify: `lib/mcp_web/components/portal/page_layout.ex`
- Test: `test/mcp_web/components/portal/page_layout_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to page_layout_test.exs
describe "page_layout calendar variant" do
  test "renders calendar navigation slot" do
    assigns = %{}

    html = rendered_to_string(~H"""
    <PageLayout.page_layout variant={:calendar} title="Appointments">
      <:calendar_nav>
        <button>< Prev</button>
        <span>January 2026</span>
        <button>Next ></button>
      </:calendar_nav>
      <:content>Calendar grid</:content>
    </PageLayout.page_layout>
    """)

    assert html =~ "January 2026"
    assert html =~ "calendar-layout"
  end
end
```

**Step 2: Run test to verify it fails**

**Step 3: Implement calendar variant**

Add `:calendar_nav` slot and handle `:calendar` variant in template.

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git commit -m "feat(portal): add calendar variant to PageLayout"
```

---

### Task 4: Create POS ProductGrid Component

Phase 2 plan specifies this as a separate component.

**Files:**
- Create: `lib/mcp_web/components/pos/product_grid.ex`
- Test: `test/mcp_web/components/pos/product_grid_test.exs`

Full implementation from Phase 2 plan Task 1 (see original plan document).

---

### Task 5: Create POS Cart Component

**Files:**
- Create: `lib/mcp_web/components/pos/cart.ex`
- Test: `test/mcp_web/components/pos/cart_test.exs`

Full implementation from Phase 2 plan Task 2.

---

### Task 6: Create POS PaymentModal Component

**Files:**
- Create: `lib/mcp_web/components/pos/payment_modal.ex`
- Test: `test/mcp_web/components/pos/payment_modal_test.exs`

Full implementation from Phase 2 plan Task 3.

---

### Task 7: Rebuild Store POS LiveView

Using the proper components.

**Files:**
- Create: `lib/mcp_web/live/store/pos_live.ex`
- Test: `test/mcp_web/live/store/pos_live_test.exs`

Full implementation from Phase 2 plan Task 4.

---

### Task 8: Create Terminal Components

**Files:**
- Create: `lib/mcp_web/components/terminal/amount_entry.ex`
- Create: `lib/mcp_web/components/terminal/card_entry.ex`
- Create: `lib/mcp_web/components/terminal/receipt.ex`
- Tests for each

---

### Task 9: Rebuild Store Terminal LiveView

**Files:**
- Create: `lib/mcp_web/live/store/terminal_live.ex`
- Test: `test/mcp_web/live/store/terminal_live_test.exs`

---

### Task 10: Rebuild Merchant Customers IndexLive

MUST use PageLayout and ActionSidebar.

**Files:**
- Create: `lib/mcp_web/live/merchant/customers/index_live.ex`
- Test: `test/mcp_web/live/merchant/customers/index_live_test.exs`

**Requirements:**
- Use `<.page_layout variant={:list}>`
- Use `<.stats_row>` for metrics
- Use `<.data_table>` for customer list
- Use `<.action_sidebar>` with actions + filters + AI insights placeholder

---

### Task 11: Rebuild Merchant Customers ShowLive

**Files:**
- Create: `lib/mcp_web/live/merchant/customers/show_live.ex`
- Test: `test/mcp_web/live/merchant/customers/show_live_test.exs`

**Requirements:**
- Use `<.page_layout variant={:detail}>`
- Customer profile card
- Transaction history with DataTable
- AI insights sidebar section

---

### Task 12: Rebuild Store Customers IndexLive

**Files:**
- Create: `lib/mcp_web/live/store/customers/index_live.ex`
- Test: `test/mcp_web/live/store/customers/index_live_test.exs`

**Requirements:**
- Read-only version for store staff
- Quick lookup focus
- No add/edit actions

---

### Task 13: Create Store Customers ShowLive

THIS FILE WAS MISSING ENTIRELY.

**Files:**
- Create: `lib/mcp_web/live/store/customers/show_live.ex`
- Test: `test/mcp_web/live/store/customers/show_live_test.exs`

---

### Task 14: Rebuild Merchant Transactions IndexLive

**Files:**
- Create: `lib/mcp_web/live/merchant/payments/transactions/index_live.ex`
- Test: `test/mcp_web/live/merchant/payments/transactions/index_live_test.exs`

**Requirements:**
- Use `<.page_layout variant={:table}>`
- Use `<.data_table>` with full features
- Date range picker
- Status filter
- Export button

---

### Task 15: Create Merchant Transactions ShowLive

THIS FILE WAS MISSING ENTIRELY.

**Files:**
- Create: `lib/mcp_web/live/merchant/payments/transactions/show_live.ex`
- Test: `test/mcp_web/live/merchant/payments/transactions/show_live_test.exs`

**Requirements:**
- Use `<.page_layout variant={:detail}>`
- Transaction timeline
- Customer info section
- Refund actions in sidebar

---

### Task 16: Re-add Routes

Uncomment and fix routes in router.ex for all rebuilt LiveViews.

---

### Task 17: Quality Gate - Run Full Test Suite

```bash
mix precommit
```

ALL tests must pass. No warnings.

---

## Definition of Done

- [ ] All broken files removed
- [ ] FocusedLayout has intelligence_bar slot
- [ ] PageLayout has calendar variant
- [ ] POS components exist (ProductGrid, Cart, PaymentModal)
- [ ] Terminal components exist
- [ ] All 8 LiveViews rebuilt using layout components properly
- [ ] All LiveViews have comprehensive tests
- [ ] All tests pass
- [ ] `mix precommit` passes
- [ ] Visual verification at /dev/components shows all variants

---

## Next Steps After Remediation

With Phase 1-2 properly complete, proceed to Phase 3-5:

- **Phase 3**: Inventory & Products (Merchant), Product display (Store)
- **Phase 4**: Orders & Reports (Merchant), Order history (Store)
- **Phase 5**: AI Integration, Intelligence Bar, Proactive Insights
