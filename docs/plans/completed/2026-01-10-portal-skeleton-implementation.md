# Portal UI Skeleton Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a modern, aesthetically pleasing Merchant and Store portal skeleton with distinct navigation patterns per the design spec.

**Architecture:** Merchant Portal uses top nav + contextual sidebar (like Shopify Admin), Store Portal uses left sidebar with grouped navigation. Both share foundational CoreComponents but have distinct shell layouts. Context switchers enable navigation between merchant-level and store-level views.

**Tech Stack:** Phoenix LiveView, DaisyUI + Tailwind CSS v4, CoreComponents pattern, Alpine.js for client-only interactions

**Design Reference:** `docs/plans/completed/2026-01-10-portal-ui-design.md`

**Quality Standards:**
- All components use semantic DaisyUI tokens (no hex values)
- Motion/transitions on all interactive elements
- Loading states for async operations
- Responsive (mobile-first)
- TDD: Test first, then implement

---

## Phase 1: Foundation CoreComponents

### Task 1: StatCard Component

A stat card displays a metric with label, value, and optional trend indicator.

**Files:**
- Create: `lib/mcp_web/components/core/data_display.ex`
- Create: `test/mcp_web/components/core/data_display_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/core/data_display_test.exs
defmodule McpWeb.Core.DataDisplayTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Core.DataDisplay

  describe "stat_card/1" do
    test "renders value and label" do
      assigns = %{value: "$12,847", label: "Today's Revenue"}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card value={@value} label={@label} />
        """)

      assert html =~ "$12,847"
      assert html =~ "Today's Revenue"
      assert html =~ "stat"
    end

    test "renders trend when provided" do
      assigns = %{value: "156", label: "Transactions", trend: "+12%", trend_direction: :up}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card
          value={@value}
          label={@label}
          trend={@trend}
          trend_direction={@trend_direction}
        />
        """)

      assert html =~ "+12%"
      assert html =~ "text-success"
    end

    test "renders down trend with error color" do
      assigns = %{value: "89", label: "Customers", trend: "-3%", trend_direction: :down}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card
          value={@value}
          label={@label}
          trend={@trend}
          trend_direction={@trend_direction}
        />
        """)

      assert html =~ "-3%"
      assert html =~ "text-error"
    end

    test "renders icon when provided" do
      assigns = %{value: "$82.35", label: "Avg Order", icon: "hero-currency-dollar"}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card value={@value} label={@label} icon={@icon} />
        """)

      assert html =~ "hero-currency-dollar"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/data_display_test.exs --trace`
Expected: FAIL with "module DataDisplay is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/core/data_display.ex
defmodule McpWeb.Core.DataDisplay do
  @moduledoc """
  Data display components: stat cards, badges, progress indicators.
  """
  use Phoenix.Component

  @doc """
  Renders a stat card for dashboard metrics.

  ## Examples

      <.stat_card value="$12,847" label="Today's Revenue" />
      <.stat_card value="156" label="Transactions" trend="+12%" trend_direction={:up} />
  """
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :trend, :string, default: nil
  attr :trend_direction, :atom, default: nil, values: [nil, :up, :down]
  attr :icon, :string, default: nil
  attr :class, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class={[
      "stat bg-base-100 rounded-box shadow-sm",
      "border border-base-300/50",
      "transition-all duration-200 hover:shadow-md hover:border-base-300",
      @class
    ]}>
      <div :if={@icon} class="stat-figure text-primary">
        <span class={[@icon, "size-8 opacity-60"]} />
      </div>
      <div class="stat-title text-base-content/70 text-sm font-medium">{@label}</div>
      <div class="stat-value text-2xl font-semibold text-base-content">{@value}</div>
      <div :if={@trend} class={[
        "stat-desc text-sm font-medium",
        @trend_direction == :up && "text-success",
        @trend_direction == :down && "text-error",
        @trend_direction == nil && "text-base-content/60"
      ]}>
        <span :if={@trend_direction == :up}>↑</span>
        <span :if={@trend_direction == :down}>↓</span>
        {@trend}
      </div>
    </div>
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/data_display_test.exs --trace`
Expected: 4 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/data_display.ex test/mcp_web/components/core/data_display_test.exs
git commit -m "feat(ui): add stat_card component for dashboard metrics"
```

---

### Task 2: Badge Component

Badges for status indicators, counts, and labels.

**Files:**
- Modify: `lib/mcp_web/components/core/data_display.ex`
- Modify: `test/mcp_web/components/core/data_display_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to test/mcp_web/components/core/data_display_test.exs

describe "badge/1" do
  test "renders with default variant" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <DataDisplay.badge>New</DataDisplay.badge>
      """)

    assert html =~ "badge"
    assert html =~ "New"
  end

  test "renders with variant" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <DataDisplay.badge variant="success">Active</DataDisplay.badge>
      """)

    assert html =~ "badge-success"
    assert html =~ "Active"
  end

  test "renders with size" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <DataDisplay.badge size="lg">Large</DataDisplay.badge>
      """)

    assert html =~ "badge-lg"
  end

  test "renders outline variant" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <DataDisplay.badge outline>Outline</DataDisplay.badge>
      """)

    assert html =~ "badge-outline"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/data_display_test.exs --trace`
Expected: FAIL with "function badge/1 is undefined"

**Step 3: Write minimal implementation**

```elixir
# Add to lib/mcp_web/components/core/data_display.ex

@doc """
Renders a badge for status indicators and labels.

## Examples

    <.badge>Default</badge>
    <.badge variant="success">Active</.badge>
    <.badge variant="error" size="lg">Failed</.badge>
"""
attr :variant, :string,
  default: nil,
  values: [nil, "primary", "secondary", "accent", "info", "success", "warning", "error", "ghost"]

attr :size, :string, default: nil, values: [nil, "lg", "md", "sm", "xs"]
attr :outline, :boolean, default: false
attr :class, :string, default: nil
slot :inner_block, required: true

def badge(assigns) do
  ~H"""
  <span class={[
    "badge",
    @variant && "badge-#{@variant}",
    @size && "badge-#{@size}",
    @outline && "badge-outline",
    "transition-colors duration-150",
    @class
  ]}>
    {render_slot(@inner_block)}
  </span>
  """
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/data_display_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/data_display.ex test/mcp_web/components/core/data_display_test.exs
git commit -m "feat(ui): add badge component for status indicators"
```

---

### Task 3: Avatar Component

Avatar for user menus and profile displays.

**Files:**
- Modify: `lib/mcp_web/components/core/data_display.ex`
- Modify: `test/mcp_web/components/core/data_display_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to test/mcp_web/components/core/data_display_test.exs

describe "avatar/1" do
  test "renders with image" do
    assigns = %{src: "/images/user.jpg", alt: "John Doe"}

    html =
      rendered_to_string(~H"""
      <DataDisplay.avatar src={@src} alt={@alt} />
      """)

    assert html =~ "avatar"
    assert html =~ "/images/user.jpg"
    assert html =~ "John Doe"
  end

  test "renders with initials when no image" do
    assigns = %{initials: "JD"}

    html =
      rendered_to_string(~H"""
      <DataDisplay.avatar initials={@initials} />
      """)

    assert html =~ "JD"
    assert html =~ "bg-primary"
  end

  test "renders with size" do
    assigns = %{initials: "AB"}

    html =
      rendered_to_string(~H"""
      <DataDisplay.avatar initials={@initials} size="lg" />
      """)

    assert html =~ "w-16"
  end

  test "renders with online indicator" do
    assigns = %{initials: "CD", online: true}

    html =
      rendered_to_string(~H"""
      <DataDisplay.avatar initials={@initials} online={@online} />
      """)

    assert html =~ "online"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/data_display_test.exs --trace`
Expected: FAIL with "function avatar/1 is undefined"

**Step 3: Write minimal implementation**

