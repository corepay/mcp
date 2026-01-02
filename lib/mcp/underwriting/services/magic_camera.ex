defmodule Mcp.Underwriting.Services.MagicCamera do
  @moduledoc """
  Generates QR codes for mobile document upload.
  Enables desktop-to-phone handoff for camera capture.

  Sessions are stored in ETS for fast access and automatic
  cleanup on expiration. In production, consider using Redis
  for distributed storage across nodes.
  """

  @token_ttl_minutes 10
  @upload_endpoint "/upload/camera"
  @ets_table :magic_camera_sessions

  defstruct [:application_id, :document_type, :token, :qr_url, :expires_at]

  @type t :: %__MODULE__{
          application_id: String.t(),
          document_type: atom(),
          token: String.t(),
          qr_url: String.t(),
          expires_at: DateTime.t()
        }

  @doc """
  Initializes the ETS table for session storage.
  Called during application startup.
  """
  @spec init() :: :ok
  def init do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:set, :public, :named_table])
    end

    :ok
  end

  @doc """
  Generates a magic camera session for document upload.
  Returns QR code URL that opens phone camera.

  ## Examples

      iex> {:ok, session} = MagicCamera.generate_session("app-123", :government_id)
      iex> session.application_id
      "app-123"

  """
  @spec generate_session(String.t(), atom()) :: {:ok, t()}
  def generate_session(application_id, document_type) do
    token = generate_token()
    expires_at = DateTime.add(DateTime.utc_now(), @token_ttl_minutes, :minute)

    # Store session in ETS
    store_session(token, %{
      application_id: application_id,
      document_type: document_type,
      expires_at: expires_at
    })

    base_url = get_base_url()
    qr_url = "#{base_url}#{@upload_endpoint}/#{token}"

    {:ok,
     %__MODULE__{
       application_id: application_id,
       document_type: document_type,
       token: token,
       qr_url: qr_url,
       expires_at: expires_at
     }}
  end

  @doc """
  Verifies a magic camera token and returns session data.
  Returns error if token is invalid or expired.
  """
  @spec verify_session(String.t()) :: {:ok, t()} | {:error, :invalid_or_expired}
  def verify_session(token) do
    case get_session(token) do
      nil ->
        {:error, :invalid_or_expired}

      session ->
        if DateTime.compare(session.expires_at, DateTime.utc_now()) == :gt do
          {:ok, session}
        else
          delete_session(token)
          {:error, :invalid_or_expired}
        end
    end
  end

  @doc """
  Completes the upload and notifies the desktop session.
  Broadcasts to PubSub for real-time updates.
  """
  @spec complete_upload(String.t(), String.t()) ::
          {:ok, :uploaded} | {:error, :invalid_or_expired}
  def complete_upload(token, document_path) do
    case verify_session(token) do
      {:ok, session} ->
        # Broadcast to desktop session via PubSub
        Phoenix.PubSub.broadcast(
          Mcp.PubSub,
          "magic_camera:#{session.application_id}",
          {:document_uploaded, session.document_type, document_path}
        )

        delete_session(token)
        {:ok, :uploaded}

      error ->
        error
    end
  end

  @doc """
  Manually invalidates a session before expiration.
  """
  @spec invalidate_session(String.t()) :: :ok
  def invalidate_session(token) do
    delete_session(token)
    :ok
  end

  # Private functions

  defp generate_token do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  defp store_session(token, data) do
    :ets.insert(@ets_table, {token, Map.put(data, :token, token)})
  end

  defp get_session(token) do
    case :ets.lookup(@ets_table, token) do
      [{^token, data}] -> struct(__MODULE__, data)
      [] -> nil
    end
  end

  defp delete_session(token) do
    :ets.delete(@ets_table, token)
  end

  defp get_base_url do
    if Code.ensure_loaded?(McpWeb.Endpoint) do
      McpWeb.Endpoint.url()
    else
      System.get_env("APP_URL", "http://localhost:4000")
    end
  end
end
