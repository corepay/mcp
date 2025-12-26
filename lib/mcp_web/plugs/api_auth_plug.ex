defmodule McpWeb.Plugs.ApiAuthPlug do
  @moduledoc """
  Authenticates requests using API Keys.
  Supports `X-API-Key` header or `Authorization: Bearer <token>`.
  """
  import Plug.Conn

  alias Mcp.Billing.ApiUsage
  alias Mcp.Platform.ApiKey

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_auth_token(conn) do
      nil ->
        conn
        |> send_resp(401, "Unauthorized: Missing API Key")
        |> halt()

      token ->
        case authenticate(token) do
          {:ok, api_key} ->
            conn
            |> assign(:current_api_key, api_key)
            |> assign_context(api_key)
            |> trigger_billing(api_key)

          {:error, _reason} ->
            conn
            |> send_resp(401, "Unauthorized: Invalid API Key")
            |> halt()
        end
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "x-api-key") do
      [token | _] ->
        token

      [] ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token | _] -> token
          _ -> nil
        end
    end
  end

  defp authenticate(token) do
    # We use the code interface defined in ApiKey resource
    ApiKey.authenticate(token)
  end

  defp assign_context(conn, api_key) do
    conn = assign(conn, :current_user_id, api_key.owner_id)

    # If the owner is a tenant, we might want to set current_tenant_id instead
    # Based on our polymorphic design:
    case api_key.owner_type do
      :tenant ->
        assign(conn, :current_tenant_id, api_key.owner_id)

      :user ->
        assign(conn, :current_user_id, api_key.owner_id)

      _ ->
        conn
    end
  end

  defp trigger_billing(conn, _api_key) do
    if tenant_id = conn.assigns[:current_tenant_id] do
      Task.start(fn ->
        ApiUsage.charge_usage(tenant_id)
      end)
    end

    conn
  end
end