```elixir
# Add to lib/mcp_web/components/core/data_display.ex

@doc """
Renders an avatar with image or initials.

## Examples

    <.avatar src="/images/user.jpg" alt="John Doe" />
    <.avatar initials="JD" size="lg" />
    <.avatar initials="JD" online />
"""
attr :src, :string, default: nil
attr :alt, :string, default: "Avatar"
attr :initials, :string, default: nil
attr :size, :string, default: "md", values: ["xs", "sm", "md", "lg", "xl"]
attr :online, :boolean, default: false
attr :class, :string, default: nil

def avatar(assigns) do
  size_classes = %{
    "xs" => "w-6",
    "sm" => "w-8",
    "md" => "w-10",
    "lg" => "w-16",
    "xl" => "w-24"
  }

  assigns = assign(assigns, :size_class, size_classes[assigns.size])

  ~H"""
  <div class={["avatar", @online && "online", @class]}>
    <div class={[
      @size_class,
      "rounded-full",
      !@src && "bg-primary text-primary-content",
      "ring ring-base-300 ring-offset-base-100 ring-offset-1",
      "transition-all duration-200"
    ]}>
      <img :if={@src} src={@src} alt={@alt} class="object-cover" />
      <span
        :if={!@src && @initials}
        class="flex items-center justify-center w-full h-full text-sm font-medium"
      >
        {@initials}
      </span>
    </div>
  </div>
  """
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/data_display_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/data_display.ex test/mcp_web/components/core/data_display_test.exs
git commit -m "feat(ui): add avatar component for user displays"
```

---

### Task 4: Skeleton Component

Loading placeholders for async content.

**Files:**
- Create: `lib/mcp_web/components/core/feedback.ex`
- Create: `test/mcp_web/components/core/feedback_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/core/feedback_test.exs
defmodule McpWeb.Core.FeedbackTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Core.Feedback

  describe "skeleton/1" do
    test "renders default skeleton" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton />
        """)

      assert html =~ "skeleton"
      assert html =~ "animate-pulse"
    end

    test "renders with variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton variant="text" />
        """)

      assert html =~ "h-4"
    end

    test "renders circle variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton variant="circle" />
        """)

      assert html =~ "rounded-full"
    end

    test "renders with custom dimensions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton width="w-32" height="h-8" />
        """)

      assert html =~ "w-32"
      assert html =~ "h-8"
    end
  end

  describe "skeleton_stat_card/1" do
    test "renders stat card skeleton" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton_stat_card />
        """)

      assert html =~ "skeleton"
      assert html =~ "stat"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/feedback_test.exs --trace`
Expected: FAIL with "module Feedback is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/core/feedback.ex
defmodule McpWeb.Core.Feedback do
  @moduledoc """
  Feedback components: loading states, progress, notifications.
  """
  use Phoenix.Component

  @doc """
  Renders a skeleton loading placeholder.

  ## Examples

      <.skeleton />
      <.skeleton variant="text" />
      <.skeleton variant="circle" width="w-12" height="h-12" />
  """
  attr :variant, :string, default: "rect", values: ["rect", "text", "circle"]
  attr :width, :string, default: "w-full"
  attr :height, :string, default: nil
  attr :class, :string, default: nil

  def skeleton(assigns) do
    height =
      assigns.height ||
        case assigns.variant do
          "text" -> "h-4"
          "circle" -> "h-10"
          _ -> "h-20"
        end

    shape =
      case assigns.variant do
        "circle" -> "rounded-full"
        "text" -> "rounded"
        _ -> "rounded-box"
      end

    assigns = assign(assigns, height: height, shape: shape)

    ~H"""
    <div class={[
      "skeleton animate-pulse bg-base-300/50",
      @width,
      @height,
      @shape,
      @class
    ]}>
    </div>
    """
  end

  @doc """
  Renders a skeleton placeholder for stat cards.
  """
  attr :class, :string, default: nil

  def skeleton_stat_card(assigns) do
    ~H"""
    <div class={[
      "stat bg-base-100 rounded-box shadow-sm border border-base-300/50",
      @class
    ]}>
      <div class="stat-title">
        <.skeleton variant="text" width="w-24" />
      </div>
      <div class="stat-value py-2">
        <.skeleton variant="text" width="w-32" height="h-8" />
      </div>
      <div class="stat-desc">
        <.skeleton variant="text" width="w-16" />
      </div>
    </div>
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/feedback_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/feedback.ex test/mcp_web/components/core/feedback_test.exs
git commit -m "feat(ui): add skeleton components for loading states"
```

---

### Task 5: Dropdown Component

Dropdown menus for context switcher and user menus.

**Files:**
- Create: `lib/mcp_web/components/core/navigation.ex`
- Create: `test/mcp_web/components/core/navigation_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/core/navigation_test.exs
defmodule McpWeb.Core.NavigationTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Core.Navigation

  describe "dropdown/1" do
    test "renders dropdown with trigger and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.dropdown>
          <:trigger>
            <button>Open</button>
          </:trigger>
          <:content>
            <li><a>Item 1</a></li>
            <li><a>Item 2</a></li>
          </:content>
        </Navigation.dropdown>
        """)

      assert html =~ "dropdown"
      assert html =~ "Open"
      assert html =~ "Item 1"
    end

    test "renders with position" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.dropdown position="end">
          <:trigger>Menu</:trigger>
          <:content><li>Item</li></:content>
        </Navigation.dropdown>
        """)

      assert html =~ "dropdown-end"
    end

    test "renders with hover trigger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.dropdown hover>
          <:trigger>Hover</:trigger>
          <:content><li>Item</li></:content>
        </Navigation.dropdown>
        """)

      assert html =~ "dropdown-hover"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: FAIL with "module Navigation is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/core/navigation.ex
defmodule McpWeb.Core.Navigation do
  @moduledoc """
  Navigation components: navbar, sidebar, dropdown, tabs.
  """
  use Phoenix.Component

  @doc """
  Renders a dropdown menu.

  ## Examples

      <.dropdown>
        <:trigger>
          <button class="btn">Menu</button>
        </:trigger>
        <:content>
          <li><a>Profile</a></li>
          <li><a>Settings</a></li>
        </:content>
      </.dropdown>
  """
  attr :position, :string, default: nil, values: [nil, "end", "top", "bottom", "left", "right"]
  attr :hover, :boolean, default: false
  attr :class, :string, default: nil

  slot :trigger, required: true
  slot :content, required: true

  def dropdown(assigns) do
    ~H"""
    <div class={[
      "dropdown",
      @position && "dropdown-#{@position}",
      @hover && "dropdown-hover",
      @class
    ]}>
      <div tabindex="0" role="button">
        {render_slot(@trigger)}
      </div>
      <ul
        tabindex="0"
        class={[
          "dropdown-content menu",
          "bg-base-100 rounded-box shadow-xl",
          "border border-base-300/50",
          "z-50 w-52 p-2",
          "transition-all duration-200"
        ]}
      >
        {render_slot(@content)}
      </ul>
    </div>
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/navigation.ex test/mcp_web/components/core/navigation_test.exs
git commit -m "feat(ui): add dropdown component for menus"
```

---

### Task 6: Navbar Component

Top navigation bar for Merchant Portal.

**Files:**
- Modify: `lib/mcp_web/components/core/navigation.ex`
- Modify: `test/mcp_web/components/core/navigation_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to test/mcp_web/components/core/navigation_test.exs

describe "navbar/1" do
  test "renders navbar with start, center, end zones" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Navigation.navbar>
        <:start>
          <span>Logo</span>
        </:start>
        <:center>
          <a>Dashboard</a>
          <a>Products</a>
        </:center>
        <:end>
          <button>Profile</button>
        </:end>
      </Navigation.navbar>
      """)

    assert html =~ "navbar"
    assert html =~ "Logo"
    assert html =~ "Dashboard"
    assert html =~ "Profile"
    assert html =~ "navbar-start"
    assert html =~ "navbar-center"
    assert html =~ "navbar-end"
  end

  test "renders with custom background" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Navigation.navbar class="bg-primary">
        <:start>Logo</:start>
      </Navigation.navbar>
      """)

    assert html =~ "bg-primary"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: FAIL with "function navbar/1 is undefined"

**Step 3: Write minimal implementation**

```elixir
# Add to lib/mcp_web/components/core/navigation.ex

@doc """
Renders a top navigation bar.

