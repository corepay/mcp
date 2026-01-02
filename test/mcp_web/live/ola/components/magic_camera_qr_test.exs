defmodule McpWeb.Ola.Components.MagicCameraQRTest do
  @moduledoc false
  use McpWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Mcp.Underwriting.Services.MagicCamera
  alias McpWeb.Ola.Components.MagicCameraQR

  setup do
    MagicCamera.init()
    :ok
  end

  # We need a host LiveView to test the component
  defmodule TestLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket) do
      # Subscribe to PubSub for magic camera uploads
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mcp.PubSub, "magic_camera:test-app-123")
      end

      {:ok,
       socket
       |> Phoenix.Component.assign(:application_id, "test-app-123")
       |> Phoenix.Component.assign(:document_type, :government_id)
       |> Phoenix.Component.assign(:upload_result, nil)}
    end

    def handle_info({:document_uploaded, doc_type, path}, socket) do
      # Forward to component and update local state
      send_update(MagicCameraQR, id: "qr-test", reset: true)
      {:noreply, Phoenix.Component.assign(socket, :upload_result, %{type: doc_type, path: path})}
    end

    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={MagicCameraQR}
          id="qr-test"
          application_id={@application_id}
          document_type={@document_type}
        />
        <%= if @upload_result do %>
          <div id="upload-result">Uploaded: {@upload_result.path}</div>
        <% end %>
      </div>
      """
    end
  end

  describe "initial render" do
    test "shows button to generate QR code", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TestLive)

      assert html =~ "Use phone camera"
      assert html =~ "hero-qr-code"
    end
  end

  describe "generate_qr event" do
    test "generates and displays QR code", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      # Click the generate button
      html =
        view
        |> element("button", "Use phone camera")
        |> render_click()

      assert html =~ "Scan to upload with phone"
      assert html =~ "<svg"
      assert html =~ "Expires in"
      assert html =~ "Generate new code"
    end
  end

  describe "close_qr event" do
    test "closes the QR code display", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      # Generate QR code
      view
      |> element("button", "Use phone camera")
      |> render_click()

      # Close the QR code
      html =
        view
        |> element("button[phx-click=close_qr]")
        |> render_click()

      assert html =~ "Use phone camera"
      refute html =~ "Scan to upload with phone"
    end
  end

  describe "upload notification" do
    test "parent handles upload notification and resets component", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      # Generate QR code - this subscribes the component to PubSub
      view
      |> element("button", "Use phone camera")
      |> render_click()

      # Verify QR is shown
      html = render(view)
      assert html =~ "Scan to upload with phone"

      # Simulate upload completion via PubSub
      # The parent LiveView's handle_info will receive this
      Phoenix.PubSub.broadcast(
        Mcp.PubSub,
        "magic_camera:test-app-123",
        {:document_uploaded, :government_id, "/path/to/doc.pdf"}
      )

      # Wait for the message to be processed
      :timer.sleep(100)

      html = render(view)
      assert html =~ "Uploaded: /path/to/doc.pdf"

      # QR code should be hidden after upload (component was reset)
      refute html =~ "Scan to upload with phone"
    end
  end

  describe "regenerate QR" do
    test "generates new QR code with new token", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      # Generate first QR code
      view
      |> element("button", "Use phone camera")
      |> render_click()

      # Regenerate
      html =
        view
        |> element("button", "Generate new code")
        |> render_click()

      # Should still show QR code
      assert html =~ "Scan to upload with phone"
      assert html =~ "<svg"
    end
  end
end
