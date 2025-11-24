defmodule McpWeb.WidgetComponent do
  @moduledoc """
  LiveComponent for rendering different types of analytics widgets.

  Supports various widget types including number cards, charts, tables,
  and other visualization components with real-time updates.
  """

  use Phoenix.LiveComponent
  import Phoenix.HTML

  @impl true
  def update(%{widget: widget, data: data} = _assigns, socket) do
    socket =
      socket
      |> assign(:widget, widget)
      |> assign(:data, data)
      |> assign(:loading, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{widget: widget, loading: true} = _assigns, socket) do
    socket =
      socket
      |> assign(:widget, widget)
      |> assign(:loading, true)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{widget: widget, error: error} = _assigns, socket) do
    socket =
      socket
      |> assign(:widget, widget)
      |> assign(:loading, false)
      |> assign(:error, error)

    {:ok, socket}
  end

  @impl true
  def render(%{widget: _widget} = assigns) do
    ~H"""
    <div
      class={[
        "widget bg-white rounded-lg shadow-sm border border-gray-200 p-4",
        "transition-all duration-200 hover:shadow-md",
        @widget.is_visible || "hidden"
      ]}
      style={"grid-column: span #{@widget.position["w"] || 1}; grid-row: span #{@widget.position["h"] || 1};"}
      id={"widget-#{@widget.id}"}
      phx-hook="WidgetHook"
      data-widget-id={@widget.id}
      data-widget-type={@widget.widget_type}
    >
      <div class="flex items-center justify-between mb-3">
        <h3 class="font-medium text-gray-900 truncate">
          {@widget.title}
        </h3>
        <div class="flex items-center space-x-2">
          <%= if @loading do %>
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
          <% end %>
          <div class="relative group">
            <button class="text-gray-400 hover:text-gray-600">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
              </svg>
            </button>
            <div class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg z-10 hidden group-hover:block">
              <div class="py-1">
                <button
                  phx-click="refresh_widget"
                  phx-value-widget-id={@widget.id}
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 w-full text-left"
                >
                  Refresh
                </button>
                <button
                  phx-click="drill_down"
                  phx-value-widget-id={@widget.id}
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 w-full text-left"
                >
                  Drill Down
                </button>
                <button
                  phx-click="export_widget"
                  phx-value-widget-id={@widget.id}
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 w-full text-left"
                >
                  Export
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="widget-content">
        <%= if @error do %>
          <div class="flex items-center justify-center h-32 text-red-600">
            <div class="text-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-12 w-12 mx-auto mb-2 text-gray-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
              <p class="text-sm">Failed to load data</p>
            </div>
          </div>
        <% else %>
          {render_widget_content(@widget.widget_type, @data, @widget.visualization_config)}
        <% end %>
      </div>
    </div>
    """
  end

  defp render_widget_content("number_card", data, config) do
    value = Map.get(data, :current_value, 0)
    trend = Map.get(data, :trend, "stable")
    trend_color = trend_color(trend)
    trend_icon = trend_icon(trend)

    assigns = %{
      value: value,
      trend: trend,
      trend_color: trend_color,
      trend_icon: trend_icon,
      config: config,
      data: data
    }

    ~H"""
    <div class="text-center">
      <div class="text-3xl font-bold text-gray-900 mb-2">
        {format_number(@value, @config["format"] || "number")}
      </div>
      <div class="flex items-center justify-center space-x-1 text-sm #{@trend_color}">
        {raw(@trend_icon)}
        <span>{@trend}</span>
      </div>
      <div class="text-xs text-gray-500 mt-1">
        {get_time_ago(@data[:timestamp])}
      </div>
    </div>
    """
  end

  defp render_widget_content("line_chart", data, config) do
    assigns = %{data: data, config: config}

    ~H"""
    <div
      id={"widget-#{@config["chart_id"] || "line-chart"}"}
      class="h-64"
      phx-hook="LineChartHook"
      data-chart-data={Jason.encode!(@data)}
      data-config={Jason.encode!(@config)}
    >
      <canvas id={"chart-#{@config["chart_id"] || "line-chart"}"}></canvas>
    </div>
    """
  end

  defp render_widget_content("bar_chart", data, config) do
    assigns = %{data: data, config: config}

    ~H"""
    <div
      id={"widget-#{@config["chart_id"] || "bar-chart"}"}
      class="h-64"
      phx-hook="BarChartHook"
      data-chart-data={Jason.encode!(@data)}
      data-config={Jason.encode!(@config)}
    >
      <canvas id={"chart-#{@config["chart_id"] || "bar-chart"}"}></canvas>
    </div>
    """
  end

  defp render_widget_content("pie_chart", data, config) do
    assigns = %{data: data, config: config}

    ~H"""
    <div
      id={"widget-#{@config["chart_id"] || "pie-chart"}"}
      class="h-64 flex justify-center items-center"
      phx-hook="PieChartHook"
      data-chart-data={Jason.encode!(@data)}
      data-config={Jason.encode!(@config)}
    >
      <canvas
        id={"chart-#{@config["chart_id"] || "pie-chart"}"}
        style="max-height: 200px; max-width: 200px;"
      >
      </canvas>
    </div>
    """
  end

  defp render_widget_content("table", data, config) do
    assigns = %{data: data, config: config}

    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <%= for column <- @config["columns"] || [] do %>
              <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {column["title"]}
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for row <- @data[:rows] || [] do %>
            <tr class="hover:bg-gray-50">
              <%= for column <- @config["columns"] || [] do %>
                <td class="px-3 py-2 text-sm text-gray-900">
                  {format_table_value(row[column["field"]], column["format"])}
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp render_widget_content("gauge", data, config) do
    value = Map.get(data, :current_value, 0)
    max_value = Map.get(config, "max_value", 100)
    percentage = (value / max_value * 100) |> Float.round(1)
    color = gauge_color(percentage, config)

    assigns = %{value: value, percentage: percentage, color: color, config: config}

    ~H"""
    <div class="relative">
      <div class="flex items-center justify-center">
        <div class="relative">
          <svg class="w-32 h-32 transform -rotate-90">
            <circle
              cx="64"
              cy="64"
              r="56"
              stroke="currentColor"
              stroke-width="8"
              fill="none"
              class="text-gray-200"
            >
            </circle>
            <circle
              cx="64"
              cy="64"
              r="56"
              stroke="currentColor"
              stroke-width="8"
              fill="none"
              stroke-dasharray="#{2 * :math.pi() * 56}"
              stroke-dashoffset="#{2 * :math.pi() * 56 * (1 - @percentage / 100)}"
              class={@color}
              stroke-linecap="round"
            >
            </circle>
          </svg>
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="text-center">
              <div class="text-2xl font-bold text-gray-900">
                {@percentage}%
              </div>
              <div class="text-xs text-gray-500">
                {format_number(@value, @config["format"] || "number")}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_widget_content("metric_list", data, config) do
    assigns = %{data: data, config: config}

    ~H"""
    <div class="space-y-3">
      <%= for metric <- @data[:metrics] || [] do %>
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-gray-900">
            {metric["label"]}
          </span>
          <span class="text-sm text-gray-600">
            {format_number(metric["value"], metric["format"] || "number")}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_widget_content(_, _data, _config) do
    assigns = %{}

    ~H"""
    <div class="flex items-center justify-center h-32 text-gray-500">
      <div class="text-center">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-12 w-12 mx-auto mb-2"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
          />
        </svg>
        <p class="text-sm">Widget type not supported</p>
      </div>
    </div>
    """
  end

  # Helper Functions

  defp format_number(value, "currency") do
    "$#{Mcp.NumberHelper.number_to_currency(value)}"
  end

  defp format_number(value, "percentage") when is_number(value) do
    "#{Float.round(value, 2)}%"
  end

  defp format_number(value, "bytes") when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)} GB"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)} MB"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)} KB"
      true -> "#{value} B"
    end
  end

  defp format_number(value, "duration") when is_number(value) do
    cond do
      value >= 3600 -> "#{div(value, 3600)}h #{rem(div(value, 60), 60)}m"
      value >= 60 -> "#{div(value, 60)}m #{rem(value, 60)}s"
      true -> "#{value}s"
    end
  end

  defp format_number(value, _format) do
    Mcp.NumberHelper.number_to_delimited(value, precision: if(is_float(value), do: 2, else: 0))
  end

  defp format_table_value(value, "currency") do
    format_number(value, "currency")
  end

  defp format_table_value(value, "percentage") do
    format_number(value, "percentage")
  end

  defp format_table_value(value, _format) do
    to_string(value)
  end

  defp trend_color("up"), do: "text-green-600"
  defp trend_color("down"), do: "text-red-600"
  defp trend_color(_), do: "text-gray-600"

  defp trend_icon("up") do
    "<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"h-4 w-4\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\">
      <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13 7h8m0 0v8m0-8l-8 8-4-4-6 6\" />
    </svg>"
  end

  defp trend_icon("down") do
    "<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"h-4 w-4\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\">
      <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13 17h8m0 0V9m0 8l-8-8-4 4-6-6\" />
    </svg>"
  end

  defp trend_icon(_) do
    "<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"h-4 w-4\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\">
      <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 12h14\" />
    </svg>"
  end

  defp gauge_color(percentage, config) do
    thresholds =
      Map.get(config, "thresholds", %{
        "good" => 80,
        "warning" => 60,
        "critical" => 0
      })

    cond do
      percentage >= Map.get(thresholds, "good", 80) -> "text-green-500"
      percentage >= Map.get(thresholds, "warning", 60) -> "text-yellow-500"
      true -> "text-red-500"
    end
  end

  defp get_time_ago(nil), do: ""

  defp get_time_ago(timestamp) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, timestamp, :second)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end
end
