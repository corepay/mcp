defmodule McpWeb.Dev.PortalComponentsLive do
  @moduledoc """
  Development page for showcasing all portal components and verifying responsive behavior.

  This page demonstrates:
  - StatsRow with various metrics and trends
  - ActionSidebar with actions, filters, and AI insights
  - PageLayout variants (dashboard, list, detail, table)
  - DataTable with pagination and sorting
  - FocusedLayout variants (two_panel, centered, wizard)
  """
  use McpWeb, :live_view

  alias McpWeb.Portal.{ActionSidebar, DataTable, FocusedLayout, PageLayout, StatsRow}

  import McpWeb.Core.CoreComponents

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Portal Components")
      |> assign(:current_section, :stats_row)
      |> assign(:sample_transactions, sample_transactions())
      |> assign(:current_page, 1)
      |> assign(:total_pages, 5)
      |> assign(:total_count, 47)
      |> assign(:sort_by, nil)
      |> assign(:sort_dir, :asc)

    {:ok, socket}
  end

  def handle_event("navigate_section", %{"section" => section}, socket) do
    {:noreply, assign(socket, :current_section, String.to_existing_atom(section))}
  end

  def handle_event("page-change", %{"page" => page}, socket) do
    {:noreply, assign(socket, :current_page, String.to_integer(page))}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)
    current_sort_by = socket.assigns.sort_by
    current_sort_dir = socket.assigns.sort_dir

    {new_sort_by, new_sort_dir} =
      if current_sort_by == field do
        {field, toggle_direction(current_sort_dir)}
      else
        {field, :asc}
      end

    {:noreply, assign(socket, sort_by: new_sort_by, sort_dir: new_sort_dir)}
  end

  def handle_event("filter_changed", _params, socket) do
    {:noreply, put_flash(socket, :info, "Filter changed")}
  end

  def handle_event("sidebar_action", %{"action" => action}, socket) do
    {:noreply, put_flash(socket, :info, "Action triggered: #{action}")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <%!-- Sticky Navigation --%>
      <div class="sticky top-0 z-50 bg-base-100 border-b border-base-300 shadow-sm">
        <div class="container mx-auto px-6 py-4">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h1 class="text-3xl font-bold text-base-content">Portal Components</h1>
              <p class="text-sm text-base-content/60 mt-1">
                Living documentation for all portal UI components
              </p>
            </div>
            <.link href="/dev/style-guide" class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="size-4" />
              <span>Back to Style Guide</span>
            </.link>
          </div>

          <%!-- Component Navigation --%>
          <div class="flex gap-2 flex-wrap">
            <button
              phx-click="navigate_section"
              phx-value-section="stats_row"
              class={[
                "btn btn-sm",
                @current_section == :stats_row && "btn-primary",
                @current_section != :stats_row && "btn-ghost"
              ]}
            >
              StatsRow
            </button>
            <button
              phx-click="navigate_section"
              phx-value-section="action_sidebar"
              class={[
                "btn btn-sm",
                @current_section == :action_sidebar && "btn-primary",
                @current_section != :action_sidebar && "btn-ghost"
              ]}
            >
              ActionSidebar
            </button>
            <button
              phx-click="navigate_section"
              phx-value-section="page_layout"
              class={[
                "btn btn-sm",
                @current_section == :page_layout && "btn-primary",
                @current_section != :page_layout && "btn-ghost"
              ]}
            >
              PageLayout
            </button>
            <button
              phx-click="navigate_section"
              phx-value-section="data_table"
              class={[
                "btn btn-sm",
                @current_section == :data_table && "btn-primary",
                @current_section != :data_table && "btn-ghost"
              ]}
            >
              DataTable
            </button>
            <button
              phx-click="navigate_section"
              phx-value-section="focused_layout"
              class={[
                "btn btn-sm",
                @current_section == :focused_layout && "btn-primary",
                @current_section != :focused_layout && "btn-ghost"
              ]}
            >
              FocusedLayout
            </button>
            <button
              phx-click="navigate_section"
              phx-value-section="responsive"
              class={[
                "btn btn-sm",
                @current_section == :responsive && "btn-primary",
                @current_section != :responsive && "btn-ghost"
              ]}
            >
              Responsive Behavior
            </button>
          </div>
        </div>
      </div>

      <%!-- Main Content --%>
      <div class="container mx-auto px-6 py-8">
        <%= case @current_section do %>
          <% :stats_row -> %>
            <.stats_row_section />
          <% :action_sidebar -> %>
            <.action_sidebar_section />
          <% :page_layout -> %>
            <.page_layout_section />
          <% :data_table -> %>
            <.data_table_section
              transactions={@sample_transactions}
              current_page={@current_page}
              total_pages={@total_pages}
              total_count={@total_count}
              sort_by={@sort_by}
              sort_dir={@sort_dir}
            />
          <% :focused_layout -> %>
            <.focused_layout_section />
          <% :responsive -> %>
            <.responsive_section />
        <% end %>
      </div>
    </div>
    """
  end

  # ===========================
  # Section Components
  # ===========================

  defp stats_row_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-bold text-base-content mb-2">StatsRow Component</h2>
        <p class="text-base-content/70 mb-4">
          Responsive grid layout for displaying key metrics. Shows 4 columns on desktop (≥768px) and 2x2 grid on mobile.
        </p>
      </div>

      <div class="space-y-6">
        <div>
          <h3 class="text-lg font-semibold mb-3">Basic Stats with Trends</h3>
          <StatsRow.stats_row>
            <StatsRow.stat
              label="Revenue"
              value="$12,847"
              trend={12}
              comparison="vs yesterday"
              icon="hero-currency-dollar"
            />
            <StatsRow.stat
              label="Transactions"
              value="156"
              trend={8}
              comparison="vs yesterday"
              icon="hero-shopping-cart"
            />
            <StatsRow.stat
              label="Customers"
              value="89"
              trend={-3}
              comparison="vs yesterday"
              icon="hero-user-group"
            />
            <StatsRow.stat
              label="Avg Order"
              value="$82.35"
              trend={5}
              comparison="vs yesterday"
              icon="hero-chart-bar"
            />
          </StatsRow.stats_row>
        </div>

        <div>
          <h3 class="text-lg font-semibold mb-3">Stats with Links (Clickable)</h3>
          <StatsRow.stats_row>
            <StatsRow.stat
              label="Active Products"
              value="234"
              href="#products"
              icon="hero-cube"
            />
            <StatsRow.stat label="Pending Orders" value="12" href="#orders" icon="hero-clock" />
            <StatsRow.stat
              label="Low Stock Items"
              value="8"
              trend={-25}
              href="#inventory"
              icon="hero-exclamation-triangle"
            />
            <StatsRow.stat label="Total Sales" value="$45,230" trend={18} href="#sales" />
          </StatsRow.stats_row>
        </div>

        <div>
          <h3 class="text-lg font-semibold mb-3">Mixed Trends (Positive, Negative, Neutral)</h3>
          <StatsRow.stats_row>
            <StatsRow.stat label="Conversion Rate" value="3.2%" trend={15} comparison="vs last week" />
            <StatsRow.stat label="Bounce Rate" value="42%" trend={-8} comparison="vs last week" />
            <StatsRow.stat label="Avg Session" value="4:32" trend={0} comparison="unchanged" />
            <StatsRow.stat label="Page Views" value="12.4k" trend={22} comparison="vs last week" />
          </StatsRow.stats_row>
        </div>
      </div>

      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="size-5" />
        <div>
          <h4 class="font-semibold">Responsive Behavior</h4>
          <p class="text-sm">
            On mobile (&lt;768px): 2 columns in 2 rows. On tablet/desktop (≥768px): 4 columns in 1 row.
            Resize your browser to see the layout adapt.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp action_sidebar_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-bold text-base-content mb-2">ActionSidebar Component</h2>
        <p class="text-base-content/70 mb-4">
          Fixed-width sidebar (288px) with quick actions, filters, and AI insights. Typically used in 2/3+1/3 layouts.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <.card class="bg-base-100">
            <h3 class="card-title mb-4">Main Content Area</h3>
            <p class="text-base-content/70 mb-4">
              This would be your main content (list of products, transactions, etc).
              The ActionSidebar appears on the right side on desktop and stacks below on mobile.
            </p>
            <div class="space-y-3">
              <div class="skeleton h-20 w-full"></div>
              <div class="skeleton h-20 w-full"></div>
              <div class="skeleton h-20 w-full"></div>
            </div>
          </.card>
        </div>

        <div class="lg:col-span-1">
          <ActionSidebar.action_sidebar>
            <:actions>
              <ActionSidebar.sidebar_action
                icon="hero-plus"
                label="Add New Product"
                phx-click="sidebar_action"
                phx-value-action="add_product"
              />
              <ActionSidebar.sidebar_action
                icon="hero-arrow-up-tray"
                label="Import CSV"
                phx-click="sidebar_action"
                phx-value-action="import"
              />
              <ActionSidebar.sidebar_action
                icon="hero-arrow-down-tray"
                label="Export Data"
                phx-click="sidebar_action"
                phx-value-action="export"
              />
              <ActionSidebar.sidebar_action
                icon="hero-folder-open"
                label="Bulk Edit"
                phx-click="sidebar_action"
                phx-value-action="bulk_edit"
              />
            </:actions>

            <:filters>
              <ActionSidebar.sidebar_filter
                label="Status"
                options={[
                  {"All Statuses", ""},
                  {"Active", "active"},
                  {"Inactive", "inactive"},
                  {"Draft", "draft"}
                ]}
                field={:status}
                phx-change="filter_changed"
              />
              <ActionSidebar.sidebar_filter
                label="Category"
                options={[
                  {"All Categories", ""},
                  {"Electronics", "electronics"},
                  {"Clothing", "clothing"},
                  {"Food & Beverage", "food"}
                ]}
                field={:category}
                phx-change="filter_changed"
              />
              <ActionSidebar.sidebar_filter
                label="Price Range"
                options={[
                  {"Any Price", ""},
                  {"Under $10", "0-10"},
                  {"$10 - $50", "10-50"},
                  {"Over $50", "50+"}
                ]}
                field={:price}
                phx-change="filter_changed"
              />
            </:filters>

            <:insights>
              <ActionSidebar.ai_insight
                message="8 products are running low on stock"
                action="View inventory alerts"
                phx-click="sidebar_action"
                phx-value-action="view_low_stock"
              />
              <ActionSidebar.ai_insight
                message="Best time to restock: Tuesday mornings"
                action="Schedule restock"
                phx-click="sidebar_action"
                phx-value-action="schedule_restock"
              />
              <ActionSidebar.ai_insight
                message="3 products trending upward this week"
                action="View trending items"
                phx-click="sidebar_action"
                phx-value-action="view_trending"
              />
            </:insights>
          </ActionSidebar.action_sidebar>
        </div>
      </div>

      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="size-5" />
        <div>
          <h4 class="font-semibold">Responsive Behavior</h4>
          <p class="text-sm">
            On desktop (≥1024px): Sidebar appears in right column. On tablet/mobile: Sidebar stacks below main content.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp page_layout_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-bold text-base-content mb-2">PageLayout Component</h2>
        <p class="text-base-content/70 mb-4">
          Consistent page structure with support for 4 variants: dashboard, list, detail, and table.
        </p>
      </div>

      <div class="space-y-8">
        <%!-- Dashboard Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">Dashboard Variant (Full Width)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box p-1">
            <PageLayout.page_layout variant={:dashboard} title="Dashboard">
              <:stats>
                <StatsRow.stats_row>
                  <StatsRow.stat label="Today's Revenue" value="$8,234" trend={12} />
                  <StatsRow.stat label="Orders" value="47" trend={8} />
                  <StatsRow.stat label="Customers" value="32" trend={-3} />
                  <StatsRow.stat label="Avg Order" value="$175" trend={5} />
                </StatsRow.stats_row>
              </:stats>

              <:content>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <.card class="bg-base-100">
                    <h3 class="card-title">Recent Activity</h3>
                    <div class="space-y-2 mt-4">
                      <div class="skeleton h-12 w-full"></div>
                      <div class="skeleton h-12 w-full"></div>
                      <div class="skeleton h-12 w-full"></div>
                    </div>
                  </.card>

                  <.card class="bg-base-100">
                    <h3 class="card-title">Quick Stats</h3>
                    <div class="space-y-2 mt-4">
                      <div class="skeleton h-12 w-full"></div>
                      <div class="skeleton h-12 w-full"></div>
                      <div class="skeleton h-12 w-full"></div>
                    </div>
                  </.card>
                </div>
              </:content>
            </PageLayout.page_layout>
          </div>
        </div>

        <%!-- List Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">List Variant (2/3 + 1/3 with Sidebar)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box p-1">
            <PageLayout.page_layout variant={:list} title="Products">
              <:toolbar>
                <.input type="text" name="search" placeholder="Search products..." class="flex-1" />
                <.button variant="primary">+ Add Product</.button>
              </:toolbar>

              <:content>
                <.card class="bg-base-100">
                  <div class="space-y-3">
                    <div :for={i <- 1..5} class="flex items-center gap-4 p-3 bg-base-200 rounded-box">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-box w-12 h-12">
                          <span>{i}</span>
                        </div>
                      </div>
                      <div class="flex-1">
                        <h4 class="font-semibold">Product {i}</h4>
                        <p class="text-sm text-base-content/60">Sample product description</p>
                      </div>
                      <div class="badge badge-primary">Active</div>
                    </div>
                  </div>
                </.card>
              </:content>

              <:sidebar>
                <ActionSidebar.action_sidebar>
                  <:actions>
                    <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="#" />
                    <ActionSidebar.sidebar_action icon="hero-arrow-up-tray" label="Import" href="#" />
                  </:actions>
                  <:filters>
                    <ActionSidebar.sidebar_filter
                      label="Status"
                      options={[{"All", ""}, {"Active", "active"}]}
                      field={:status}
                    />
                  </:filters>
                </ActionSidebar.action_sidebar>
              </:sidebar>
            </PageLayout.page_layout>
          </div>
        </div>

        <%!-- Detail Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">Detail Variant (with Back Navigation)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box p-1">
            <PageLayout.page_layout variant={:detail} title="Product #12345" back="#products">
              <:content>
                <.card class="bg-base-100">
                  <h3 class="card-title mb-4">Product Details</h3>
                  <div class="space-y-4">
                    <div>
                      <label class="label"><span class="label-text">Name</span></label>
                      <.input type="text" name="name" value="Sample Product" />
                    </div>
                    <div>
                      <label class="label"><span class="label-text">Price</span></label>
                      <.input type="text" name="price" value="$49.99" />
                    </div>
                    <div>
                      <label class="label"><span class="label-text">Description</span></label>
                      <textarea class="textarea textarea-bordered w-full" rows="4">
    Product description goes here...</textarea>
                    </div>
                  </div>
                </.card>
              </:content>

              <:sidebar>
                <ActionSidebar.action_sidebar>
                  <:actions>
                    <ActionSidebar.sidebar_action icon="hero-pencil" label="Edit" href="#" />
                    <ActionSidebar.sidebar_action icon="hero-trash" label="Delete" href="#" />
                    <ActionSidebar.sidebar_action
                      icon="hero-document-duplicate"
                      label="Duplicate"
                      href="#"
                    />
                  </:actions>
                </ActionSidebar.action_sidebar>
              </:sidebar>
            </PageLayout.page_layout>
          </div>
        </div>

        <%!-- Table Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">Table Variant (Full Width for Data Tables)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box p-1">
            <PageLayout.page_layout variant={:table} title="Transactions">
              <:toolbar>
                <.input type="text" name="search" placeholder="Search..." class="flex-1" />
                <select class="select select-bordered">
                  <option>All Types</option>
                  <option>Sale</option>
                  <option>Refund</option>
                </select>
              </:toolbar>

              <:content>
                <.card class="bg-base-100">
                  <table class="table">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Customer</th>
                        <th>Amount</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={i <- 1..5}>
                        <td class="font-mono text-sm">TXN-{1000 + i}</td>
                        <td>Customer {i}</td>
                        <td>${50 + i * 10}</td>
                        <td>
                          <div class="badge badge-success">Completed</div>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </.card>
              </:content>
            </PageLayout.page_layout>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp data_table_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-bold text-base-content mb-2">DataTable Component</h2>
        <p class="text-base-content/70 mb-4">
          Feature-rich table with sorting, pagination, row actions, and responsive horizontal scroll on mobile.
        </p>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-3">Full-Featured Example</h3>
        <.card class="bg-base-100">
          <DataTable.data_table
            id="sample-transactions"
            rows={@transactions}
            sort_by={@sort_by}
            sort_dir={@sort_dir}
          >
            <:col :let={txn} label="ID" field={:id} sortable>
              <span class="font-mono text-sm">{txn.id}</span>
            </:col>
            <:col :let={txn} label="Customer" field={:customer} sortable>
              {txn.customer}
            </:col>
            <:col :let={txn} label="Amount" field={:amount} align={:right} sortable>
              <span class="font-semibold">${txn.amount}</span>
            </:col>
            <:col :let={txn} label="Status" field={:status} sortable>
              <div class={[
                "badge badge-sm",
                txn.status == "completed" && "badge-success",
                txn.status == "pending" && "badge-warning",
                txn.status == "failed" && "badge-error"
              ]}>
                {String.capitalize(txn.status)}
              </div>
            </:col>
            <:col :let={txn} label="Date" field={:date} sortable>
              <span class="text-sm text-base-content/70">{txn.date}</span>
            </:col>
            <:action :let={_txn}>
              <.button variant="ghost" size="sm">View</.button>
            </:action>
          </DataTable.data_table>

          <DataTable.pagination
            page={@current_page}
            total_pages={@total_pages}
            total_count={@total_count}
            per_page={10}
          />
        </.card>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-3">Empty State</h3>
        <.card class="bg-base-100">
          <DataTable.data_table id="empty-table" rows={[]}>
            <:col label="Column 1" field={:col1}>Content</:col>
            <:col label="Column 2" field={:col2}>Content</:col>
          </DataTable.data_table>
        </.card>
      </div>

      <div>
        <h3 class="text-lg font-semibold mb-3">Loading State</h3>
        <.card class="bg-base-100">
          <DataTable.data_table id="loading-table" rows={[]} loading>
            <:col label="Column 1" field={:col1}>Content</:col>
            <:col label="Column 2" field={:col2}>Content</:col>
          </DataTable.data_table>
        </.card>
      </div>

      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="size-5" />
        <div>
          <h4 class="font-semibold">Responsive Behavior</h4>
          <p class="text-sm">
            On mobile (&lt;768px): Table scrolls horizontally within its container.
            Pagination controls stack vertically on very small screens.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp focused_layout_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-bold text-base-content mb-2">FocusedLayout Component</h2>
        <p class="text-base-content/70 mb-4">
          Full-screen, distraction-free layouts for POS, terminals, and wizards. Minimal chrome, maximum focus.
        </p>
      </div>

      <div class="space-y-8">
        <%!-- Two Panel Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">Two-Panel Variant (60/40 Split)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box overflow-hidden h-96">
            <FocusedLayout.focused_layout
              title="Point of Sale"
              exit="#dashboard"
              variant={:two_panel}
            >
              <:left_panel>
                <div class="space-y-4">
                  <h3 class="text-lg font-semibold">Product Grid</h3>
                  <div class="grid grid-cols-2 gap-3">
                    <div
                      :for={i <- 1..6}
                      class="bg-base-200 rounded-box p-4 text-center cursor-pointer hover:bg-base-300"
                    >
                      <div class="avatar placeholder mb-2">
                        <div class="bg-neutral text-neutral-content rounded-box w-16 h-16">
                          <span>{i}</span>
                        </div>
                      </div>
                      <p class="font-semibold text-sm">Product {i}</p>
                      <p class="text-xs text-base-content/60">${20 + i * 5}</p>
                    </div>
                  </div>
                </div>
              </:left_panel>

              <:right_panel>
                <div class="space-y-4">
                  <h3 class="text-lg font-semibold">Cart Summary</h3>
                  <div class="space-y-2">
                    <div class="flex justify-between items-center p-3 bg-base-100 rounded-box">
                      <span>Product 1</span>
                      <span class="font-semibold">$25.00</span>
                    </div>
                    <div class="flex justify-between items-center p-3 bg-base-100 rounded-box">
                      <span>Product 2</span>
                      <span class="font-semibold">$30.00</span>
                    </div>
                  </div>
                  <div class="divider"></div>
                  <div class="flex justify-between items-center text-lg font-bold">
                    <span>Total</span>
                    <span>$55.00</span>
                  </div>
                  <.button variant="primary" class="w-full">Charge $55.00</.button>
                </div>
              </:right_panel>
            </FocusedLayout.focused_layout>
          </div>
        </div>

        <%!-- Centered Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">Centered Variant (Terminal/Single Focus)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box overflow-hidden h-96">
            <FocusedLayout.focused_layout
              title="Payment Terminal"
              exit="#dashboard"
              variant={:centered}
            >
              <:content>
                <.card class="bg-base-100 text-center">
                  <div class="space-y-6">
                    <.icon name="hero-credit-card" class="size-24 mx-auto text-primary" />
                    <h2 class="text-3xl font-bold">$55.00</h2>
                    <p class="text-base-content/70">Waiting for card...</p>
                    <div class="flex gap-3">
                      <.button variant="outline" class="flex-1">Cancel</.button>
                      <.button variant="primary" class="flex-1">Manual Entry</.button>
                    </div>
                  </div>
                </.card>
              </:content>
            </FocusedLayout.focused_layout>
          </div>
        </div>

        <%!-- Wizard Variant --%>
        <div>
          <h3 class="text-lg font-semibold mb-3">Wizard Variant (Multi-Step Process)</h3>
          <div class="border-2 border-dashed border-base-300 rounded-box overflow-hidden h-96">
            <FocusedLayout.focused_layout title="Checkout" exit="#cart" variant={:wizard}>
              <:progress>
                <div class="flex items-center justify-center gap-2">
                  <div class="badge badge-primary">1</div>
                  <div class="w-8 h-1 bg-primary"></div>
                  <div class="badge">2</div>
                  <div class="w-8 h-1 bg-base-300"></div>
                  <div class="badge">3</div>
                  <span class="ml-2 text-sm font-medium">Step 1 of 3: Shipping Information</span>
                </div>
              </:progress>

              <:content>
                <.card class="bg-base-100">
                  <h3 class="card-title mb-4">Shipping Address</h3>
                  <div class="space-y-4">
                    <.input type="text" name="name" label="Full Name" />
                    <.input type="text" name="address" label="Street Address" />
                    <div class="grid grid-cols-2 gap-4">
                      <.input type="text" name="city" label="City" />
                      <.input type="text" name="zip" label="ZIP Code" />
                    </div>
                  </div>
                  <div class="flex gap-3 mt-6">
                    <.button variant="outline" class="flex-1">Back</.button>
                    <.button variant="primary" class="flex-1">Continue</.button>
                  </div>
                </.card>
              </:content>
            </FocusedLayout.focused_layout>
          </div>
        </div>
      </div>

      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="size-5" />
        <div>
          <h4 class="font-semibold">Responsive Behavior</h4>
          <p class="text-sm">
            Two-panel layout stacks vertically on mobile (&lt;768px).
            Centered and wizard variants remain centered with max-width constraints.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp responsive_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h2 class="text-2xl font-bold text-base-content mb-2">Responsive Behavior Reference</h2>
        <p class="text-base-content/70 mb-4">
          All portal components follow a mobile-first responsive design approach.
        </p>
      </div>

      <.card class="bg-base-100">
        <h3 class="card-title mb-4">Breakpoint Reference</h3>
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Breakpoint</th>
                <th>Width</th>
                <th>Tailwind Class</th>
                <th>Typical Behavior</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="font-semibold">Mobile</td>
                <td>&lt;768px</td>
                <td><code class="badge badge-neutral">base</code></td>
                <td>Single column, stacked layouts</td>
              </tr>
              <tr>
                <td class="font-semibold">Tablet</td>
                <td>768px - 1023px</td>
                <td><code class="badge badge-neutral">md:</code></td>
                <td>2 columns for stats, sidebar collapses</td>
              </tr>
              <tr>
                <td class="font-semibold">Desktop</td>
                <td>≥1024px</td>
                <td><code class="badge badge-neutral">lg:</code></td>
                <td>Full layouts, sidebars visible</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.card>

      <.card class="bg-base-100">
        <h3 class="card-title mb-4">Component Responsive Classes</h3>
        <div class="space-y-4">
          <div>
            <h4 class="font-semibold mb-2">StatsRow</h4>
            <code class="text-sm bg-base-200 p-2 rounded block">
              grid grid-cols-2 md:grid-cols-4 gap-4
            </code>
            <p class="text-sm text-base-content/60 mt-1">
              2 columns on mobile → 4 columns on tablet+
            </p>
          </div>

          <div class="divider"></div>

          <div>
            <h4 class="font-semibold mb-2">PageLayout (list/detail variants)</h4>
            <code class="text-sm bg-base-200 p-2 rounded block">
              grid grid-cols-1 lg:grid-cols-3 gap-6
            </code>
            <p class="text-sm text-base-content/60 mt-1">
              Single column on mobile/tablet → 2/3+1/3 split on desktop
            </p>
          </div>

          <div class="divider"></div>

          <div>
            <h4 class="font-semibold mb-2">ActionSidebar</h4>
            <code class="text-sm bg-base-200 p-2 rounded block">w-72 sticky top-20</code>
            <p class="text-sm text-base-content/60 mt-1">
              Fixed width (288px), stacks below content on mobile
            </p>
          </div>

          <div class="divider"></div>

          <div>
            <h4 class="font-semibold mb-2">DataTable</h4>
            <code class="text-sm bg-base-200 p-2 rounded block">overflow-x-auto</code>
            <p class="text-sm text-base-content/60 mt-1">
              Horizontal scroll on mobile, full table on desktop
            </p>
          </div>

          <div class="divider"></div>

          <div>
            <h4 class="font-semibold mb-2">FocusedLayout (two_panel)</h4>
            <code class="text-sm bg-base-200 p-2 rounded block">
              flex w-full h-full (60/40 split desktop, stacked mobile)
            </code>
            <p class="text-sm text-base-content/60 mt-1">
              Side-by-side panels on desktop → stacked on mobile
            </p>
          </div>
        </div>
      </.card>

      <div class="alert alert-success">
        <.icon name="hero-check-circle" class="size-5" />
        <div>
          <h4 class="font-semibold">Testing Responsive Behavior</h4>
          <p class="text-sm">
            Resize your browser window or use Chrome DevTools device emulation to test responsive breakpoints.
            All components should adapt smoothly between mobile, tablet, and desktop views.
          </p>
        </div>
      </div>
    </div>
    """
  end

  # ===========================
  # Helper Functions
  # ===========================

  defp sample_transactions do
    [
      %{
        id: "TXN-1001",
        customer: "Alice Johnson",
        amount: "125.50",
        status: "completed",
        date: "2026-01-11"
      },
      %{
        id: "TXN-1002",
        customer: "Bob Smith",
        amount: "89.99",
        status: "completed",
        date: "2026-01-11"
      },
      %{
        id: "TXN-1003",
        customer: "Carol Williams",
        amount: "234.00",
        status: "pending",
        date: "2026-01-11"
      },
      %{
        id: "TXN-1004",
        customer: "David Brown",
        amount: "45.75",
        status: "failed",
        date: "2026-01-10"
      },
      %{
        id: "TXN-1005",
        customer: "Emma Davis",
        amount: "567.80",
        status: "completed",
        date: "2026-01-10"
      },
      %{
        id: "TXN-1006",
        customer: "Frank Miller",
        amount: "99.00",
        status: "completed",
        date: "2026-01-10"
      },
      %{
        id: "TXN-1007",
        customer: "Grace Wilson",
        amount: "178.25",
        status: "pending",
        date: "2026-01-10"
      },
      %{
        id: "TXN-1008",
        customer: "Henry Moore",
        amount: "320.00",
        status: "completed",
        date: "2026-01-09"
      },
      %{
        id: "TXN-1009",
        customer: "Iris Taylor",
        amount: "67.50",
        status: "completed",
        date: "2026-01-09"
      },
      %{
        id: "TXN-1010",
        customer: "Jack Anderson",
        amount: "412.90",
        status: "completed",
        date: "2026-01-09"
      }
    ]
  end

  defp toggle_direction(:asc), do: :desc
  defp toggle_direction(:desc), do: :asc
end
