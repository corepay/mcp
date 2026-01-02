defmodule Mcp.Underwriting.Services.MagicCameraTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.MagicCamera

  setup do
    MagicCamera.init()
    :ok
  end

  describe "generate_session/2" do
    test "creates a unique session with QR data" do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      assert session.application_id == "app-123"
      assert session.document_type == :government_id
      assert is_binary(session.token)
      assert is_binary(session.qr_url)
      assert String.contains?(session.qr_url, session.token)
    end

    test "session expires in 10 minutes" do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      # Should expire ~10 minutes from now
      diff = DateTime.diff(session.expires_at, DateTime.utc_now(), :minute)
      assert diff >= 9 and diff <= 10
    end

    test "generates unique tokens for each session" do
      {:ok, session1} = MagicCamera.generate_session("app-1", :government_id)
      {:ok, session2} = MagicCamera.generate_session("app-2", :bank_statement)

      assert session1.token != session2.token
    end

    test "supports different document types" do
      {:ok, session1} = MagicCamera.generate_session("app-1", :government_id)
      {:ok, session2} = MagicCamera.generate_session("app-2", :bank_statement)
      {:ok, session3} = MagicCamera.generate_session("app-3", :business_license)

      assert session1.document_type == :government_id
      assert session2.document_type == :bank_statement
      assert session3.document_type == :business_license
    end
  end

  describe "verify_session/1" do
    test "returns session data for valid token" do
      {:ok, session} = MagicCamera.generate_session("app-123", :bank_statement)
      {:ok, verified} = MagicCamera.verify_session(session.token)

      assert verified.application_id == "app-123"
      assert verified.document_type == :bank_statement
    end

    test "returns error for unknown token" do
      result = MagicCamera.verify_session("unknown-token")

      assert {:error, :invalid_or_expired} = result
    end

    test "returns error for expired token" do
      # Create a session and manually expire it
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      # Manually expire by updating the session in ETS
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

      result = MagicCamera.verify_session(session.token)
      assert {:error, :invalid_or_expired} = result
    end

    test "deletes expired token after verification attempt" do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      # Manually expire the session
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

      # First call returns error and deletes
      assert {:error, :invalid_or_expired} = MagicCamera.verify_session(session.token)

      # Token no longer exists in ETS
      assert :ets.lookup(:magic_camera_sessions, session.token) == []
    end
  end

  describe "complete_upload/2" do
    test "returns error for invalid token" do
      result = MagicCamera.complete_upload("invalid-token", "/path/to/doc")
      assert {:error, :invalid_or_expired} = result
    end

    test "broadcasts document_uploaded event and cleans up session" do
      # Subscribe to PubSub for the application
      Phoenix.PubSub.subscribe(Mcp.PubSub, "magic_camera:app-broadcast-test")

      {:ok, session} = MagicCamera.generate_session("app-broadcast-test", :government_id)

      # Complete the upload
      assert {:ok, :uploaded} = MagicCamera.complete_upload(session.token, "/uploads/doc.pdf")

      # Should receive the broadcast
      assert_receive {:document_uploaded, :government_id, "/uploads/doc.pdf"}

      # Session should be deleted
      assert {:error, :invalid_or_expired} = MagicCamera.verify_session(session.token)
    end
  end

  describe "invalidate_session/1" do
    test "removes a valid session" do
      {:ok, session} = MagicCamera.generate_session("app-123", :government_id)

      assert :ok = MagicCamera.invalidate_session(session.token)
      assert {:error, :invalid_or_expired} = MagicCamera.verify_session(session.token)
    end

    test "returns ok for non-existent token" do
      assert :ok = MagicCamera.invalidate_session("non-existent")
    end
  end
end
