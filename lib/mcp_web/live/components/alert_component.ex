defmodule McpWeb.AlertComponent do
  @moduledoc """
  LiveComponent for displaying and managing analytics alerts.

  Shows active alerts, allows acknowledgment and resolution,
  and provides alert history and status tracking.
  """

  use Phoenix.LiveComponent

  @impl true
  def update(%{alerts: alerts} = _assigns, socket) do
    socket =
      socket
      |> assign(:alerts, alerts)
      |> assign(:selected_alert, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{alert: alert} = _assigns, socket) do
    socket =
      socket
      |> assign(:alert, alert)

    {:ok, socket}
  end

  @impl true
  def render(%{alerts: alerts} = assigns) when is_list(alerts) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Active Alerts</h3>
        <div class="flex items-center space-x-2">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
            {length(@alerts)} Active
          </span>
        </div>
      </div>

      <%= if length(@alerts) == 0 do %>
        <div class="text-center py-8">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="mx-auto h-12 w-12 text-gray-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No active alerts</h3>
          <p class="mt-1 text-sm text-gray-500">All systems are operating normally.</p>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for alert <- @alerts do %>
            <.alert_row alert={alert} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(%{alert: _alert} = assigns) do
    ~H"""
    <div class={[
      "border-l-4 p-4 rounded-lg",
      alert_status_class(@alert.status)
    ]}>
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.alert_icon severity={@alert.widget_alert.severity} />
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-gray-900">
                {@alert.widget_alert.name}
              </h3>
              <div class="mt-1 text-sm text-gray-600">
                <p>{alert_message(@alert)}</p>
                <div class="mt-2 text-xs text-gray-500">
                  Triggered {time_ago(@alert.triggered_at)} •
                  Duration: {format_duration(@alert.duration_minutes)}
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="ml-4 flex-shrink-0 flex space-x-2">
          <%= if @alert.status == :triggered do %>
            <button
              phx-click="acknowledge_alert"
              phx-value-alert-id={@alert.id}
              class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Acknowledge
            </button>
          <% end %>
          <%= if @alert.status in [:triggered, :acknowledged] do %>
            <button
              phx-click="resolve_alert"
              phx-value-alert-id={@alert.id}
              class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
            >
              Resolve
            </button>
          <% end %>
        </div>
      </div>

      <%= if Map.get(assigns, :show_details, false) do %>
        <div class="mt-4 pt-4 border-t border-gray-200">
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="font-medium text-gray-900">Alert Type:</span>
              <span class="ml-2 text-gray-600">{@alert.widget_alert.alert_type}</span>
            </div>
            <div>
              <span class="font-medium text-gray-900">Severity:</span>
              <span class="ml-2">
                <.severity_badge severity={@alert.widget_alert.severity} />
              </span>
            </div>
            <div>
              <span class="font-medium text-gray-900">Widget:</span>
              <span class="ml-2 text-gray-600">{@alert.widget_alert.widget.title}</span>
            </div>
            <div>
              <span class="font-medium text-gray-900">Trigger Value:</span>
              <span class="ml-2 text-gray-600">{format_trigger_value(@alert)}</span>
            </div>
          </div>

          <%= if @alert.trigger_context && map_size(@alert.trigger_context) > 0 do %>
            <div class="mt-4">
              <h4 class="text-sm font-medium text-gray-900 mb-2">Context</h4>
              <pre class="text-xs bg-gray-50 p-2 rounded overflow-x-auto">
                <%= Jason.encode!(@alert.trigger_context, pretty: true) %>
              </pre>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp alert_row(assigns) do
    ~H"""
    <div class="alert-item" id={"alert-#{@alert.id}"}>
      <div
        class={[
          "border-l-4 p-4 rounded-lg bg-white hover:shadow-sm transition-shadow cursor-pointer",
          alert_status_class(@alert.status)
        ]}
        phx-click="toggle_alert_details"
        phx-value-alert-id={@alert.id}
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <.alert_icon severity={@alert.widget_alert.severity} />
            <div>
              <h4 class="text-sm font-medium text-gray-900">
                {@alert.widget_alert.name}
              </h4>
              <p class="text-sm text-gray-600 mt-1">
                {alert_message(@alert)}
              </p>
              <div class="flex items-center space-x-4 mt-1 text-xs text-gray-500">
                <span>{time_ago(@alert.triggered_at)}</span>
                <span>{format_duration(@alert.duration_minutes)}</span>
                <.severity_badge severity={@alert.widget_alert.severity} />
              </div>
            </div>
          </div>
          <div class="flex items-center space-x-2">
            <%= if @alert.status == :triggered do %>
              <button
                phx-click="acknowledge_alert"
                phx-value-alert-id={@alert.id}
                phx-click-stop
                class="px-2 py-1 text-xs bg-yellow-100 text-yellow-800 rounded hover:bg-yellow-200"
              >
                Acknowledge
              </button>
            <% end %>
            <%= if @alert.status in [:triggered, :acknowledged] do %>
              <button
                phx-click="resolve_alert"
                phx-value-alert-id={@alert.id}
                phx-click-stop
                class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded hover:bg-green-200"
              >
                Resolve
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper Components

  defp alert_icon(assigns) do
    ~H"""
    <div class={[
      "flex-shrink-0",
      case @severity do
        :critical -> "text-red-600"
        :high -> "text-red-500"
        :medium -> "text-yellow-500"
        :low -> "text-blue-500"
      end
    ]}>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <path
          fill-rule="evenodd"
          d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
          clip-rule="evenodd"
        />
      </svg>
    </div>
    """
  end

  defp severity_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
      case @severity do
        :critical -> "bg-red-100 text-red-800"
        :high -> "bg-red-100 text-red-800"
        :medium -> "bg-yellow-100 text-yellow-800"
        :low -> "bg-blue-100 text-blue-800"
      end
    ]}>
      {String.capitalize(Atom.to_string(@severity))}
    </span>
    """
  end

  # Helper Functions

  defp alert_status_class(:triggered), do: "border-red-400 bg-red-50"
  defp alert_status_class(:acknowledged), do: "border-yellow-400 bg-yellow-50"
  defp alert_status_class(:resolved), do: "border-green-400 bg-green-50"
  defp alert_status_class(:suppressed), do: "border-gray-400 bg-gray-50"

  defp alert_message(alert) do
    cond do
      alert.resolution_notes ->
        alert.resolution_notes

      alert.trigger_value && alert.threshold_value ->
        "Threshold exceeded: #{format_trigger_value(alert)}"

      true ->
        "Alert condition met"
    end
  end

  defp format_trigger_value(alert) do
    cond do
      alert.trigger_value && alert.threshold_value ->
        "#{alert.trigger_value} (threshold: #{alert.threshold_value})"

      alert.trigger_value ->
        "#{alert.trigger_value}"

      true ->
        "N/A"
    end
  end

  defp format_duration(nil), do: "0m"
  defp format_duration(minutes) when minutes < 60, do: "#{minutes}m"

  defp format_duration(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)
    "#{hours}h #{remaining_minutes}m"
  end

  defp time_ago(timestamp) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, timestamp, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86_400)}d ago"
    end
  end
end