## Examples

    <.navbar>
      <:start>Logo</:start>
      <:center>
        <a href="/dashboard">Dashboard</a>
      </:center>
      <:end>
        <.avatar initials="JD" />
      </:end>
    </.navbar>
"""
attr :class, :string, default: nil

slot :start
slot :center
slot :end

def navbar(assigns) do
  ~H"""
  <nav class={[
    "navbar bg-base-100 shadow-sm",
    "border-b border-base-300/50",
    "px-4 min-h-14",
    @class
  ]}>
    <div :if={@start != []} class="navbar-start gap-2">
      {render_slot(@start)}
    </div>
    <div :if={@center != []} class="navbar-center gap-1">
      {render_slot(@center)}
    </div>
    <div :if={@end != []} class="navbar-end gap-2">
      {render_slot(@end)}
    </div>
  </nav>
  """
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/navigation.ex test/mcp_web/components/core/navigation_test.exs
git commit -m "feat(ui): add navbar component for top navigation"
```

---

### Task 7: Sidebar Component

Left sidebar for Store Portal with grouped sections.

**Files:**
- Modify: `lib/mcp_web/components/core/navigation.ex`
- Modify: `test/mcp_web/components/core/navigation_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to test/mcp_web/components/core/navigation_test.exs

describe "sidebar/1" do
  test "renders sidebar with header and items" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Navigation.sidebar>
        <:header>
          <span>Store Name</span>
        </:header>
        <:section title="SELL">
          <li><a>POS</a></li>
          <li><a>Terminal</a></li>
        </:section>
        <:footer>
          <li><a>Settings</a></li>
        </:footer>
      </Navigation.sidebar>
      """)

    assert html =~ "Store Name"
    assert html =~ "SELL"
    assert html =~ "POS"
    assert html =~ "Settings"
  end

  test "renders collapsible sections" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Navigation.sidebar>
        <:section title="MANAGE" collapsible>
          <li><a>Customers</a></li>
        </:section>
      </Navigation.sidebar>
      """)

    assert html =~ "MANAGE"
    assert html =~ "collapse"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: FAIL with "function sidebar/1 is undefined"

**Step 3: Write minimal implementation**

```elixir
# Add to lib/mcp_web/components/core/navigation.ex

@doc """
Renders a left sidebar with grouped sections.

## Examples

    <.sidebar>
      <:header><span>Store Name</span></:header>
      <:section title="SELL">
        <li><a href="/pos">POS</a></li>
      </:section>
      <:footer><li><a>Settings</a></li></:footer>
    </.sidebar>
"""
attr :class, :string, default: nil

slot :header
slot :section do
  attr :title, :string, required: true
  attr :collapsible, :boolean
end
slot :footer

def sidebar(assigns) do
  ~H"""
  <aside class={[
    "flex flex-col w-64 min-h-screen",
    "bg-base-200 border-r border-base-300/50",
    @class
  ]}>
    <div :if={@header != []} class="p-4 border-b border-base-300/50">
      {render_slot(@header)}
    </div>

    <nav class="flex-1 overflow-y-auto p-2">
      <ul class="menu gap-1">
        <%= for section <- @section do %>
          <%= if section[:collapsible] do %>
            <li>
              <details class="collapse collapse-arrow">
                <summary class="menu-title text-xs font-semibold text-base-content/60 uppercase tracking-wider">
                  {section.title}
                </summary>
                <ul class="collapse-content menu p-0 pl-2">
                  {render_slot(section)}
                </ul>
              </details>
            </li>
          <% else %>
            <li class="menu-title text-xs font-semibold text-base-content/60 uppercase tracking-wider mt-4 first:mt-0">
              {section.title}
            </li>
            {render_slot(section)}
          <% end %>
        <% end %>
      </ul>
    </nav>

    <div :if={@footer != []} class="mt-auto border-t border-base-300/50 p-2">
      <ul class="menu gap-1">
        {render_slot(@footer)}
      </ul>
    </div>
  </aside>
  """
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/navigation.ex test/mcp_web/components/core/navigation_test.exs
git commit -m "feat(ui): add sidebar component with grouped sections"
```

---

### Task 8: Tabs Component

Horizontal tab navigation for sections.

**Files:**
- Modify: `lib/mcp_web/components/core/navigation.ex`
- Modify: `test/mcp_web/components/core/navigation_test.exs`

**Step 1: Write the failing test**

```elixir
# Add to test/mcp_web/components/core/navigation_test.exs

describe "tabs/1" do
  test "renders tabs with items" do
    assigns = %{
      items: [
        %{label: "Dashboard", href: "/", active: true},
        %{label: "Products", href: "/products", active: false},
        %{label: "Settings", href: "/settings", active: false}
      ]
    }

    html =
      rendered_to_string(~H"""
      <Navigation.tabs items={@items} />
      """)

    assert html =~ "tabs"
    assert html =~ "Dashboard"
    assert html =~ "Products"
    assert html =~ "tab-active"
  end

  test "renders with bordered variant" do
    assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

    html =
      rendered_to_string(~H"""
      <Navigation.tabs items={@items} variant="bordered" />
      """)

    assert html =~ "tabs-bordered"
  end

  test "renders with boxed variant" do
    assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

    html =
      rendered_to_string(~H"""
      <Navigation.tabs items={@items} variant="boxed" />
      """)

    assert html =~ "tabs-boxed"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: FAIL with "function tabs/1 is undefined"

**Step 3: Write minimal implementation**

```elixir
# Add to lib/mcp_web/components/core/navigation.ex

@doc """
Renders horizontal navigation tabs.

## Examples

    <.tabs items={[
      %{label: "Dashboard", href: "/", active: true},
      %{label: "Products", href: "/products", active: false}
    ]} />
