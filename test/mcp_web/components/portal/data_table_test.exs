# test/mcp_web/components/portal/data_table_test.exs
defmodule McpWeb.Portal.DataTableTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portal.DataTable

  # Sample transaction data for testing
  defp sample_transactions do
    [
      %{
        id: "txn-001",
        reference_id: "REF-ABC123",
        customer_name: "John Doe",
        amount: 9999,
        status: :completed
      },
      %{
        id: "txn-002",
        reference_id: "REF-DEF456",
        customer_name: nil,
        amount: 5000,
        status: :pending
      },
      %{
        id: "txn-003",
        reference_id: "REF-GHI789",
        customer_name: "Jane Smith",
        amount: 15_000,
        status: :failed
      }
    ]
  end

  describe "data_table/1 - basic rendering" do
    test "renders table container with proper structure" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should render a table element
      assert html =~ "<table"
      assert html =~ "</table>"
      # Should have the id attribute
      assert html =~ ~r/id="test-table"/
      # Should use DaisyUI table class
      assert html =~ "table"
    end

    test "renders column headers with labels" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
          <:col :let={txn} label="Customer" field={:customer}>
            {txn.customer_name || "Guest"}
          </:col>
          <:col :let={txn} label="Amount" field={:amount}>
            {txn.amount}
          </:col>
        </DataTable.data_table>
        """)

      # Should render all column headers
      assert html =~ "<thead"
      assert html =~ "ID"
      assert html =~ "Customer"
      assert html =~ "Amount"
    end

    test "renders rows with column content" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="Reference" field={:reference_id}>
            {txn.reference_id}
          </:col>
          <:col :let={txn} label="Customer" field={:customer}>
            {txn.customer_name || "Guest"}
          </:col>
        </DataTable.data_table>
        """)

      # Should render transaction data
      assert html =~ "REF-ABC123"
      assert html =~ "REF-DEF456"
      assert html =~ "REF-GHI789"
      assert html =~ "John Doe"
      assert html =~ "Guest"
      assert html =~ "Jane Smith"
    end
  end

  describe "data_table/1 - column alignment" do
    test "applies left alignment by default" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Default should be left aligned (no explicit class or text-left)
      # The column cell should NOT have text-right or text-center
      refute html =~ ~r/<td[^>]*class="[^"]*text-right[^"]*"/
      refute html =~ ~r/<td[^>]*class="[^"]*text-center[^"]*"/
    end

    test "applies right alignment when specified" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="Amount" field={:amount} align={:right}>
            {txn.amount}
          </:col>
        </DataTable.data_table>
        """)

      # Should have right-aligned cells
      assert html =~ "text-right"
    end

    test "applies center alignment when specified" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="Status" field={:status} align={:center}>
            {txn.status}
          </:col>
        </DataTable.data_table>
        """)

      # Should have center-aligned cells
      assert html =~ "text-center"
    end
  end

  describe "data_table/1 - sortable columns" do
    test "renders sortable header with click handler" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id} sortable>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Sortable columns should have cursor pointer and phx-click
      assert html =~ "cursor-pointer"
      assert html =~ "phx-click"
    end

    test "non-sortable columns do not have click handler" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Non-sortable columns should not have sort-related attributes on the th
      # The header should not have phx-click for sorting
      refute html =~ ~r/<th[^>]*phx-click="sort"[^>]*>.*ID/s
    end

    test "shows sort indicator for current sort column" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows} sort_by={:id} sort_dir={:asc}>
          <:col :let={txn} label="ID" field={:id} sortable>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should show ascending sort indicator
      assert html =~ "hero-chevron-up" or html =~ "hero-arrow-up"
    end

    test "shows descending sort indicator" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows} sort_by={:id} sort_dir={:desc}>
          <:col :let={txn} label="ID" field={:id} sortable>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should show descending sort indicator
      assert html =~ "hero-chevron-down" or html =~ "hero-arrow-down"
    end
  end

  describe "data_table/1 - row click navigation" do
    test "renders row click handler when provided" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table
          id="test-table"
          rows={@rows}
          row_click={fn txn -> "navigate-to-#{txn.id}" end}
        >
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Rows should be clickable
      assert html =~ "cursor-pointer"
      assert html =~ "phx-click"
    end

    test "rows are not clickable when row_click not provided" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Rows should not have row-level click handlers
      refute html =~ ~r/<tr[^>]*phx-click="row-click"/
    end
  end

  describe "data_table/1 - streaming support" do
    test "renders with phx-update stream when stream is true" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows} stream>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should have phx-update="stream" on tbody
      assert html =~ ~r/phx-update="stream"/
    end

    test "uses row_id function for stream item IDs" do
      assigns = %{
        rows: [
          {"txn-stream-001", %{id: "001", reference_id: "REF-001"}},
          {"txn-stream-002", %{id: "002", reference_id: "REF-002"}}
        ]
      }

      html =
        rendered_to_string(~H"""
        <DataTable.data_table
          id="test-table"
          rows={@rows}
          stream
          row_id={fn {id, _row} -> id end}
        >
          <:col :let={{_id, txn}} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should use the row_id for tr id
      assert html =~ ~r/id="txn-stream-001"/
      assert html =~ ~r/id="txn-stream-002"/
    end
  end

  describe "data_table/1 - empty state" do
    test "renders empty state when no rows" do
      assigns = %{rows: []}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should show empty state message
      assert html =~ "No data" or html =~ "No results" or html =~ "empty"
    end

    test "renders custom empty state when provided" do
      assigns = %{rows: []}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
          <:empty>
            <div id="custom-empty">No transactions found</div>
          </:empty>
        </DataTable.data_table>
        """)

      # Should show custom empty state
      assert html =~ "custom-empty"
      assert html =~ "No transactions found"
    end
  end

  describe "data_table/1 - loading state" do
    test "renders loading indicator when loading is true" do
      assigns = %{rows: []}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows} loading>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should show loading indicator
      assert html =~ "loading" or html =~ "skeleton" or html =~ "spinner"
    end
  end

  describe "data_table/1 - action slot" do
    test "renders action slot for each row" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
          <:action :let={txn}>
            <button id={"action-#{txn.id}"}>View</button>
          </:action>
        </DataTable.data_table>
        """)

      # Should render action buttons
      assert html =~ "action-txn-001"
      assert html =~ "action-txn-002"
      assert html =~ "action-txn-003"
      assert html =~ "View"
    end

    test "renders Actions header when action slot is used" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
          <:action :let={_txn}>
            <button>Edit</button>
          </:action>
        </DataTable.data_table>
        """)

      # Should have Actions header
      assert html =~ "Actions" or html =~ "actions"
    end
  end

  describe "data_table/1 - bulk selection" do
    test "renders checkbox column when selectable is true" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows} selectable>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should have checkbox column
      assert html =~ ~r/<input[^>]*type="checkbox"/
    end

    test "renders select-all checkbox in header" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows} selectable>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should have select-all checkbox in thead
      assert html =~ ~r/<thead[^>]*>.*<input[^>]*type="checkbox"/s
    end

    test "does not render checkboxes when selectable is false" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should not have checkboxes
      refute html =~ ~r/<input[^>]*type="checkbox"/
    end
  end

  describe "data_table/1 - row hover styling" do
    test "applies hover styling to rows" do
      assigns = %{rows: sample_transactions()}

      html =
        rendered_to_string(~H"""
        <DataTable.data_table id="test-table" rows={@rows}>
          <:col :let={txn} label="ID" field={:id}>
            {txn.reference_id}
          </:col>
        </DataTable.data_table>
        """)

      # Should have hover styling on rows
      assert html =~ "hover:"
    end
  end
end
