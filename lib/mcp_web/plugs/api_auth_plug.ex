defmodule McpWeb.Plugs.ApiAuthPlug do
  @moduledoc """
  Authenticates requests using API Keys.
  Supports `X-API-Key` header or `Authorization: Bearer <token>`.

  Sets the following assigns on successful authentication:
  - `current_api_key`: The authenticated API key resource
  - `api_actor`: Set to `:api_key` to identify the authentication method
  - `current_tenant_id`: For tenant-owned keys
  - `current_user_id`: For user-owned keys

  Supports scope-based permission checking via options:
  - `required_scopes`: List of scopes to check (any match allows access)
  """
  import Plug.Conn

  alias Mcp.Platform.ApiKey

  require Logger

  def init(opts) when is_list(opts), do: Enum.into(opts, %{})
  def init(opts) when is_map(opts), do: opts

  def call(conn, opts) do
    opts = if is_list(opts), do: Enum.into(opts, %{}), else: opts
    required_scopes = Map.get(opts, :required_scopes, [])

    with {:ok, token} <- extract_token(conn),
         {:ok, api_key} <- authenticate(token),
         :ok <- validate_api_key(api_key, required_scopes) do
      conn
      |> assign(:current_api_key, api_key)
      |> assign(:api_actor, :api_key)
      |> assign_context(api_key)
      |> update_last_used_async(api_key)
    else
      {:error, :missing_token} ->
        send_json_error(conn, 401, "missing_api_key", "Unauthorized: Missing API Key")

      {:error, :not_found} ->
        send_json_error(conn, 401, "invalid_api_key", "Unauthorized: Invalid API Key")

      {:error, :expired} ->
        send_json_error(conn, 401, "expired_api_key", "Unauthorized: Expired API Key")

      {:error, :revoked} ->
        send_json_error(conn, 401, "revoked_api_key", "Unauthorized: Revoked API Key")

      {:error, :insufficient_permissions} ->
        send_json_error(
          conn,
          403,
          "insufficient_permissions",
          "Forbidden: Insufficient permissions"
        )

      {:error, _reason} ->
        send_json_error(conn, 401, "invalid_api_key", "Unauthorized: Invalid API Key")
    end
  end

  defp extract_token(conn) do
    case get_auth_token(conn) do
      nil -> {:error, :missing_token}
      "" -> {:error, :missing_token}
      token -> {:ok, token}
    end
  end

  defp validate_api_key(api_key, required_scopes) do
    cond do
      expired?(api_key) -> {:error, :expired}
      revoked?(api_key) -> {:error, :revoked}
      not has_required_scopes?(api_key, required_scopes) -> {:error, :insufficient_permissions}
      true -> :ok
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "x-api-key") do
      [token | _] when token != "" ->
        token

      _ ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token | _] when token != "" -> token
          _ -> nil
        end
    end
  end

  defp authenticate(token) do
    # Use the authenticate action defined in ApiKey resource
    # This hashes the token and filters for non-revoked keys
    case ApiKey.authenticate(token) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, api_key} -> {:ok, api_key}
      {:error, _} = error -> error
    end
  end

  defp expired?(%{expires_at: nil}), do: false

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp revoked?(%{revoked_at: nil}), do: false
  defp revoked?(%{revoked_at: _}), do: true

  defp has_required_scopes?(_api_key, []), do: true

  defp has_required_scopes?(api_key, required_scopes) do
    # Check if any of the required scopes match
    Enum.any?(required_scopes, fn scope ->
      scope in api_key.scopes
    end)
  end

  defp assign_context(conn, api_key) do
    case api_key.owner_type do
      :tenant ->
        assign(conn, :current_tenant_id, api_key.owner_id)

      :user ->
        assign(conn, :current_user_id, api_key.owner_id)

      _ ->
        conn
    end
  end

  defp update_last_used_async(conn, api_key) do
    Task.start(fn ->
      try do
        api_key
        |> Ash.Changeset.for_update(:update_last_used, %{})
        |> Ash.update()
      rescue
        e ->
          Logger.warning("Failed to update last_used_at for API key #{api_key.id}: #{inspect(e)}")
      end
    end)

    conn
  end

  defp send_json_error(conn, status, code, message) do
    request_id = get_request_id(conn)

    body =
      Jason.encode!(%{
        error: %{
          code: code,
          message: message,
          request_id: request_id
        },
        request_id: request_id
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
    |> halt()
  end

  defp get_request_id(conn) do
    case get_resp_header(conn, "x-request-id") do
      [id | _] -> id
      [] -> generate_request_id()
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
