defmodule McpWeb.Ola.Components.MagicCameraQR do
  @moduledoc """
  QR code component for magic camera handoff.

  Displays a QR code that users can scan with their phone to upload
  documents using their phone's camera. Subscribes to PubSub to
  receive upload completion notifications.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Services.MagicCamera

  @impl true
  def mount(socket) do
    {:ok, assign(socket, session: nil, qr_svg: nil, listening: false)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      if assigns[:reset] do
        # Reset triggered by parent after upload complete
        handle_reset(socket)
      else
        socket
        |> assign(:application_id, assigns[:application_id])
        |> assign(:document_type, assigns[:document_type])
        |> assign(:id, assigns[:id])
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("generate_qr", _params, socket) do
    {:ok, session} =
      MagicCamera.generate_session(
        socket.assigns.application_id,
        socket.assigns.document_type
      )

    # Generate QR code SVG using eqrcode library
    qr_svg = generate_qr_svg(session.qr_url)

    # Subscribe to upload notifications
    Phoenix.PubSub.subscribe(Mcp.PubSub, "magic_camera:#{socket.assigns.application_id}")

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:qr_svg, qr_svg)
     |> assign(:listening, true)}
  end

  @impl true
  def handle_event("close_qr", _params, socket) do
    # Invalidate the session if closing without upload
    if socket.assigns.session do
      MagicCamera.invalidate_session(socket.assigns.session.token)
    end

    {:noreply,
     socket
     |> assign(:session, nil)
     |> assign(:qr_svg, nil)
     |> assign(:listening, false)}
  end

  # Note: LiveComponents can't receive messages directly.
  # The parent LiveView should handle {:document_uploaded, ...} messages
  # and call update/2 on this component to reset state, or use send_update.
  #
  # Example in parent LiveView:
  #   def handle_info({:document_uploaded, doc_type, path}, socket) do
  #     send_update(MagicCameraQR, id: "qr-component", reset: true)
  #     ...
  #   end

  @doc """
  Resets the component state after an upload completes.
  Call via send_update from the parent LiveView.
  """
  def handle_reset(socket) do
    socket
    |> assign(:session, nil)
    |> assign(:qr_svg, nil)
    |> assign(:listening, false)
  end

  defp generate_qr_svg(url) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(width: 200)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="magic-camera-qr">
      <%= if @session do %>
        <div class="card bg-base-100 shadow border">
          <div class="card-body items-center text-center p-4">
            <div class="flex items-center justify-between w-full mb-2">
              <h3 class="card-title text-sm flex items-center gap-2">
                <.icon name="hero-device-phone-mobile" class="w-5 h-5" /> Scan to upload with phone
              </h3>
              <button
                phx-click="close_qr"
                phx-target={@myself}
                class="btn btn-ghost btn-xs btn-circle"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>

            <div class="p-2 bg-white rounded-lg">
              {raw(@qr_svg)}
            </div>

            <p class="text-xs text-base-content/60 mt-2">
              Expires in {remaining_time(@session.expires_at)}
            </p>

            <button phx-click="generate_qr" phx-target={@myself} class="btn btn-ghost btn-xs mt-1">
              Generate new code
            </button>
          </div>
        </div>
      <% else %>
        <button phx-click="generate_qr" phx-target={@myself} class="btn btn-outline btn-sm gap-2">
          <.icon name="hero-qr-code" class="w-4 h-4" /> Use phone camera
        </button>
      <% end %>
    </div>
    """
  end

  defp remaining_time(expires_at) do
    minutes = DateTime.diff(expires_at, DateTime.utc_now(), :minute)
    "#{max(0, minutes)} min"
  end
end
