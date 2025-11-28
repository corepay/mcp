defmodule McpWeb.Admin.Underwriting.Components.SlaTimer do
  use McpWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class={[
      "flex items-center space-x-1 font-medium",
      sla_color(@due_at)
    ]}>
      <.icon name="hero-clock" class="w-4 h-4" />
      <span><%= relative_time(@due_at) %></span>
    </div>
    """
  end

  defp sla_color(due_at) do
    diff = DateTime.diff(due_at, DateTime.utc_now(), :minute)
    
    cond do
      diff < 0 -> "text-error font-bold" # Overdue
      diff < 60 -> "text-warning" # Less than 1 hour
      true -> "text-success" # Plenty of time
    end
  end

  defp relative_time(datetime) do
    diff = DateTime.diff(datetime, DateTime.utc_now(), :minute)
    
    cond do
      diff < 0 -> "Overdue by #{abs(diff)}m"
      diff < 60 -> "#{diff}m left"
      true -> "#{div(diff, 60)}h #{rem(diff, 60)}m left"
    end
  end
end
