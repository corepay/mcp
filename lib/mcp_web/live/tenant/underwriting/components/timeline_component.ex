defmodule McpWeb.Tenant.Underwriting.Components.TimelineComponent do
  use McpWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-lg border border-base-200">
      <div class="card-body">
        <h2 class="card-title text-lg mb-4">Activity Timeline</h2>
        
        <div class="relative pl-4 border-l border-base-300 space-y-6">
          <%= for activity <- @activities do %>
            <div class="relative">
              <!-- Dot -->
              <div class={["absolute -left-[21px] top-1 w-3 h-3 rounded-full border-2 border-base-100", dot_color(activity.type)]}></div>
              
              <div class="flex flex-col">
                <span class="text-xs text-zinc-500">
                  <%= Calendar.strftime(activity.inserted_at, "%b %d, %H:%M") %>
                </span>
                
                <p class="font-medium text-sm text-zinc-900 dark:text-zinc-100">
                  <%= format_activity_type(activity.type) %>
                </p>
                
                <%= if activity.metadata do %>
                  <div class="mt-1 text-xs text-zinc-600 bg-base-200 p-2 rounded">
                    <%= render_metadata(activity.metadata) %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
          <%= if Enum.empty?(@activities) do %>
            <p class="text-sm text-zinc-500 italic">No activity recorded yet.</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_activity_type(:status_change), do: "Status Changed"
  defp format_activity_type(:comment), do: "Comment Added"
  defp format_activity_type(:internal_note), do: "Internal Note"
  defp format_activity_type(:risk_assessment), do: "Risk Assessment Completed"
  defp format_activity_type(:document_upload), do: "Document Uploaded"
  defp format_activity_type(type), do: Phoenix.Naming.humanize(type)

  defp dot_color(:internal_note), do: "bg-warning"
  defp dot_color(:status_change), do: "bg-primary"
  defp dot_color(:risk_assessment), do: "bg-error"
  defp dot_color(_), do: "bg-zinc-400"

  defp render_metadata(%{"note" => note}), do: note
  defp render_metadata(%{"reason" => reason}), do: reason
  defp render_metadata(metadata) do
    # Simple key-value rendering for now
    Enum.map(metadata, fn {k, v} -> 
      "#{Phoenix.Naming.humanize(k)}: #{inspect(v)}" 
    end)
    |> Enum.join(", ")
  end
end