"""
attr :items, :list, required: true
attr :variant, :string, default: nil, values: [nil, "bordered", "boxed", "lifted"]
attr :size, :string, default: nil, values: [nil, "xs", "sm", "md", "lg"]
attr :class, :string, default: nil

def tabs(assigns) do
  ~H"""
  <div
    role="tablist"
    class={[
      "tabs",
      @variant && "tabs-#{@variant}",
      @size && "tabs-#{@size}",
      @class
    ]}
  >
    <a
      :for={item <- @items}
      href={item.href}
      role="tab"
      class={[
        "tab",
        "transition-colors duration-150",
        item.active && "tab-active"
      ]}
    >
      {item.label}
    </a>
  </div>
  """
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/navigation_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/navigation.ex test/mcp_web/components/core/navigation_test.exs
git commit -m "feat(ui): add tabs component for horizontal navigation"
```

---

### Task 9: Context Switcher Component

Specialized dropdown for switching between Merchant/Store contexts.

**Files:**
- Create: `lib/mcp_web/components/portals/merchant/components.ex`
- Create: `test/mcp_web/components/portals/merchant/components_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/portals/merchant/components_test.exs
defmodule McpWeb.Portals.Merchant.ComponentsTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portals.Merchant.Components

  describe "context_switcher/1" do
    test "renders current context with merchant name" do
      assigns = %{
        current_name: "Acme Corp",
        current_type: :merchant,
        stores: [
          %{name: "Downtown Store", slug: "downtown"},
          %{name: "Online Shop", slug: "online"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <Components.context_switcher
          current_name={@current_name}
          current_type={@current_type}
          stores={@stores}
        />
        """)

      assert html =~ "Acme Corp"
      assert html =~ "Downtown Store"
      assert html =~ "Online Shop"
      assert html =~ "dropdown"
    end

    test "renders with store context" do
      assigns = %{
        current_name: "Downtown Store",
        current_type: :store,
        merchant_name: "Acme Corp",
        stores: []
      }

      html =
        rendered_to_string(~H"""
        <Components.context_switcher
          current_name={@current_name}
          current_type={@current_type}
          merchant_name={@merchant_name}
          stores={@stores}
        />
        """)

      assert html =~ "Downtown Store"
      assert html =~ "Acme Corp"
    end

    test "shows new store link" do
      assigns = %{
        current_name: "Acme Corp",
        current_type: :merchant,
        stores: []
      }

      html =
        rendered_to_string(~H"""
        <Components.context_switcher
          current_name={@current_name}
          current_type={@current_type}
          stores={@stores}
        />
        """)

      assert html =~ "New Store"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/portals/merchant/components_test.exs --trace`
Expected: FAIL with "module Components is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/portals/merchant/components.ex
defmodule McpWeb.Portals.Merchant.Components do
  @moduledoc """
  Business components for the Merchant Portal.
  """
  use Phoenix.Component
  import McpWeb.Core.Navigation, only: [dropdown: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a context switcher for navigating between merchant and stores.

  ## Examples

      <.context_switcher
        current_name="Acme Corp"
        current_type={:merchant}
        stores={[%{name: "Downtown", slug: "downtown"}]}
      />
  """
  attr :current_name, :string, required: true
  attr :current_type, :atom, required: true, values: [:merchant, :store]
  attr :merchant_name, :string, default: nil
  attr :stores, :list, default: []
  attr :class, :string, default: nil

  def context_switcher(assigns) do
    ~H"""
    <.dropdown class={@class}>
      <:trigger>
        <button class={[
          "btn btn-ghost gap-2",
          "font-semibold text-base-content",
          "hover:bg-base-200"
        ]}>
          <span class="max-w-[180px] truncate">{@current_name}</span>
          <.icon name="hero-chevron-down" class="size-4 opacity-60" />
        </button>
      </:trigger>
      <:content>
        <%!-- Back to merchant if in store context --%>
        <li :if={@current_type == :store && @merchant_name} class="border-b border-base-300/50 pb-2 mb-2">
          <a href="/app" class="flex items-center gap-2 text-base-content/70 hover:text-base-content">
            <.icon name="hero-arrow-left" class="size-4" />
            {@merchant_name}
          </a>
        </li>

        <%!-- Current merchant indicator --%>
        <li :if={@current_type == :merchant} class="border-b border-base-300/50 pb-2 mb-2">
          <span class="flex items-center gap-2 font-medium text-primary pointer-events-none">
            <span class="w-2 h-2 rounded-full bg-primary"></span>
            {@current_name}
          </span>
        </li>

        <%!-- Store list --%>
        <li :for={store <- @stores}>
          <a
            href={"/app/stores/#{store.slug}"}
            class="flex items-center gap-2 text-base-content/80 hover:text-base-content"
          >
            <span class={[
              "w-2 h-2 rounded-full",
              @current_type == :store && store.name == @current_name && "bg-primary",
              !(@current_type == :store && store.name == @current_name) && "bg-base-300"
            ]}>
            </span>
            {store.name}
          </a>
        </li>

        <%!-- New store --%>
        <li class="border-t border-base-300/50 pt-2 mt-2">
          <a href="/app/stores/new" class="flex items-center gap-2 text-base-content/60 hover:text-base-content">
            <.icon name="hero-plus" class="size-4" />
            New Store
          </a>
        </li>
      </:content>
    </.dropdown>
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/portals/merchant/components_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/portals/merchant/components.ex test/mcp_web/components/portals/merchant/components_test.exs
git commit -m "feat(ui): add context switcher for merchant/store navigation"
```

---

## Phase 2: Shell Layouts

### Task 10: Merchant Shell Layout

Top nav + contextual sidebar pattern for Merchant Portal.

**Files:**
- Create: `lib/mcp_web/components/layouts/merchant_shell.ex`
- Create: `test/mcp_web/components/layouts/merchant_shell_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/layouts/merchant_shell_test.exs
defmodule McpWeb.Layouts.MerchantShellTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Layouts.MerchantShell

  describe "merchant_shell/1" do
    test "renders shell with navbar and content" do
      assigns = %{
        merchant_name: "Acme Corp",
        stores: [],
        current_path: "/app",
        user_initials: "JD"
      }

      html =
        rendered_to_string(~H"""
        <MerchantShell.merchant_shell
          merchant_name={@merchant_name}
          stores={@stores}
          current_path={@current_path}
          user_initials={@user_initials}
        >
          <p>Dashboard content</p>
        </MerchantShell.merchant_shell>
        """)

      assert html =~ "navbar"
      assert html =~ "Acme Corp"
      assert html =~ "Dashboard"
      assert html =~ "Dashboard content"
    end

    test "renders nav items with active state" do
      assigns = %{
        merchant_name: "Acme Corp",
        stores: [],
        current_path: "/app/products",
        user_initials: "JD"
      }

      html =
        rendered_to_string(~H"""
        <MerchantShell.merchant_shell
          merchant_name={@merchant_name}
          stores={@stores}
          current_path={@current_path}
          user_initials={@user_initials}
        >
          <p>Content</p>
        </MerchantShell.merchant_shell>
        """)

      # Products should be active
      assert html =~ "Products"
    end

    test "renders with sidebar for sections that need it" do
      assigns = %{
        merchant_name: "Acme Corp",
        stores: [],
        current_path: "/app/payments",
        user_initials: "JD"
      }

      html =
        rendered_to_string(~H"""
        <MerchantShell.merchant_shell
          merchant_name={@merchant_name}
          stores={@stores}
          current_path={@current_path}
          user_initials={@user_initials}
        >
          <:sidebar>
            <li><a>Transactions</a></li>
          </:sidebar>
          <p>Payments content</p>
        </MerchantShell.merchant_shell>
        """)

      assert html =~ "Transactions"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/layouts/merchant_shell_test.exs --trace`
