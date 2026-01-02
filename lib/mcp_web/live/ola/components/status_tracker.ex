defmodule McpWeb.Ola.Components.StatusTracker do
  @moduledoc """
  "Pizza Tracker" style status display for applicants.
  Shows application progress through underwriting stages.
  """
  use McpWeb, :live_component

  @stages [
    %{id: :submitted, label: "Submitted", icon: "hero-paper-airplane"},
    %{id: :under_review, label: "Under Review", icon: "hero-magnifying-glass"},
    %{id: :manual_review, label: "Final Review", icon: "hero-user-circle"},
    %{id: :decision, label: "Decision", icon: "hero-check-badge"}
  ]

  def render(assigns) do
    assigns = assign(assigns, :stages, @stages)

    ~H"""
    <div class="w-full max-w-2xl mx-auto">
      <div class="relative">
        <!-- Progress line -->
        <div class="absolute top-6 left-0 right-0 h-1 bg-base-300">
          <div
            class="h-full bg-primary transition-all duration-500"
            style={"width: #{progress_percentage(@status)}%"}
          />
        </div>
        
    <!-- Steps -->
        <div class="relative flex justify-between">
          <%= for {stage, idx} <- Enum.with_index(@stages) do %>
            <div class="flex flex-col items-center">
              <div class={[
                "w-12 h-12 rounded-full flex items-center justify-center border-4 z-10 transition-all",
                step_classes(stage.id, @status, idx)
              ]}>
                <%= if complete?(stage.id, @status) do %>
                  <.icon name="hero-check" class="w-6 h-6 text-white" />
                <% else %>
                  <.icon
                    name={stage.icon}
                    class={"w-6 h-6 #{if current?(stage.id, @status), do: "text-primary", else: "text-base-content/50"}"}
                  />
                <% end %>
              </div>

              <span class={[
                "mt-2 text-sm font-medium text-center",
                if(current?(stage.id, @status) or complete?(stage.id, @status),
                  do: "text-primary",
                  else: "text-base-content/50"
                )
              ]}>
                {stage.label}
              </span>

              <%= if current?(stage.id, @status) do %>
                <span class="mt-1 text-xs text-primary animate-pulse">
                  In Progress
                </span>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Status message -->
      <div class="mt-8 text-center">
        <p class="text-lg font-medium">{status_message(@status)}</p>
        <p class="text-sm text-base-content/70 mt-1">{status_description(@status)}</p>
      </div>
    </div>
    """
  end

  defp step_classes(stage_id, current_status, _idx) do
    cond do
      complete?(stage_id, current_status) ->
        "bg-primary border-primary"

      current?(stage_id, current_status) ->
        "bg-base-100 border-primary"

      true ->
        "bg-base-100 border-base-300"
    end
  end

  defp complete?(stage_id, current_status) do
    stage_order(stage_id) < stage_order(current_status)
  end

  defp current?(stage_id, current_status) do
    stage_order(stage_id) == stage_order(current_status)
  end

  defp stage_order(:submitted), do: 0
  defp stage_order(:under_review), do: 1
  defp stage_order(:manual_review), do: 2
  defp stage_order(:approved), do: 3
  defp stage_order(:rejected), do: 3
  defp stage_order(:decision), do: 3
  defp stage_order(_), do: 0

  defp progress_percentage(status) do
    case status do
      :submitted -> 0
      :under_review -> 33
      :manual_review -> 66
      :approved -> 100
      :rejected -> 100
      _ -> 0
    end
  end

  defp status_message(:submitted), do: "Application Received"
  defp status_message(:under_review), do: "Reviewing Your Application"
  defp status_message(:manual_review), do: "Final Review in Progress"
  defp status_message(:approved), do: "Congratulations! You're Approved!"
  defp status_message(:rejected), do: "Application Not Approved"
  defp status_message(_), do: "Processing"

  defp status_description(:submitted),
    do: "We've received your application and will begin review shortly."

  defp status_description(:under_review),
    do: "Our team is reviewing your documents and information."

  defp status_description(:manual_review),
    do: "A specialist is taking a final look at your application."

  defp status_description(:approved),
    do: "Your merchant account is ready. Check your email for next steps."

  defp status_description(:rejected),
    do: "Unfortunately, we couldn't approve your application at this time."

  defp status_description(_), do: ""
end
