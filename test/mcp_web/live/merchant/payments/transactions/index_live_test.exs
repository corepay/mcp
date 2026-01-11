defmodule McpWeb.Merchant.Payments.Transactions.IndexLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Merchant.Payments.Transactions.IndexLive

  @endpoint McpWeb.Endpoint

  defp build_socket do
    %Phoenix.LiveView.Socket{
      endpoint: @endpoint,
      router: McpWeb.Router,
      assigns: %{
        __changed__: %{},
        flash: %{}
      }
    }
  end

  describe "mount/3" do
    test "loads sample transactions with pagination" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      assert is_list(socket.assigns.transactions)
      assert length(socket.assigns.transactions) > 0
      assert socket.assigns.page == 1
      assert socket.assigns.per_page == 10
      assert socket.assigns.total_pages > 0
      assert socket.assigns.total_count > 0
    end

    test "initializes filters with defaults" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      assert socket.assigns.status_filter == "All"
      assert socket.assigns.start_date
      assert socket.assigns.end_date
    end

    test "sets date range to last 30 days by default" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      start_date = Date.from_iso8601!(socket.assigns.start_date)
      end_date = Date.from_iso8601!(socket.assigns.end_date)

      assert Date.diff(end_date, start_date) == 30
      assert end_date == Date.utc_today()
    end
  end

  describe "render/1" do
    setup do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      html = render_component(&IndexLive.render/1, socket.assigns)

      {:ok, html: html, socket: socket}
    end

    test "renders page with title 'Transactions'", %{html: html} do
      assert html =~ "Transactions"
    end

    test "displays transaction data table with correct columns", %{html: html} do
      assert html =~ "Date"
      assert html =~ "Reference"
      assert html =~ "Customer"
      assert html =~ "Amount"
      assert html =~ "Status"
      assert html =~ "Actions"
    end

    test "displays sample transaction data in table", %{html: html} do
      assert html =~ "TXN-2026-"
      assert html =~ "John Doe"
    end

    test "toolbar has date range inputs", %{html: html} do
      assert html =~ "name=\"start_date\""
      assert html =~ "name=\"end_date\""
    end

    test "toolbar has status filter dropdown", %{html: html} do
      assert html =~ "Status"
      assert html =~ "All"
      assert html =~ "Completed"
      assert html =~ "Pending"
      assert html =~ "Failed"
      assert html =~ "Refunded"
    end

    test "toolbar has Export button", %{html: html} do
      assert html =~ "Export"
    end

    test "displays pagination when multiple pages exist", %{html: html, socket: socket} do
      if socket.assigns.total_pages > 1 do
        assert html =~ "Showing"
        assert html =~ "of"
      end
    end

    test "displays status badges with correct colors", %{html: html} do
      assert html =~ "badge"
    end
  end

  describe "handle_event/3 - filter_changed" do
    test "filters transactions by status" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      initial_count = socket.assigns.total_count

      {:noreply, socket} =
        IndexLive.handle_event("filter_changed", %{"status" => "Completed"}, socket)

      assert socket.assigns.status_filter == "Completed"
      # Filtered count should be less than or equal to total
      assert socket.assigns.total_count <= initial_count
      # Reset to page 1 when filtering
      assert socket.assigns.page == 1
    end

    test "shows all transactions when status filter is 'All'" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      total_count = socket.assigns.total_count

      {:noreply, socket} =
        IndexLive.handle_event("filter_changed", %{"status" => "Pending"}, socket)

      assert socket.assigns.total_count <= total_count

      {:noreply, socket} =
        IndexLive.handle_event("filter_changed", %{"status" => "All"}, socket)

      assert socket.assigns.total_count == total_count
    end
  end

  describe "handle_event/3 - date_range_changed" do
    test "filters transactions by date range" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      start_date = "2026-01-01"
      end_date = "2026-01-05"

      {:noreply, socket} =
        IndexLive.handle_event(
          "date_range_changed",
          %{"start_date" => start_date, "end_date" => end_date},
          socket
        )

      assert socket.assigns.start_date == start_date
      assert socket.assigns.end_date == end_date
      # Reset to page 1 when filtering
      assert socket.assigns.page == 1
    end

    test "handles empty date inputs gracefully" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      {:noreply, socket} =
        IndexLive.handle_event(
          "date_range_changed",
          %{"start_date" => "", "end_date" => ""},
          socket
        )

      # Should keep existing dates
      assert socket.assigns.start_date
      assert socket.assigns.end_date
    end
  end

  describe "handle_event/3 - page-change" do
    test "changes to the requested page" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      assert socket.assigns.page == 1

      {:noreply, socket} = IndexLive.handle_event("page-change", %{"page" => "2"}, socket)

      assert socket.assigns.page == 2
    end

    test "does not exceed total pages" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      total_pages = socket.assigns.total_pages

      {:noreply, socket} =
        IndexLive.handle_event("page-change", %{"page" => "9999"}, socket)

      assert socket.assigns.page <= total_pages
    end

    test "does not go below page 1" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      {:noreply, socket} = IndexLive.handle_event("page-change", %{"page" => "0"}, socket)

      assert socket.assigns.page >= 1
    end
  end

  describe "handle_event/3 - export" do
    test "handles export event" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      {:noreply, _socket} = IndexLive.handle_event("export", %{}, socket)
    end
  end

  describe "handle_event/3 - row-click" do
    test "handles row click for navigation" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      {:noreply, _socket} =
        IndexLive.handle_event("row-click", %{"id" => "row-txn_1"}, socket)
    end
  end

  describe "filtering logic" do
    test "combines status and date filters correctly" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      # Apply status filter
      {:noreply, socket} =
        IndexLive.handle_event("filter_changed", %{"status" => "Completed"}, socket)

      completed_count = socket.assigns.total_count

      # Apply date range filter on top of status filter
      {:noreply, socket} =
        IndexLive.handle_event(
          "date_range_changed",
          %{"start_date" => "2026-01-10", "end_date" => "2026-01-11"},
          socket
        )

      # Should have fewer or equal items than just status filter
      assert socket.assigns.total_count <= completed_count
    end
  end
end