Expected: FAIL with "module MerchantShell is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/layouts/merchant_shell.ex
defmodule McpWeb.Layouts.MerchantShell do
  @moduledoc """
  Merchant Portal shell layout with top nav + contextual sidebar.
  """
  use Phoenix.Component
  import McpWeb.Core.Navigation, only: [navbar: 1, dropdown: 1]
  import McpWeb.Core.DataDisplay, only: [avatar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]
  import McpWeb.Portals.Merchant.Components, only: [context_switcher: 1]

  @nav_items [
    %{label: "Dashboard", href: "/app", icon: "hero-home"},
    %{label: "Products", href: "/app/products", icon: "hero-cube"},
    %{label: "Stores", href: "/app/stores", icon: "hero-building-storefront"},
    %{label: "Payments", href: "/app/payments", icon: "hero-credit-card"},
    %{label: "Customers", href: "/app/customers", icon: "hero-users"}
  ]

  @doc """
  Renders the Merchant Portal shell with top nav and optional contextual sidebar.

  ## Examples

      <.merchant_shell merchant_name="Acme" stores={[]} current_path="/app" user_initials="JD">
        <p>Content</p>
      </.merchant_shell>
  """
  attr :merchant_name, :string, required: true
  attr :stores, :list, default: []
  attr :current_path, :string, required: true
  attr :user_initials, :string, default: "?"
  attr :user_name, :string, default: nil
  attr :class, :string, default: nil

  slot :sidebar
  slot :inner_block, required: true

  def merchant_shell(assigns) do
    assigns = assign(assigns, :nav_items, @nav_items)

    ~H"""
    <div class={["min-h-screen bg-base-200 flex flex-col", @class]}>
      <%!-- Top Navigation Bar --%>
      <.navbar class="bg-base-100 sticky top-0 z-40">
        <:start>
          <.context_switcher
            current_name={@merchant_name}
            current_type={:merchant}
            stores={@stores}
          />
        </:start>

        <:center>
          <div class="hidden lg:flex gap-1">
            <a
              :for={item <- @nav_items}
              href={item.href}
              class={[
                "btn btn-ghost btn-sm gap-2",
                "font-medium",
                active?(@current_path, item.href) && "bg-base-200 text-primary"
              ]}
            >
              <.icon name={item.icon} class="size-4" />
              {item.label}
            </a>
          </div>
        </:center>

        <:end>
          <%!-- Search --%>
          <button class="btn btn-ghost btn-circle">
            <.icon name="hero-magnifying-glass" class="size-5" />
          </button>

          <%!-- Help --%>
          <button class="btn btn-ghost btn-circle">
            <.icon name="hero-question-mark-circle" class="size-5" />
          </button>

          <%!-- Notifications --%>
          <button class="btn btn-ghost btn-circle indicator">
            <span class="indicator-item badge badge-primary badge-xs"></span>
            <.icon name="hero-bell" class="size-5" />
          </button>

          <%!-- User menu --%>
          <.dropdown position="end">
            <:trigger>
              <.avatar initials={@user_initials} size="sm" />
            </:trigger>
            <:content>
              <li :if={@user_name} class="menu-title">{@user_name}</li>
              <li><a href="/app/settings">Settings</a></li>
              <li><a href="/sign-out" data-method="delete">Sign out</a></li>
            </:content>
          </.dropdown>
        </:end>
      </.navbar>

      <%!-- Content Area with optional sidebar --%>
      <div class="flex flex-1">
        <%!-- Contextual Sidebar (if provided) --%>
        <aside
          :if={@sidebar != []}
          class="hidden lg:block w-60 bg-base-100 border-r border-base-300/50 p-4"
        >
          <ul class="menu gap-1">
            {render_slot(@sidebar)}
          </ul>
        </aside>

        <%!-- Main Content --%>
        <main class="flex-1 p-6">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  defp active?(current_path, href) do
    cond do
      href == "/app" -> current_path == "/app"
      true -> String.starts_with?(current_path, href)
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/layouts/merchant_shell_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/layouts/merchant_shell.ex test/mcp_web/components/layouts/merchant_shell_test.exs
git commit -m "feat(ui): add merchant shell with top nav + contextual sidebar"
```

---

### Task 11: Store Shell Layout

Left sidebar layout for Store Portal.

**Files:**
- Create: `lib/mcp_web/components/layouts/store_shell.ex`
- Create: `test/mcp_web/components/layouts/store_shell_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/layouts/store_shell_test.exs
defmodule McpWeb.Layouts.StoreShellTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Layouts.StoreShell

  describe "store_shell/1" do
    test "renders shell with sidebar and content" do
      assigns = %{
        store_name: "Downtown Store",
        store_slug: "downtown",
        merchant_name: "Acme Corp",
        current_path: "/app/stores/downtown",
        user_initials: "JD",
        vertical: :retail
      }

      html =
        rendered_to_string(~H"""
        <StoreShell.store_shell
          store_name={@store_name}
          store_slug={@store_slug}
          merchant_name={@merchant_name}
          current_path={@current_path}
          user_initials={@user_initials}
          vertical={@vertical}
        >
          <p>Store content</p>
        </StoreShell.store_shell>
        """)

      assert html =~ "Downtown Store"
      assert html =~ "Dashboard"
      assert html =~ "POS"
      assert html =~ "Store content"
    end

    test "renders grouped nav sections" do
      assigns = %{
        store_name: "Downtown Store",
        store_slug: "downtown",
        merchant_name: "Acme Corp",
        current_path: "/app/stores/downtown",
        user_initials: "JD",
        vertical: :retail
      }

      html =
        rendered_to_string(~H"""
        <StoreShell.store_shell
          store_name={@store_name}
          store_slug={@store_slug}
          merchant_name={@merchant_name}
          current_path={@current_path}
          user_initials={@user_initials}
          vertical={@vertical}
        >
          <p>Content</p>
        </StoreShell.store_shell>
        """)

      assert html =~ "SELL"
      assert html =~ "MANAGE"
    end

    test "renders shift info" do
      assigns = %{
        store_name: "Store",
        store_slug: "store",
        merchant_name: "Merchant",
        current_path: "/app/stores/store",
        user_initials: "JD",
        vertical: :retail,
        shift_start: "2:00 PM"
      }

      html =
        rendered_to_string(~H"""
        <StoreShell.store_shell
          store_name={@store_name}
          store_slug={@store_slug}
          merchant_name={@merchant_name}
          current_path={@current_path}
          user_initials={@user_initials}
          vertical={@vertical}
          shift_start={@shift_start}
        >
          <p>Content</p>
        </StoreShell.store_shell>
        """)

      assert html =~ "2:00 PM"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/layouts/store_shell_test.exs --trace`
Expected: FAIL with "module StoreShell is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/layouts/store_shell.ex
defmodule McpWeb.Layouts.StoreShell do
  @moduledoc """
  Store Portal shell layout with left sidebar navigation.
  """
  use Phoenix.Component
  import McpWeb.Core.Navigation, only: [sidebar: 1, dropdown: 1]
  import McpWeb.Core.DataDisplay, only: [avatar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]
  import McpWeb.Portals.Merchant.Components, only: [context_switcher: 1]

  # Navigation sections - visibility controlled by vertical
  @nav_sections [
    %{
      id: :sell,
      title: "SELL",
      items: [
        %{label: "POS", href: "/pos", icon: "hero-shopping-cart", verticals: :all},
        %{label: "Terminal", href: "/terminal", icon: "hero-computer-desktop", verticals: :all},
        %{label: "Orders", href: "/orders", icon: "hero-clipboard-document-list", verticals: [:retail, :restaurant]},
        %{label: "Invoices", href: "/invoices", icon: "hero-document-text", verticals: [:retail, :services, :subscription]}
      ]
    },
    %{
      id: :manage,
      title: "MANAGE",
      items: [
        %{label: "Customers", href: "/customers", icon: "hero-users", verticals: :all},
        %{label: "Products", href: "/products", icon: "hero-cube", verticals: :all},
        %{label: "Inventory", href: "/inventory", icon: "hero-archive-box", verticals: [:retail, :restaurant]},
        %{label: "Subscriptions", href: "/subscriptions", icon: "hero-arrow-path", verticals: [:subscription]},
        %{label: "Loyalty", href: "/loyalty", icon: "hero-gift", verticals: :all}
      ]
    },
    %{
      id: :schedule,
      title: "SCHEDULE",
      items: [
        %{label: "Appointments", href: "/appointments", icon: "hero-calendar", verticals: [:services]},
        %{label: "Tables", href: "/tables", icon: "hero-table-cells", verticals: [:restaurant]},
        %{label: "Staff", href: "/staff", icon: "hero-user-group", verticals: :all}
      ]
    },
    %{
      id: :money,
      title: "MONEY",
      items: [
        %{label: "Refunds", href: "/refunds", icon: "hero-receipt-refund", verticals: :all},
        %{label: "Tips", href: "/tips", icon: "hero-banknotes", verticals: [:restaurant, :services]},
        %{label: "Reports", href: "/reports", icon: "hero-chart-bar", verticals: :all}
      ]
    }
  ]

  @doc """
  Renders the Store Portal shell with left sidebar navigation.

  ## Examples

      <.store_shell
        store_name="Downtown Store"
        store_slug="downtown"
        merchant_name="Acme Corp"
        current_path="/app/stores/downtown"
        user_initials="JD"
        vertical={:retail}
      >
        <p>Content</p>
      </.store_shell>
  """
  attr :store_name, :string, required: true
  attr :store_slug, :string, required: true
  attr :merchant_name, :string, required: true
  attr :current_path, :string, required: true
  attr :user_initials, :string, default: "?"
  attr :user_name, :string, default: nil
  attr :vertical, :atom, default: :retail, values: [:retail, :restaurant, :services, :subscription]
  attr :shift_start, :string, default: nil
  attr :other_stores, :list, default: []
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def store_shell(assigns) do
    base_path = "/app/stores/#{assigns.store_slug}"
    nav_sections = filter_nav_for_vertical(@nav_sections, assigns.vertical, base_path)
    assigns = assign(assigns, nav_sections: nav_sections, base_path: base_path)

    ~H"""
    <div class={["min-h-screen bg-base-200 flex", @class]}>
      <%!-- Left Sidebar --%>
      <aside class="w-64 bg-base-100 border-r border-base-300/50 flex flex-col">
        <%!-- Header with context switcher --%>
        <div class="p-3 border-b border-base-300/50">
          <.context_switcher
            current_name={@store_name}
            current_type={:store}
            merchant_name={@merchant_name}
            stores={@other_stores}
          />
        </div>

        <%!-- Navigation sections --%>
        <nav class="flex-1 overflow-y-auto p-2">
          <%!-- Dashboard link --%>
          <ul class="menu gap-1 mb-2">
            <li>
              <a
                href={@base_path}
                class={[
                  "flex items-center gap-3",
                  active?(@current_path, @base_path, true) && "active"
                ]}
              >
                <.icon name="hero-home" class="size-5" />
                Dashboard
              </a>
            </li>
          </ul>

          <%!-- Grouped sections --%>
          <div :for={section <- @nav_sections} class="mb-4">
            <div class="menu-title text-xs font-semibold text-base-content/60 uppercase tracking-wider px-4 py-2">
              {section.title}
            </div>
            <ul class="menu gap-1">
              <li :for={item <- section.items}>
                <a
                  href={item.full_href}
                  class={[
                    "flex items-center gap-3",
                    active?(@current_path, item.full_href, false) && "active"
                  ]}
                >
                  <.icon name={item.icon} class="size-5" />
                  {item.label}
                </a>
              </li>
            </ul>
          </div>
        </nav>

        <%!-- Footer with settings and shift --%>
        <div class="mt-auto border-t border-base-300/50 p-2">
          <ul class="menu gap-1">
            <li>
              <a href={"#{@base_path}/settings"} class="flex items-center gap-3">
                <.icon name="hero-cog-6-tooth" class="size-5" />
                Settings
              </a>
            </li>
            <li>
              <a href={"#{@base_path}/close-shift"} class="flex items-center gap-3">
                <.icon name="hero-clock" class="size-5" />
                Close Shift
              </a>
            </li>
          </ul>

          <%!-- Shift info --%>
          <div :if={@shift_start} class="px-4 py-2 text-xs text-base-content/60">
            Shift: {@shift_start} - Close
          </div>
        </div>
      </aside>

      <%!-- Main content area --%>
      <div class="flex-1 flex flex-col">
        <%!-- Top bar (slimmer than merchant) --%>
        <header class="h-12 bg-base-100 border-b border-base-300/50 flex items-center justify-end px-4 gap-2">
          <%!-- Search --%>
          <button class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-magnifying-glass" class="size-4" />
          </button>

          <%!-- Help --%>
          <button class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-question-mark-circle" class="size-4" />
          </button>

          <%!-- Notifications --%>
          <button class="btn btn-ghost btn-sm btn-circle indicator">
            <span class="indicator-item badge badge-primary badge-xs"></span>
            <.icon name="hero-bell" class="size-4" />
          </button>

          <%!-- User menu --%>
          <.dropdown position="end">
            <:trigger>
              <.avatar initials={@user_initials} size="xs" />
            </:trigger>
            <:content>
              <li :if={@user_name} class="menu-title">{@user_name}</li>
              <li><a href={"#{@base_path}/settings"}>Settings</a></li>
              <li><a href="/sign-out" data-method="delete">Sign out</a></li>
            </:content>
          </.dropdown>
        </header>

        <%!-- Main content --%>
        <main class="flex-1 p-6 overflow-auto">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  defp filter_nav_for_vertical(sections, vertical, base_path) do
    sections
    |> Enum.map(fn section ->
      items =
        section.items
        |> Enum.filter(fn item ->
          item.verticals == :all || vertical in item.verticals
        end)
        |> Enum.map(fn item ->
          Map.put(item, :full_href, base_path <> item.href)
        end)

      %{section | items: items}
    end)
    |> Enum.reject(fn section -> section.items == [] end)
  end

  defp active?(current_path, href, exact) do
    if exact do
      current_path == href
    else
      String.starts_with?(current_path, href)
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/layouts/store_shell_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/components/layouts/store_shell.ex test/mcp_web/components/layouts/store_shell_test.exs
git commit -m "feat(ui): add store shell with left sidebar navigation"
```

---

## Phase 3: Dashboard Implementations

### Task 12: Merchant Dashboard LiveView

Full merchant dashboard with stats, charts placeholders, and activity feed.

**Files:**
- Modify: `lib/mcp_web/live/merchant/dashboard_live.ex`
- Create: `test/mcp_web/live/merchant/dashboard_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/dashboard_live_test.exs
defmodule McpWeb.Merchant.DashboardLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /app/dashboard" do
    test "renders dashboard with stats", %{conn: conn} do
      # Note: In real implementation, would need auth setup
      {:ok, view, html} = live(conn, ~p"/app/dashboard")

      # Verify stat cards are rendered
      assert html =~ "Today's Revenue"
      assert html =~ "Transactions"
      assert html =~ "Customers"
      assert html =~ "Avg Order"
    end

    test "renders stores performance section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      assert html =~ "Stores Performance"
    end

    test "renders recent transactions section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      assert html =~ "Recent Transactions"
    end

    test "renders needs attention section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      assert html =~ "Needs Attention"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/dashboard_live_test.exs --trace`
