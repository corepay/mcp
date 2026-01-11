defmodule McpWeb.Merchant.Payments.Transactions.IndexLive do
  @moduledoc """
  Merchant Transactions index page - displays transaction list with date range filter,
  status filter, and pagination.
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout
  import McpWeb.Portal.DataTable
  import McpWeb.Core.CoreComponents
  import McpWeb.Core.DataDisplay

  @impl true
  def mount(_params, _session, socket) do
    # Set default date range (last 30 days)
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -30)

    socket =
      socket
      |> assign(:all_transactions, get_sample_transactions())
      |> assign(:status_filter, "All")
      |> assign(:start_date, Date.to_iso8601(start_date))
      |> assign(:end_date, Date.to_iso8601(end_date))
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> apply_filters()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:table} title="Transactions">
      <:toolbar>
        <div class="flex items-center gap-4 flex-1 flex-wrap">
          <%!-- Date Range Filter --%>
          <form phx-change="date_range_changed" class="flex items-center gap-2">
            <.input
              type="date"
              name="start_date"
              value={@start_date}
              label="From"
              class="input-sm"
            />
            <.input type="date" name="end_date" value={@end_date} label="To" class="input-sm" />
          </form>
          <%!-- Status Filter --%>
          <form phx-change="filter_changed" class="flex items-center gap-2">
            <.input
              type="select"
              name="status"
              value={@status_filter}
              label="Status"
              options={["All", "Completed", "Pending", "Failed", "Refunded"]}
              class="select-sm"
            />
          </form>
          <%!-- Export Button --%>
          <.button variant="outline" size="sm" phx-click="export" class="ml-auto">
            <.icon name="hero-arrow-down-tray" class="size-4 mr-1" /> Export
          </.button>
        </div>
      </:toolbar>

      <:content>
        <.data_table id="transactions-table" rows={@transactions}>
          <:col :let={txn} label="Date" field={:created_at}>
            <div class="flex flex-col">
              <span class="font-medium">
                {format_date(txn.created_at)}
              </span>
              <span class="text-xs text-base-content/60">
                {format_time(txn.created_at)}
              </span>
            </div>
          </:col>

          <:col :let={txn} label="Reference" field={:reference}>
            <span class="font-mono text-sm">{txn.reference}</span>
          </:col>

          <:col :let={txn} label="Customer" field={:customer_name}>
            <div class="flex flex-col">
              <span class="font-medium">{txn.customer_name}</span>
              <span class="text-xs text-base-content/60">
                {txn.payment_method}
              </span>
            </div>
          </:col>

          <:col :let={txn} label="Amount" field={:amount} align={:right}>
            <span class="font-semibold">
              {format_money(txn.amount)}
            </span>
          </:col>

          <:col :let={txn} label="Status" field={:status}>
            <.badge variant={status_badge_variant(txn.status)}>
              {format_status(txn.status)}
            </.badge>
          </:col>

          <:action :let={txn}>
            <a
              href={"/app/payments/transactions/#{txn.id}"}
              class="btn btn-ghost btn-sm"
              phx-click="row-click"
              phx-value-id={"row-#{txn.id}"}
            >
              View
            </a>
          </:action>

          <:empty>
            <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
              <.icon name="hero-banknotes" class="size-12 mb-2" />
              <p>No transactions found</p>
              <p class="text-sm mt-1">Try adjusting your filters</p>
            </div>
          </:empty>
        </.data_table>

        <.pagination
          page={@page}
          total_pages={@total_pages}
          total_count={@total_count}
          per_page={@per_page}
        />
      </:content>
    </.page_layout>
    """
  end

  @impl true
  def handle_event("filter_changed", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:page, 1)
      |> apply_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "date_range_changed",
        %{"start_date" => start_date, "end_date" => end_date},
        socket
      ) do
    # Only update if both dates are provided
    socket =
      if start_date != "" and end_date != "" do
        socket
        |> assign(:start_date, start_date)
        |> assign(:end_date, end_date)
        |> assign(:page, 1)
        |> apply_filters()
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("page-change", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    # Clamp page between 1 and total_pages
    page = max(1, min(page, socket.assigns.total_pages))

    socket =
      socket
      |> assign(:page, page)
      |> paginate_transactions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("export", _params, socket) do
    # Placeholder for CSV export functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("row-click", %{"id" => _row_id}, socket) do
    # Row click navigation is handled by the anchor tag
    {:noreply, socket}
  end

  # Private helper functions

  defp apply_filters(socket) do
    filtered =
      socket.assigns.all_transactions
      |> filter_by_status(socket.assigns.status_filter)
      |> filter_by_date_range(socket.assigns.start_date, socket.assigns.end_date)

    total_count = length(filtered)
    total_pages = max(1, ceil(total_count / socket.assigns.per_page))

    socket
    |> assign(:filtered_transactions, filtered)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> paginate_transactions()
  end

  defp paginate_transactions(socket) do
    page = socket.assigns.page
    per_page = socket.assigns.per_page
    offset = (page - 1) * per_page

    transactions =
      socket.assigns.filtered_transactions
      |> Enum.drop(offset)
      |> Enum.take(per_page)

    assign(socket, :transactions, transactions)
  end

  defp filter_by_status(transactions, status) when status in ["all", "All"], do: transactions

  defp filter_by_status(transactions, status) do
    status_atom = status |> String.downcase() |> String.to_existing_atom()
    Enum.filter(transactions, fn txn -> txn.status == status_atom end)
  end

  defp filter_by_date_range(transactions, start_date_str, end_date_str) do
    start_date = Date.from_iso8601!(start_date_str)
    end_date = Date.from_iso8601!(end_date_str)

    Enum.filter(transactions, fn txn ->
      txn_date = DateTime.to_date(txn.created_at)

      Date.compare(txn_date, start_date) in [:gt, :eq] and
        Date.compare(txn_date, end_date) in [:lt, :eq]
    end)
  end

  defp get_sample_transactions do
    [
      %{
        id: "txn_1",
        reference: "TXN-2026-0001",
        customer_name: "John Doe",
        customer_id: "cust_1",
        amount: Decimal.new("125.00"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-10 14:30:00Z]
      },
      %{
        id: "txn_2",
        reference: "TXN-2026-0002",
        customer_name: "Jane Smith",
        customer_id: "cust_2",
        amount: Decimal.new("89.99"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-10 13:15:00Z]
      },
      %{
        id: "txn_3",
        reference: "TXN-2026-0003",
        customer_name: "Bob Johnson",
        customer_id: "cust_3",
        amount: Decimal.new("250.00"),
        status: :pending,
        payment_method: "bank_transfer",
        created_at: ~U[2026-01-10 11:45:00Z]
      },
      %{
        id: "txn_4",
        reference: "TXN-2026-0004",
        customer_name: "Alice Williams",
        customer_id: "cust_4",
        amount: Decimal.new("45.50"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-09 16:20:00Z]
      },
      %{
        id: "txn_5",
        reference: "TXN-2026-0005",
        customer_name: "Charlie Brown",
        customer_id: "cust_5",
        amount: Decimal.new("175.00"),
        status: :failed,
        payment_method: "card",
        created_at: ~U[2026-01-09 14:10:00Z]
      },
      %{
        id: "txn_6",
        reference: "TXN-2026-0006",
        customer_name: "Diana Prince",
        customer_id: "cust_6",
        amount: Decimal.new("320.00"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-08 10:30:00Z]
      },
      %{
        id: "txn_7",
        reference: "TXN-2026-0007",
        customer_name: "Edward Norton",
        customer_id: "cust_7",
        amount: Decimal.new("99.99"),
        status: :refunded,
        payment_method: "card",
        created_at: ~U[2026-01-08 09:15:00Z]
      },
      %{
        id: "txn_8",
        reference: "TXN-2026-0008",
        customer_name: "Fiona Green",
        customer_id: "cust_8",
        amount: Decimal.new("150.00"),
        status: :completed,
        payment_method: "cash",
        created_at: ~U[2026-01-07 15:45:00Z]
      },
      %{
        id: "txn_9",
        reference: "TXN-2026-0009",
        customer_name: "George Miller",
        customer_id: "cust_9",
        amount: Decimal.new("220.00"),
        status: :pending,
        payment_method: "bank_transfer",
        created_at: ~U[2026-01-07 12:00:00Z]
      },
      %{
        id: "txn_10",
        reference: "TXN-2026-0010",
        customer_name: "Hannah Lee",
        customer_id: "cust_10",
        amount: Decimal.new("85.00"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-06 17:30:00Z]
      },
      %{
        id: "txn_11",
        reference: "TXN-2026-0011",
        customer_name: "Ivan Petrov",
        customer_id: "cust_11",
        amount: Decimal.new("195.50"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-06 14:20:00Z]
      },
      %{
        id: "txn_12",
        reference: "TXN-2026-0012",
        customer_name: "Julia Roberts",
        customer_id: "cust_12",
        amount: Decimal.new("75.00"),
        status: :failed,
        payment_method: "card",
        created_at: ~U[2026-01-05 11:15:00Z]
      },
      %{
        id: "txn_13",
        reference: "TXN-2026-0013",
        customer_name: "Kevin Hart",
        customer_id: "cust_13",
        amount: Decimal.new("340.00"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-05 09:45:00Z]
      },
      %{
        id: "txn_14",
        reference: "TXN-2026-0014",
        customer_name: "Laura Palmer",
        customer_id: "cust_14",
        amount: Decimal.new("125.00"),
        status: :pending,
        payment_method: "bank_transfer",
        created_at: ~U[2026-01-04 16:10:00Z]
      },
      %{
        id: "txn_15",
        reference: "TXN-2026-0015",
        customer_name: "Michael Scott",
        customer_id: "cust_15",
        amount: Decimal.new("210.00"),
        status: :completed,
        payment_method: "card",
        created_at: ~U[2026-01-04 13:30:00Z]
      },
      %{
        id: "txn_16",
        reference: "TXN-2026-0016",
        customer_name: "Nancy Drew",
        customer_id: "cust_16",
        amount: Decimal.new("160.00"),
        status: :completed,
        payment_method: "cash",
        created_at: ~U[2025-12-28 10:20:00Z]
      },
      %{
        id: "txn_17",
        reference: "TXN-2025-0235",
        customer_name: "Oliver Twist",
        customer_id: "cust_17",
        amount: Decimal.new("95.00"),
        status: :refunded,
        payment_method: "card",
        created_at: ~U[2025-12-25 14:00:00Z]
      }
    ]
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp format_money(decimal) do
    "$#{Decimal.to_string(decimal)}"
  end

  defp format_status(:completed), do: "Completed"
  defp format_status(:pending), do: "Pending"
  defp format_status(:failed), do: "Failed"
  defp format_status(:refunded), do: "Refunded"

  defp status_badge_variant(:completed), do: "success"
  defp status_badge_variant(:pending), do: "warning"
  defp status_badge_variant(:failed), do: "error"
  defp status_badge_variant(:refunded), do: "info"
end
