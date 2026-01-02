defmodule McpWeb.Ola.CameraUploadLiveTest do
  @moduledoc false
  use McpWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Mcp.Underwriting.Services.MagicCamera

  setup do
    MagicCamera.init()
    :ok
  end

  describe "mount with valid token" do
    test "renders upload form", %{conn: conn} do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      {:ok, _view, html} = live(conn, "/upload/camera/#{session.token}")

      assert html =~ "Upload Government ID"
      assert html =~ "Upload Document"
    end

    test "shows correct document type label for bank statement", %{conn: conn} do
      {:ok, session} = MagicCamera.generate_session("app-456", :bank_statement)

      {:ok, _view, html} = live(conn, "/upload/camera/#{session.token}")

      assert html =~ "Upload Bank Statement"
    end

    test "shows correct document type label for business license", %{conn: conn} do
      {:ok, session} = MagicCamera.generate_session("app-789", :business_license)

      {:ok, _view, html} = live(conn, "/upload/camera/#{session.token}")

      assert html =~ "Upload Business License"
    end
  end

  describe "mount with invalid token" do
    test "shows expired message for invalid token", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/upload/camera/invalid-token-123")

      assert html =~ "Link Expired"
      assert html =~ "Please scan a new QR code"
    end
  end

  describe "mount with expired token" do
    test "shows expired message", %{conn: conn} do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      # Manually expire the token
      expired_at = DateTime.add(DateTime.utc_now(), -1, :minute)

      :ets.insert(:magic_camera_sessions, {
        session.token,
        %{
          application_id: session.application_id,
          document_type: session.document_type,
          expires_at: expired_at,
          token: session.token
        }
      })

      {:ok, _view, html} = live(conn, "/upload/camera/#{session.token}")

      assert html =~ "Link Expired"
    end
  end

  describe "upload flow" do
    test "successful upload shows completion message", %{conn: conn} do
      {:ok, session} = MagicCamera.generate_session("app-upload-test", :government_id)

      # Subscribe to receive the broadcast
      Phoenix.PubSub.subscribe(Mcp.PubSub, "magic_camera:app-upload-test")

      {:ok, view, _html} = live(conn, "/upload/camera/#{session.token}")

      # Upload a file
      document =
        file_input(view, "form", :document, [
          %{
            name: "id-front.jpg",
            content: <<0xFF, 0xD8, 0xFF>>,
            type: "image/jpeg"
          }
        ])

      assert render_upload(document, "id-front.jpg") =~ "id-front.jpg"

      # Submit the form
      html = view |> element("form") |> render_submit()

      assert html =~ "Upload Complete!"
      assert html =~ "You can close this page"

      # Should have received the broadcast
      assert_receive {:document_uploaded, :government_id, _path}
    end
  end
end