Expected: FAIL (route or content missing)

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/merchant/dashboard_live.ex
defmodule McpWeb.Merchant.DashboardLive do
  use McpWeb, :live_view
  import McpWeb.Core.DataDisplay, only: [stat_card: 1, badge: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, header: 1]

  @impl true
  def mount(_params, _session, socket) do
    # In production, fetch from Ash resources
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:merchant_name, "Acme Corp")
      |> assign(:user_name, "Ryan")
      |> assign(:stats, get_mock_stats())
      |> assign(:stores_performance, get_mock_stores())
      |> assign(:recent_transactions, get_mock_transactions())
      |> assign(:alerts, get_mock_alerts())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">
            Welcome back, {@user_name}
          </h1>
          <p class="text-base-content/60 mt-1">
            Here's what's happening with your business today.
          </p>
        </div>
        <div class="flex gap-2">
          <select class="select select-bordered select-sm">
            <option>Today</option>
            <option>Yesterday</option>
            <option>Last 7 days</option>
            <option>Last 30 days</option>
          </select>
          <button class="btn btn-outline btn-sm gap-2">
            <.icon name="hero-arrow-down-tray" class="size-4" />
            Export
          </button>
        </div>
      </div>

      <%!-- Stats Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card
          :for={stat <- @stats}
          value={stat.value}
          label={stat.label}
          trend={stat.trend}
          trend_direction={stat.trend_direction}
          icon={stat.icon}
        />
      </div>

      <%!-- Charts Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Revenue Chart (2/3 width) --%>
        <.card class="lg:col-span-2">
          <.header>
            Revenue (7 days)
            <:actions>
              <button class="btn btn-ghost btn-xs">View Details</button>
            </:actions>
          </.header>
          <div class="h-64 flex items-center justify-center bg-base-200/50 rounded-lg mt-4">
            <span class="text-base-content/40">Chart placeholder</span>
          </div>
        </.card>

        <%!-- Stores Performance --%>
        <.card>
          <.header>Stores Performance</.header>
          <div class="space-y-4 mt-4">
            <div :for={store <- @stores_performance} class="flex items-center gap-3">
              <div class="flex-1">
                <div class="flex justify-between text-sm">
                  <span class="font-medium">{store.name}</span>
                  <span class="text-base-content/70">{store.revenue}</span>
                </div>
                <progress
                  class="progress progress-primary w-full h-2 mt-1"
                  value={store.percent}
                  max="100"
                >
                </progress>
              </div>
            </div>
          </div>
        </.card>
      </div>

      <%!-- Bottom Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Recent Transactions --%>
        <.card>
          <.header>
            Recent Transactions
            <:actions>
              <a href="/app/payments" class="btn btn-ghost btn-xs">View All</a>
            </:actions>
          </.header>
          <div class="overflow-x-auto mt-4">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Customer</th>
                  <th>Amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={txn <- @recent_transactions}>
                  <td class="text-base-content/70">{txn.time}</td>
                  <td>{txn.customer}</td>
                  <td class="font-medium">{txn.amount}</td>
                  <td>
                    <.badge variant={status_variant(txn.status)} size="sm">
                      {txn.status}
                    </.badge>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.card>

        <%!-- Needs Attention --%>
        <.card>
          <.header>Needs Attention</.header>
          <div class="space-y-3 mt-4">
            <a
              :for={alert <- @alerts}
              href={alert.href}
              class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors"
            >
              <div class={[
                "p-2 rounded-lg",
                alert.type == :warning && "bg-warning/20 text-warning",
                alert.type == :error && "bg-error/20 text-error",
                alert.type == :info && "bg-info/20 text-info"
              ]}>
                <.icon name={alert.icon} class="size-5" />
              </div>
              <div class="flex-1">
                <p class="font-medium text-sm">{alert.title}</p>
                <p class="text-xs text-base-content/60">{alert.description}</p>
              </div>
              <.icon name="hero-chevron-right" class="size-4 text-base-content/40" />
            </a>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  defp status_variant("completed"), do: "success"
  defp status_variant("pending"), do: "warning"
  defp status_variant("failed"), do: "error"
  defp status_variant(_), do: nil

  # Mock data functions - replace with Ash resource queries
  defp get_mock_stats do
    [
      %{
        value: "$12,847",
        label: "Today's Revenue",
        trend: "+12% vs yesterday",
        trend_direction: :up,
        icon: "hero-currency-dollar"
      },
      %{
        value: "156",
        label: "Transactions",
        trend: "+8% vs yesterday",
        trend_direction: :up,
        icon: "hero-receipt-percent"
      },
      %{
        value: "89",
        label: "Customers",
        trend: "-3% vs yesterday",
        trend_direction: :down,
        icon: "hero-users"
      },
      %{
        value: "$82.35",
        label: "Avg Order",
        trend: "+5% vs yesterday",
        trend_direction: :up,
        icon: "hero-shopping-cart"
      }
    ]
  end

  defp get_mock_stores do
    [
      %{name: "Downtown", revenue: "$6,420", percent: 100},
      %{name: "Online", revenue: "$4,890", percent: 76},
      %{name: "Warehouse", revenue: "$1,537", percent: 24}
    ]
  end

  defp get_mock_transactions do
    [
      %{time: "2:34 PM", customer: "J. Smith", amount: "$124.00", status: "completed"},
      %{time: "2:21 PM", customer: "M. Lee", amount: "$89.50", status: "completed"},
      %{time: "2:15 PM", customer: "Guest", amount: "$42.00", status: "completed"},
      %{time: "2:08 PM", customer: "A. Johnson", amount: "$215.00", status: "pending"},
      %{time: "1:55 PM", customer: "C. Williams", amount: "$67.25", status: "completed"}
    ]
  end

  defp get_mock_alerts do
    [
      %{
        type: :warning,
        icon: "hero-exclamation-triangle",
        title: "3 failed transactions",
        description: "Review and retry or refund",
        href: "/app/payments?status=failed"
      },
      %{
        type: :warning,
        icon: "hero-credit-card",
        title: "MID approaching limit",
        description: "QorPay at 85% of monthly volume",
        href: "/app/payments/mids"
      },
      %{
        type: :info,
        icon: "hero-document-text",
        title: "5 invoices overdue",
        description: "Send reminders to customers",
        href: "/app/invoices?status=overdue"
      }
    ]
  end
