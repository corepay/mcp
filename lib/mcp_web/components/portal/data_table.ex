defmodule McpWeb.Portal.DataTable do
  @moduledoc """
  Data table component for portal pages.

  A feature-rich table component optimized for displaying paginated data with
  support for sorting, streaming, row actions, and bulk selection.

  ## Features

  - Sortable columns with visual indicators
  - Column alignment (left, center, right)
  - Row click navigation
  - LiveView streaming support
  - Empty and loading states
  - Row action slots
  - Bulk selection with checkboxes

  ## Examples

      # Basic table with columns
      <.data_table id="transactions-table" rows={@transactions}>
        <:col :let={txn} label="ID" field={:id}>
          <span class="font-mono text-sm">{txn.reference_id}</span>
        </:col>
        <:col :let={txn} label="Customer" field={:customer}>
          {txn.customer_name || "Guest"}
        </:col>
        <:col :let={txn} label="Amount" field={:amount} align={:right}>
          <.money value={txn.amount} />
        </:col>
      </.data_table>

      # With streaming and row click
      <.data_table
        id="transactions-table"
        rows={@streams.transactions}
        stream
        row_click={fn txn -> JS.navigate(~p"/payments/transactions/\#{txn.id}") end}
      >
        ...
      </.data_table>
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a data table with sortable columns and row actions.

  ## Attributes

  - `id` - Required table identifier
  - `rows` - List or stream of data rows
  - `row_click` - Optional function to handle row clicks
  - `row_id` - Function to extract row ID (for streams)
  - `stream` - Boolean to enable streaming mode
  - `loading` - Boolean to show loading state
  - `selectable` - Boolean to enable bulk selection checkboxes
  - `sort_by` - Current sort field
  - `sort_dir` - Current sort direction (:asc or :desc)

  ## Slots

  - `:col` - Column definition with label, field, align, sortable attrs
  - `:action` - Row action dropdown slot
  - `:empty` - Custom empty state content
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_click, :any, default: nil
  attr :row_id, :any, default: nil
  attr :stream, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :selectable, :boolean, default: false
  attr :sort_by, :atom, default: nil
  attr :sort_dir, :atom, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :field, :atom
    attr :align, :atom
    attr :sortable, :boolean
  end

  slot :action

  slot :empty

  def data_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <%= if @loading do %>
        <div class="flex items-center justify-center py-8">
          <span class="loading loading-spinner loading-lg"></span>
        </div>
      <% else %>
        <%= if @rows == [] do %>
          <%= if @empty != [] do %>
            {render_slot(@empty)}
          <% else %>
            <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
              <.icon name="hero-inbox" class="size-12 mb-2" />
              <p>No data available</p>
            </div>
          <% end %>
        <% else %>
          <table id={@id} class="table">
            <thead>
              <tr>
                <th :if={@selectable} class="w-12">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    phx-click="select-all"
                    aria-label="Select all rows"
                  />
                </th>
                <th
                  :for={col <- @col}
                  class={header_classes(col)}
                  phx-click={col[:sortable] && "sort"}
                  phx-value-field={col[:sortable] && col[:field]}
                >
                  <div class="flex items-center gap-1">
                    <span>{col[:label]}</span>
                    <.sort_indicator
                      :if={col[:sortable]}
                      field={col[:field]}
                      sort_by={@sort_by}
                      sort_dir={@sort_dir}
                    />
                  </div>
                </th>
                <th :if={@action != []}>Actions</th>
              </tr>
            </thead>
            <tbody id={"#{@id}-body"} phx-update={@stream && "stream"}>
              <%= for row <- @rows do %>
                <% {row_dom_id, row_data} = extract_row_data(row, @row_id, @stream) %>
                <tr
                  id={row_dom_id}
                  class={row_classes(@row_click)}
                  phx-click={@row_click && "row-click"}
                  phx-value-id={@row_click && row_dom_id}
                >
                  <td :if={@selectable} class="w-12">
                    <input
                      type="checkbox"
                      class="checkbox checkbox-sm"
                      phx-click="select-row"
                      phx-value-id={row_dom_id}
                      aria-label="Select row"
                    />
                  </td>
                  <td :for={col <- @col} class={cell_classes(col)}>
                    {render_slot(col, row_data)}
                  </td>
                  <td :if={@action != []}>
                    {render_slot(@action, row_data)}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp extract_row_data(row, row_id_fn, true = _stream) when is_function(row_id_fn) do
    {row_id_fn.(row), row}
  end

  defp extract_row_data({id, data}, _row_id_fn, true = _stream) do
    {id, data}
  end

  defp extract_row_data(row, _row_id_fn, true = _stream) do
    # Stream mode with regular rows (not tuples) - extract ID from row
    id = extract_id_from_row(row)
    {id, row}
  end

  defp extract_row_data(row, _row_id_fn, false = _stream) do
    id = extract_id_from_row(row)
    {id, row}
  end

  defp extract_row_data(row, _row_id_fn, nil = _stream) do
    extract_row_data(row, nil, false)
  end

  defp extract_id_from_row(row) do
    cond do
      is_map(row) and Map.has_key?(row, :id) -> "row-#{row.id}"
      is_map(row) and Map.has_key?(row, "id") -> "row-#{row["id"]}"
      true -> nil
    end
  end

  defp header_classes(col) do
    base = [
      col[:sortable] && "cursor-pointer hover:bg-base-200 transition-colors"
    ]

    alignment =
      case col[:align] do
        :right -> "text-right"
        :center -> "text-center"
        _ -> nil
      end

    [base, alignment]
  end

  defp cell_classes(col) do
    case col[:align] do
      :right -> "text-right"
      :center -> "text-center"
      _ -> nil
    end
  end

  defp row_classes(nil), do: "hover:bg-base-200"

  defp row_classes(_row_click) do
    "hover:bg-base-200 cursor-pointer transition-colors"
  end

  attr :field, :atom, required: true
  attr :sort_by, :atom, default: nil
  attr :sort_dir, :atom, default: nil

  defp sort_indicator(assigns) do
    ~H"""
    <%= if @field == @sort_by do %>
      <%= if @sort_dir == :asc do %>
        <.icon name="hero-chevron-up" class="size-4" />
      <% else %>
        <.icon name="hero-chevron-down" class="size-4" />
      <% end %>
    <% else %>
      <.icon name="hero-chevron-up-down" class="size-4 opacity-30" />
    <% end %>
    """
  end

  @doc """
  Renders a pagination component.

  ## Attributes

  - `page` - Current page number (1-indexed)
  - `total_pages` - Total number of pages
  - `total_count` - Total number of items
  - `per_page` - Items per page (optional, for display)
  - `on_page_change` - Event name for page changes (default: "page-change")

  ## Examples

      <.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />

      <.pagination
        page={@page}
        total_pages={@total_pages}
        total_count={@total_count}
        on_page_change="custom-page-change"
      />
  """
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :total_count, :integer, required: true
  attr :per_page, :integer, default: 10
  attr :on_page_change, :string, default: "page-change"

  def pagination(assigns) do
    assigns = assign(assigns, :pages, build_page_list(assigns.page, assigns.total_pages))

    ~H"""
    <%= if @total_pages > 1 do %>
      <div class="flex items-center justify-between mt-4">
        <div class="text-sm text-base-content/70">
          <span>
            Showing {item_range_start(@page, @per_page)}-{item_range_end(
              @page,
              @per_page,
              @total_count
            )} of {@total_count}
          </span>
        </div>
        <div class="join" role="navigation" aria-label="Pagination">
          <%!-- Previous button --%>
          <button
            class={["join-item btn btn-sm", @page <= 1 && "btn-disabled"]}
            phx-click={@on_page_change}
            phx-value-page={@page - 1}
            disabled={@page <= 1}
            aria-label="Previous page"
          >
            <.icon name="hero-chevron-left" class="size-4" />
          </button>

          <%!-- Page numbers --%>
          <%= for page_item <- @pages do %>
            <%= case page_item do %>
              <% :ellipsis -> %>
                <span class="join-item btn btn-sm btn-disabled">...</span>
              <% page_num -> %>
                <button
                  class={[
                    "join-item btn btn-sm",
                    page_num == @page && "btn-active btn-primary"
                  ]}
                  phx-click={@on_page_change}
                  phx-value-page={page_num}
                  aria-label={"Page #{page_num}"}
                  aria-current={page_num == @page && "page"}
                >
                  {page_num}
                </button>
            <% end %>
          <% end %>

          <%!-- Next button --%>
          <button
            class={["join-item btn btn-sm", @page >= @total_pages && "btn-disabled"]}
            phx-click={@on_page_change}
            phx-value-page={@page + 1}
            disabled={@page >= @total_pages}
            aria-label="Next page"
          >
            <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>
      </div>
    <% else %>
      <div class="flex items-center justify-center mt-4 text-sm text-base-content/70">
        <span>Showing {@total_count} items</span>
      </div>
    <% end %>
    """
  end

  defp build_page_list(_current_page, total_pages) when total_pages <= 7 do
    Enum.to_list(1..total_pages)
  end

  defp build_page_list(current_page, total_pages) do
    # Show: 1, ..., current-1, current, current+1, ..., total
    cond do
      current_page <= 4 ->
        Enum.to_list(1..5) ++ [:ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++
          [:ellipsis, total_pages]
    end
  end

  defp item_range_start(page, per_page) do
    (page - 1) * per_page + 1
  end

  defp item_range_end(page, per_page, total_count) do
    min(page * per_page, total_count)
  end
end
