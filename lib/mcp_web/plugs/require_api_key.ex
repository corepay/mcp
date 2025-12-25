defmodule McpWeb.Plugs.RequireApiKey do
  @moduledoc """
  Plug to require a valid API key for access.
  Looks for `X-API-Key` header.
  """
  import Plug.Conn
  require Ash.Query
  alias Mcp.Accounts.ApiKey
  alias Mcp.Cache.SpendingCache
  alias Mcp.Utils.RateLimiter

  def init(opts), do: opts

  def call(conn, _opts) do
    with [key] <- get_req_header(conn, "x-api-key"),
         {:ok, api_key} <- verify_key(key) do
      conn
      |> assign(:current_api_key, api_key)
      |> assign(:current_tenant_id, api_key.tenant_id)
      |> assign(:current_merchant_id, api_key.merchant_id)
      |> assign(:current_permissions, api_key.permissions)
      |> assign(:allowed_merchant_ids, api_key.allowed_merchant_ids)
      |> assign(:allowed_reseller_ids, api_key.allowed_reseller_ids)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid or missing API Key"})
        |> halt()
    end
  end

  defp verify_key(key) do
    prefix = String.slice(key, 0, 7)

    with {:ok, [api_key]} <- ApiKey.by_prefix(prefix),
         true <- Bcrypt.verify_pass(key, api_key.key_hash),
         :ok <- check_limits(api_key) do
      record_key_usage(api_key)

      {merchant_ids, reseller_ids} = parse_scopes(api_key.scopes)

      {:ok,
       Map.merge(api_key, %{
         allowed_merchant_ids: merchant_ids,
         allowed_reseller_ids: reseller_ids
       })}
    else
      {:ok, []} -> {:error, :not_found}
      false -> {:error, :invalid}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :not_found}
    end
  end

  defp check_limits(api_key) do
    with :ok <- check_rate_limit(api_key) do
      check_spending_limit(api_key)
    end
  end

  defp record_key_usage(api_key) do
    if Application.get_env(:mcp, :async_api_key_updates, true) do
      Task.start(fn ->
        ApiKey.update!(api_key, %{last_used_at: DateTime.utc_now()})
      end)
    else
      ApiKey.update!(api_key, %{last_used_at: DateTime.utc_now()})
    end
  end

  defp check_rate_limit(%{rate_limit: nil}), do: :ok

  defp check_rate_limit(%{rate_limit: limit, id: id}) do
    RateLimiter.check_limit("api_key:#{id}", limit)
  end

  defp check_spending_limit(%{spending_limit: nil}), do: :ok

  defp check_spending_limit(%{spending_limit: limit, id: id}) do
    current_spend = SpendingCache.get_or_calculate_monthly_spend(id)

    if Decimal.compare(current_spend, limit) == :gt do
      {:error, :spending_limit_exceeded}
    else
      :ok
    end
  end

  defp parse_scopes(scopes) do
    Enum.reduce(scopes, {[], []}, fn scope, {merchants, resellers} ->
      case String.split(scope, ":") do
        ["merchant", id] -> {[id | merchants], resellers}
        ["reseller", id] -> {merchants, [id | resellers]}
        _ -> {merchants, resellers}
      end
    end)
  end
end