end
```

**Step 4: Update router to use new dashboard**

The router already has `/app/dashboard` pointing to `MockDashboardLive`. Update to point to `Merchant.DashboardLive`:

```elixir
# In router.ex, change:
# live "/dashboard", MockDashboardLive
# to:
# live "/dashboard", Merchant.DashboardLive
```

**Step 5: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/dashboard_live_test.exs --trace`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/mcp_web/live/merchant/dashboard_live.ex test/mcp_web/live/merchant/dashboard_live_test.exs lib/mcp_web/router.ex
git commit -m "feat(ui): implement merchant dashboard with stats and activity"
```

---

### Task 13: Store Dashboard LiveView

Store dashboard with quick actions, shift context, and pending items.

**Files:**
- Modify: `lib/mcp_web/live/store/dashboard_live.ex`
- Create: `test/mcp_web/live/store/dashboard_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/store/dashboard_live_test.exs
defmodule McpWeb.Store.DashboardLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /app/stores/:slug" do
    test "renders dashboard with today's stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Today's Sales"
      assert html =~ "Transactions"
      assert html =~ "Avg Ticket"
    end

    test "renders quick actions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Quick Actions"
      assert html =~ "New Sale"
    end

    test "renders pending items", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Pending"
    end

    test "renders recent transactions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Recent Transactions"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/store/dashboard_live_test.exs --trace`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/store/dashboard_live.ex
defmodule McpWeb.Store.DashboardLive do
  use McpWeb, :live_view
  import McpWeb.Core.DataDisplay, only: [stat_card: 1, badge: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, header: 1, button: 1]

  @impl true
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Store Dashboard")
      |> assign(:store_slug, store_slug)
      |> assign(:store_name, "Downtown Store")
      |> assign(:shift_start, "2:00 PM")
      |> assign(:stats, get_mock_stats())
      |> assign(:quick_actions, get_quick_actions(store_slug))
      |> assign(:recent_transactions, get_mock_transactions())
      |> assign(:pending_items, get_mock_pending())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header with shift info --%>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">Good afternoon</h1>
          <p class="text-base-content/60 mt-1">{@store_name}</p>
        </div>
        <div class="flex items-center gap-2 text-sm text-base-content/70">
          <.icon name="hero-clock" class="size-4" />
          <span>Shift: {@shift_start} - Close</span>
        </div>
      </div>

      <%!-- Stats --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.stat_card
          :for={stat <- @stats}
          value={stat.value}
          label={stat.label}
          icon={stat.icon}
        />
      </div>

      <%!-- Quick Actions --%>
      <.card>
        <.header class="mb-4">Quick Actions</.header>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <a
            :for={action <- @quick_actions}
            href={action.href}
            class={[
              "flex flex-col items-center justify-center gap-3 p-6",
              "bg-base-200/50 rounded-xl",
              "border-2 border-transparent",
              "hover:border-primary hover:bg-base-200",
              "transition-all duration-200",
              "group"
            ]}
          >
            <div class={[
              "p-4 rounded-full",
              "bg-primary/10 text-primary",
              "group-hover:bg-primary group-hover:text-primary-content",
              "transition-colors duration-200"
            ]}>
              <.icon name={action.icon} class="size-8" />
            </div>
            <span class="font-medium text-base-content">{action.label}</span>
          </a>
        </div>
      </.card>

      <%!-- Bottom Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Recent Transactions --%>
        <.card>
          <.header>
            Recent Transactions
            <:actions>
              <a href={"/app/stores/#{@store_slug}/transactions"} class="btn btn-ghost btn-xs">
                View All
              </a>
            </:actions>
          </.header>
          <div class="space-y-2 mt-4">
            <div
              :for={txn <- @recent_transactions}
              class="flex items-center justify-between p-3 bg-base-200/30 rounded-lg"
            >
              <div class="flex items-center gap-3">
                <span class="text-sm text-base-content/60">{txn.time}</span>
                <span class="font-medium">{txn.customer}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="font-semibold">{txn.amount}</span>
                <.icon name="hero-check-circle" class="size-5 text-success" />
              </div>
            </div>
          </div>
        </.card>

        <%!-- Pending Items --%>
        <.card>
          <.header>Pending</.header>
          <div class="space-y-3 mt-4">
            <a
              :for={item <- @pending_items}
              href={item.href}
              class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors"
            >
              <div class={[
                "p-2 rounded-lg",
                item.type == :order && "bg-info/20 text-info",
                item.type == :invoice && "bg-warning/20 text-warning",
                item.type == :refund && "bg-error/20 text-error"
              ]}>
                <.icon name={item.icon} class="size-5" />
              </div>
              <div class="flex-1">
                <p class="font-medium text-sm">{item.title}</p>
              </div>
              <.icon name="hero-chevron-right" class="size-4 text-base-content/40" />
            </a>

            <div
              :if={@pending_items == []}
              class="text-center py-8 text-base-content/50"
            >
              <.icon name="hero-check-circle" class="size-12 mx-auto mb-2 opacity-50" />
              <p>All caught up!</p>
            </div>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  # Mock data - replace with Ash queries
  defp get_mock_stats do
    [
      %{value: "$2,847", label: "Today's Sales", icon: "hero-currency-dollar"},
      %{value: "34", label: "Transactions", icon: "hero-receipt-percent"},
      %{value: "$83.74", label: "Avg Ticket", icon: "hero-shopping-cart"}
    ]
  end

  defp get_quick_actions(store_slug) do
    base = "/app/stores/#{store_slug}"

    [
      %{label: "New Sale", icon: "hero-credit-card", href: "#{base}/pos"},
      %{label: "Invoice", icon: "hero-document-text", href: "#{base}/invoices/new"},
      %{label: "Customer Lookup", icon: "hero-user", href: "#{base}/customers"},
      %{label: "Refund", icon: "hero-receipt-refund", href: "#{base}/refunds/new"}
    ]
  end

  defp get_mock_transactions do
    [
      %{time: "2:34 PM", customer: "J. Smith", amount: "$124.00"},
      %{time: "2:21 PM", customer: "M. Lee", amount: "$89.50"},
      %{time: "2:15 PM", customer: "Guest", amount: "$42.00"}
    ]
  end

  defp get_mock_pending do
    [
      %{
        type: :order,
        icon: "hero-truck",
        title: "2 orders ready to ship",
        href: "#"
      },
      %{
        type: :invoice,
        icon: "hero-document-text",
        title: "1 invoice awaiting payment",
        href: "#"
      },
      %{
        type: :refund,
        icon: "hero-receipt-refund",
        title: "1 refund request",
        href: "#"
      }
    ]
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/store/dashboard_live_test.exs --trace`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/dashboard_live.ex test/mcp_web/live/store/dashboard_live_test.exs
git commit -m "feat(ui): implement store dashboard with quick actions and pending items"
```

---

## Phase 4: Integration

### Task 14: Update PortalLayouts to Use New Shells

Wire up the new shell components to the portal layouts.

**Files:**
- Modify: `lib/mcp_web/components/layouts/portal_layouts.ex`

**Step 1: Write integration test**

```elixir
# Add to existing test file or create new
# test/mcp_web/components/layouts/portal_layouts_test.exs
defmodule McpWeb.Layouts.PortalLayoutsTest do
  use McpWeb.ConnCase, async: true

  describe "merchant_portal/1" do
    test "renders merchant shell layout", %{conn: conn} do
      conn = get(conn, ~p"/app")
      html = html_response(conn, 200)

      # Should use new merchant shell with top nav
      assert html =~ "navbar"
    end
  end

  describe "store_portal/1" do
    test "renders store shell layout", %{conn: conn} do
      conn = get(conn, ~p"/app/stores/downtown")
      html = html_response(conn, 200)

      # Should use store shell with sidebar
      assert html =~ "SELL"
    end
  end
