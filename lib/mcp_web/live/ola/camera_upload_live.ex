defmodule McpWeb.Ola.CameraUploadLive do
  @moduledoc """
  Mobile-optimized camera upload page.
  Accessed via QR code scan from desktop.

  This LiveView provides a simple, mobile-friendly interface for
  uploading documents using the phone's camera. It validates the
  magic camera token and handles the upload flow.
  """
  use McpWeb, :live_view

  alias Mcp.Underwriting.Services.MagicCamera

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case MagicCamera.verify_session(token) do
      {:ok, session} ->
        socket =
          socket
          |> assign(:token, token)
          |> assign(:session, session)
          |> assign(:status, :ready)
          |> assign(:validation_result, nil)
          |> assign(:page_title, "Upload Document")
          |> allow_upload(:document,
            accept: ~w(.jpg .jpeg .png .pdf),
            max_entries: 1,
            max_file_size: 10_000_000
          )

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> assign(:token, token)
         |> assign(:session, nil)
         |> assign(:status, :expired)
         |> assign(:validation_result, nil)
         |> assign(:page_title, "Link Expired")
         |> put_flash(:error, "This link has expired. Please scan a new QR code.")}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    if socket.assigns.status != :ready do
      {:noreply, put_flash(socket, :error, "Upload session is not ready")}
    else
      uploaded_files =
        consume_uploaded_entries(socket, :document, fn %{path: path}, entry ->
          handle_upload(socket, path, entry)
        end)

      result = List.first(uploaded_files)

      socket =
        case result do
          %{status: :success} ->
            socket
            |> assign(:status, :complete)
            |> put_flash(:info, "Document uploaded successfully!")

          %{status: :invalid, issues: issues} ->
            socket
            |> assign(:validation_result, %{valid?: false, issues: issues})
            |> put_flash(:error, "Please fix the issues and try again")

          _ ->
            put_flash(socket, :error, "Upload failed")
        end

      {:noreply, socket}
    end
  end

  defp handle_upload(socket, path, entry) do
    session = socket.assigns.session
    token = socket.assigns.token

    # For now, store locally and complete the upload
    # In production, this would upload to S3/MinIO
    dest = store_document(path, entry, session)

    case MagicCamera.complete_upload(token, dest) do
      {:ok, :uploaded} ->
        {:ok, %{status: :success, path: dest}}

      {:error, _reason} ->
        {:ok, %{status: :error}}
    end
  end

  defp store_document(_path, entry, session) do
    # Return the logical path where the document would be stored
    # In production, this would upload to S3 and return the S3 path
    "applications/#{session.application_id}/camera/#{entry.client_name}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4">
      <div class="max-w-md mx-auto">
        {render_status(@status, assigns)}
      </div>
    </div>
    """
  end

  defp render_status(:expired, assigns) do
    assigns = assign(assigns, :icon_name, "hero-clock")

    ~H"""
    <div class="text-center py-12">
      <.icon name={@icon_name} class="w-16 h-16 mx-auto text-warning mb-4" />
      <h1 class="text-xl font-bold mb-2">Link Expired</h1>
      <p class="text-base-content/70">Please scan a new QR code from your application.</p>
    </div>
    """
  end

  defp render_status(:ready, assigns) do
    assigns =
      assigns
      |> assign(:camera_icon, "hero-camera")
      |> assign(:upload_icon, "hero-cloud-arrow-up")

    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">
          <.icon name={@camera_icon} class="w-6 h-6" />
          Upload {document_label(@session.document_type)}
        </h2>

        <form phx-submit="save" phx-change="validate">
          <div class="py-4">
            <.live_file_input
              upload={@uploads.document}
              class="file-input file-input-bordered w-full"
            />
          </div>

          <%= for entry <- @uploads.document.entries do %>
            <div class="mb-4">
              <div class="flex items-center gap-2">
                <span class="text-sm">{entry.client_name}</span>
                <progress class="progress progress-primary w-full" value={entry.progress} max="100" />
              </div>
              <%= for err <- upload_errors(@uploads.document, entry) do %>
                <p class="text-error text-sm">{error_to_string(err)}</p>
              <% end %>
            </div>
          <% end %>

          <%= if @validation_result && not @validation_result.valid? do %>
            <div class="alert alert-error mb-4">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
              <div>
                <h3 class="font-bold">Issues Found</h3>
                <ul class="list-disc list-inside text-sm">
                  <%= for issue <- @validation_result.issues do %>
                    <li>{issue}</li>
                  <% end %>
                </ul>
              </div>
            </div>
          <% end %>

          <button
            type="submit"
            class="btn btn-primary w-full"
            disabled={@uploads.document.entries == []}
          >
            <.icon name={@upload_icon} class="w-5 h-5" /> Upload Document
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp render_status(:complete, assigns) do
    assigns = assign(assigns, :check_icon, "hero-check-circle")

    ~H"""
    <div class="text-center py-12">
      <.icon name={@check_icon} class="w-16 h-16 mx-auto text-success mb-4" />
      <h1 class="text-xl font-bold mb-2">Upload Complete!</h1>
      <p class="text-base-content/70">You can close this page and return to your application.</p>
    </div>
    """
  end

  defp document_label(:government_id), do: "Government ID"
  defp document_label(:bank_statement), do: "Bank Statement"
  defp document_label(:business_license), do: "Business License"
  defp document_label(:tax_return), do: "Tax Return"
  defp document_label(:utility_bill), do: "Utility Bill"
  defp document_label(_), do: "Document"

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
