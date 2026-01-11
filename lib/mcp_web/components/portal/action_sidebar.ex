# lib/mcp_web/components/portal/action_sidebar.ex
defmodule McpWeb.Portal.ActionSidebar do
  @moduledoc """
  ActionSidebar component for portal pages.

  Provides a fixed-width sidebar with three sections:
  - QUICK ACTIONS: Primary action buttons (icon + label)
  - FILTERS: Dropdown/checkbox filters
  - AI INSIGHTS: Proactive insight cards (optional)

  ## Examples

      <.action_sidebar>
        <:actions>
          <.sidebar_action icon="hero-plus" label="Add New" href={~p"/products/new"} />
          <.sidebar_action icon="hero-arrow-up-tray" label="Import" phx-click="open_import" />
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
  """
  use Phoenix.Component

  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders the action sidebar container with three sections.

  ## Attributes

  - `class` - Additional CSS classes for the sidebar container

  ## Slots

  - `actions` - Quick action buttons (required)
  - `filters` - Filter dropdowns (optional)
  - `insights` - AI insight cards (optional)
  """
  attr :class, :string, default: nil
  attr :"data-testid", :string, default: nil

  slot :actions
  slot :filters
  slot :insights

  def action_sidebar(assigns) do
    ~H"""
    <aside
      class={[
        "w-72 sticky top-20",
        "flex flex-col gap-6",
        @class
      ]}
      data-testid={assigns[:"data-testid"]}
    >
      <section :if={@actions != []} class="flex flex-col gap-2">
        <h3 class="text-xs font-semibold uppercase tracking-wider text-base-content/60 px-1">
          QUICK ACTIONS
        </h3>
        <div class="flex flex-col gap-1">
          {render_slot(@actions)}
        </div>
      </section>

      <section :if={@filters != []} class="flex flex-col gap-2">
        <h3 class="text-xs font-semibold uppercase tracking-wider text-base-content/60 px-1">
          FILTERS
        </h3>
        <div class="flex flex-col gap-2">
          {render_slot(@filters)}
        </div>
      </section>

      <section :if={@insights != []} class="flex flex-col gap-2">
        <h3 class="text-xs font-semibold uppercase tracking-wider text-base-content/60 px-1">
          AI INSIGHTS
        </h3>
        <div class="flex flex-col gap-2">
          {render_slot(@insights)}
        </div>
      </section>
    </aside>
    """
  end

  @doc """
  Renders a sidebar action button.

  Actions can be links (using `href`) or LiveView events (using `phx-click`).

  ## Attributes

  - `icon` - Heroicon name (e.g., "hero-plus")
  - `label` - Button label text
  - `href` - URL for link actions (optional)
  - `disabled` - Whether the action is disabled (optional)
  - `rest` - Additional attributes including phx-click, phx-value-*, etc.

  ## Examples

      <.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
      <.sidebar_action icon="hero-arrow-up-tray" label="Import" phx-click="open_import" />
      <.sidebar_action icon="hero-trash" label="Delete" phx-click="delete" disabled={true} />
  """
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :href, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-id phx-value-type)

  def sidebar_action(assigns) do
    ~H"""
    <%= if @href do %>
      <a
        href={@href}
        class={[
          "btn btn-ghost btn-sm",
          "justify-start gap-2 w-full",
          "transition-colors duration-150",
          @disabled && "btn-disabled"
        ]}
        {@rest}
      >
        <.icon name={@icon} class="size-4" />
        <span>{@label}</span>
      </a>
    <% else %>
      <button
        type="button"
        disabled={@disabled}
        class={[
          "btn btn-ghost btn-sm",
          "justify-start gap-2 w-full",
          "transition-colors duration-150"
        ]}
        {@rest}
      >
        <.icon name={@icon} class="size-4" />
        <span>{@label}</span>
      </button>
    <% end %>
    """
  end

  @doc """
  Renders a sidebar filter dropdown.

  ## Attributes

  - `label` - Filter label
  - `options` - List of `{label, value}` tuples for the select options
  - `field` - Field name (atom) for the select name attribute
  - `value` - Currently selected value (optional)
  - `rest` - Additional attributes including phx-change

  ## Examples

      <.sidebar_filter
        label="Status"
        options={[{"All", ""}, {"Active", "active"}, {"Inactive", "inactive"}]}
        field={:status}
        phx-change="filter_changed"
      />
  """
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :field, :atom, required: true
  attr :value, :string, default: nil
  attr :rest, :global, include: ~w(phx-change)

  def sidebar_filter(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label py-1">
        <span class="label-text text-sm">{@label}</span>
      </label>
      <select
        name={@field}
        class={[
          "select select-bordered select-sm w-full",
          "focus:outline-none focus:select-primary"
        ]}
        {@rest}
      >
        <option
          :for={{opt_label, opt_value} <- @options}
          value={opt_value}
          selected={@value == opt_value}
        >
          {opt_label}
        </option>
      </select>
    </div>
    """
  end

  @doc """
  Renders an AI insight card.

  Insights can link to a URL (using `href`) or trigger LiveView events (using `phx-click`).

  ## Attributes

  - `message` - Insight message text
  - `action` - Action link text
  - `href` - URL for the action link (optional)
  - `rest` - Additional attributes including phx-click

  ## Examples

      <.ai_insight
        message="3 products are low on stock"
        action="View low stock"
        href="/products?filter=low_stock"
      />
      <.ai_insight
        message="New recommendations available"
        action="View recommendations"
        phx-click="show_recommendations"
      />
  """
  attr :message, :string, required: true
  attr :action, :string, required: true
  attr :href, :string, default: nil
  attr :rest, :global, include: ~w(phx-click)

  def ai_insight(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-box p-3">
      <p class="text-sm text-base-content/80 mb-2">
        {@message}
      </p>
      <%= if @href do %>
        <a
          href={@href}
          class="link link-accent text-sm font-medium"
          {@rest}
        >
          {@action}
        </a>
      <% else %>
        <button
          type="button"
          class="link link-accent text-sm font-medium"
          {@rest}
        >
          {@action}
        </button>
      <% end %>
    </div>
    """
  end
end