end
```

**Step 2: Update portal_layouts.ex**

```elixir
# lib/mcp_web/components/layouts/portal_layouts.ex
# Update merchant_portal and store_portal functions to use new shells

def merchant_portal(assigns) do
  # Extract data from conn/session for the shell
  assigns =
    assigns
    |> assign_new(:merchant_name, fn -> get_merchant_name(assigns) end)
    |> assign_new(:stores, fn -> get_stores(assigns) end)
    |> assign_new(:current_path, fn -> get_current_path(assigns) end)
    |> assign_new(:user_initials, fn -> get_user_initials(assigns) end)

  ~H"""
  <McpWeb.Layouts.MerchantShell.merchant_shell
    merchant_name={@merchant_name}
    stores={@stores}
    current_path={@current_path}
    user_initials={@user_initials}
  >
    {@inner_content}
  </McpWeb.Layouts.MerchantShell.merchant_shell>
  """
end

def store_portal(assigns) do
  store_slug = assigns.conn.params["store_slug"] || "unknown"

  assigns =
    assigns
    |> assign(:store_slug, store_slug)
    |> assign_new(:store_name, fn -> get_store_name(assigns, store_slug) end)
    |> assign_new(:merchant_name, fn -> get_merchant_name(assigns) end)
    |> assign_new(:current_path, fn -> get_current_path(assigns) end)
    |> assign_new(:user_initials, fn -> get_user_initials(assigns) end)
    |> assign_new(:vertical, fn -> :retail end)

  ~H"""
  <McpWeb.Layouts.StoreShell.store_shell
    store_name={@store_name}
    store_slug={@store_slug}
    merchant_name={@merchant_name}
    current_path={@current_path}
    user_initials={@user_initials}
    vertical={@vertical}
  >
    {@inner_content}
  </McpWeb.Layouts.StoreShell.store_shell>
  """
end

# Helper functions
defp get_merchant_name(assigns) do
  # In production, get from session/assigns
  Map.get(assigns, :merchant_name, "Acme Corp")
end

defp get_stores(_assigns) do
  # In production, query from Ash
  [
    %{name: "Downtown Store", slug: "downtown"},
    %{name: "Online Shop", slug: "online"}
  ]
end

defp get_store_name(_assigns, slug) do
  # In production, query from Ash
  case slug do
    "downtown" -> "Downtown Store"
    "online" -> "Online Shop"
    _ -> "Store"
  end
end

defp get_current_path(assigns) do
  assigns.conn.request_path
end

defp get_user_initials(assigns) do
  # In production, get from current_user
  Map.get(assigns, :user_initials, "JD")
end
```

**Step 3: Run tests**

Run: `mix test test/mcp_web/components/layouts/portal_layouts_test.exs --trace`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/mcp_web/components/layouts/portal_layouts.ex test/mcp_web/components/layouts/portal_layouts_test.exs
git commit -m "feat(ui): integrate new shells into portal layouts"
```

---

### Task 15: Export Components from mcp_web.ex

Ensure all new components are properly imported for use.

**Files:**
- Modify: `lib/mcp_web.ex`

**Step 1: Add imports to html_helpers**

```elixir
# In lib/mcp_web.ex, update the html_helpers function to include:

defp html_helpers do
  quote do
    # ... existing imports ...

    # Core UI components
    import McpWeb.Core.CoreComponents
    import McpWeb.Core.DataDisplay
    import McpWeb.Core.Feedback
    import McpWeb.Core.Navigation

    # ... rest of helpers ...
  end
end
```

**Step 2: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 3: Run precommit**

Run: `mix precommit`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/mcp_web.ex
git commit -m "feat(ui): export new components from mcp_web helpers"
```

---

## Quality Gates

After completing all tasks, run:

```bash
# Full test suite
mix test

# Precommit checks
mix precommit

# Visual inspection
mix phx.server
# Navigate to http://localhost:4000/app for Merchant Portal
# Navigate to http://localhost:4000/app/stores/downtown for Store Portal
```

---

## Summary

**Phase 1 (Tasks 1-9):** Foundation CoreComponents
- stat_card, badge, avatar, skeleton, dropdown, navbar, sidebar, tabs, context_switcher

**Phase 2 (Tasks 10-11):** Shell Layouts
- merchant_shell (top nav + contextual sidebar)
- store_shell (left sidebar with grouped sections)

**Phase 3 (Tasks 12-13):** Dashboard Implementations
- Merchant Dashboard with stats, charts, activity
- Store Dashboard with quick actions, pending items

**Phase 4 (Tasks 14-15):** Integration
- Wire shells to portal layouts
- Export components

**Total: 15 tasks, TDD throughout, quality gates at end**
