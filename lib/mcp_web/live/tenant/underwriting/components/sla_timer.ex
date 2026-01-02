defmodule McpWeb.Tenant.Underwriting.Components.SlaTimer do
  @moduledoc """
  Component to display SLA timers with real-time countdown.

  The component uses Process.send_after to schedule tick messages.
  The parent LiveView must handle the `{:update_sla_timer, component_id}` message
  and call `send_update/2` to refresh the component's time.

  Alternatively, use the JS hook for fully client-side updates.
  """
  use McpWeb, :live_component

  @tick_interval :timer.seconds(30)

  def mount(socket) do
    {:ok, assign(socket, :now, DateTime.utc_now())}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:now, DateTime.utc_now())

    # Schedule ticks only when connected
    if connected?(socket) && !socket.assigns[:tick_scheduled] do
      schedule_tick(socket.assigns.id)
      socket = assign(socket, :tick_scheduled, true)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  defp schedule_tick(component_id) do
    Process.send_after(self(), {:update_sla_timer, component_id}, @tick_interval)
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex items-center space-x-1 font-medium",
        sla_color(@due_at, @now)
      ]}
    >
      <.icon name="hero-clock" class="w-4 h-4" />
      <span>{relative_time(@due_at, @now)}</span>
    </div>
    """
  end

  defp sla_color(due_at, now) do
    diff = DateTime.diff(due_at, now, :minute)

    cond do
      diff < 0 -> "text-error font-bold animate-pulse"
      diff < 60 -> "text-warning"
      true -> "text-success"
    end
  end

  defp relative_time(datetime, now) do
    diff = DateTime.diff(datetime, now, :minute)

    cond do
      diff < 0 -> "Overdue by #{abs(diff)}m"
      diff < 60 -> "#{diff}m left"
      true -> "#{div(diff, 60)}h #{rem(diff, 60)}m left"
    end
  end
end
