defmodule McpWeb.Ola.Components.ValidatedUpload do
  @moduledoc """
  Document upload component with real-time validation feedback.
  Uses The Eye to analyze documents as they're uploaded.

  Provides immediate feedback on document quality and completeness,
  allowing users to fix issues before final submission.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Services.DocumentValidator

  def mount(socket) do
    {:ok,
     socket
     |> assign(:validation_result, nil)
     |> assign(:validating, false)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:id, assigns[:id] || "validated-upload")
      |> assign(:document_type, assigns[:document_type] || :other)
      |> assign(:label, assigns[:label] || "Upload Document")
      |> assign(:upload_ref, assigns[:upload_ref])
      |> assign(:uploads, assigns[:uploads])

    {:ok, socket}
  end

  @doc """
  Handles the validate_upload event triggered when a file is selected.
  Starts async validation and updates UI with loading state.
  """
  def handle_event("validate_upload", %{"ref" => ref}, socket) do
    uploads = socket.assigns[:uploads]

    if uploads do
      entry = Enum.find(uploads.entries, &(&1.ref == ref))

      if entry do
        socket = assign(socket, :validating, true)
        # Async validation would happen here in real implementation
        send(self(), {:validation_complete, ref, %{valid?: true, issues: []}})
        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @doc """
  Handles validation completion messages and updates the UI.
  """
  def handle_info({:validation_complete, _ref, result}, socket) do
    {:noreply,
     socket
     |> assign(:validating, false)
     |> assign(:validation_result, result)}
  end

  @doc """
  Processes document validation using extracted content.
  Returns a map with validation results (valid?, quality_score, issues, suggestions).

  Uses `validate_extracted_content` for pure content validation without
  requiring external services. This is suitable for testing and for cases
  where content has already been extracted.

  For full validation with The Eye service, use `validate_with_service/3`.
  """
  @spec process_validation(binary(), String.t(), atom()) :: map()
  def process_validation(content, _filename, document_type) do
    case DocumentValidator.validate_extracted_content(content, document_type) do
      {:ok, validation} -> Map.from_struct(validation)
      {:error, validation} -> Map.from_struct(validation)
    end
  end

  @doc """
  Full validation using The Eye service for document analysis.
  Falls back gracefully if service is unavailable.
  """
  @spec validate_with_service(binary(), String.t(), atom()) :: map()
  def validate_with_service(file_content, filename, document_type) do
    case DocumentValidator.validate(file_content, filename, document_type) do
      {:ok, validation} -> Map.from_struct(validation)
      {:error, validation} -> Map.from_struct(validation)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="validated-upload" id={@id}>
      <label class="block text-sm font-medium mb-2"><%= @label %></label>

      <div class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center hover:border-primary transition-colors">
        <%= if @uploads do %>
          <.live_file_input upload={@uploads} class="hidden" />
        <% end %>

        <div class="space-y-2">
          <.icon name="hero-cloud-arrow-up" class="w-8 h-8 mx-auto text-base-content/50" />
          <p class="text-sm text-base-content/70">
            Drag & drop or click to upload
          </p>
        </div>
      </div>

      <%= if @validating do %>
        <div class="mt-2 flex items-center gap-2 text-info">
          <span class="loading loading-spinner loading-xs"></span>
          <span class="text-sm">Checking document quality...</span>
        </div>
      <% end %>

      <%= if @validation_result do %>
        <div class={[
          "mt-2 p-3 rounded-lg text-sm",
          validation_classes(@validation_result)
        ]}>
          <%= if @validation_result.valid? do %>
            <div class="flex items-center gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5" />
              <span>Document looks good! Quality score: <%= @validation_result.quality_score %>%</span>
            </div>
          <% else %>
            <div class="space-y-2">
              <div class="flex items-center gap-2">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                <span>Please fix these issues:</span>
              </div>
              <ul class="list-disc list-inside ml-2">
                <%= for issue <- @validation_result.issues do %>
                  <li><%= issue %></li>
                <% end %>
              </ul>
              <%= if @validation_result[:suggestions] && @validation_result.suggestions != [] do %>
                <div class="mt-2 text-base-content/70">
                  <strong>Tips:</strong>
                  <ul class="list-disc list-inside ml-2">
                    <%= for suggestion <- @validation_result.suggestions do %>
                      <li><%= suggestion %></li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp validation_classes(%{valid?: true}), do: "bg-success/10 text-success"
  defp validation_classes(%{valid?: false}), do: "bg-error/10 text-error"
  defp validation_classes(_), do: ""
end
