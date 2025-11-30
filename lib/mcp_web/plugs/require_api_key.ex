defmodule McpWeb.Plugs.RequireApiKey do
  @moduledoc """
  Plug to require a valid API key for access.
  Looks for `X-API-Key` header.
  """
  import Plug.Conn
  require Ash.Query

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

    # 1. Find key by prefix
    case Mcp.Accounts.ApiKey.by_prefix(prefix) do
      {:ok, [api_key]} ->
        # 2. Verify hash
        if Bcrypt.verify_pass(key, api_key.key_hash) do
          # 3. Check Limits
          with :ok <- check_rate_limit(api_key),
               :ok <- check_spending_limit(api_key) do
            # 4. Update last used
            if Application.get_env(:mcp, :async_api_key_updates, true) do
              Task.start(fn ->
                Mcp.Accounts.ApiKey.update!(api_key, %{last_used_at: DateTime.utc_now()})
              end)
            else
              Mcp.Accounts.ApiKey.update!(api_key, %{last_used_at: DateTime.utc_now()})
            end

            # 5. Parse entity scopes
            {merchant_ids, reseller_ids} = parse_scopes(api_key.scopes)

            # 6. Return key with augmented assigns
            {:ok,
             Map.merge(api_key, %{
               allowed_merchant_ids: merchant_ids,
               allowed_reseller_ids: reseller_ids
             })}
          else
            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, :invalid}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp check_rate_limit(%{rate_limit: nil}), do: :ok

  defp check_rate_limit(%{rate_limit: limit, id: id}) do
    Mcp.Utils.RateLimiter.check_limit("api_key:#{id}", limit)
  end

  defp check_spending_limit(%{spending_limit: nil}), do: :ok

  defp check_spending_limit(%{spending_limit: limit, id: id}) do
    # Get current month's spend
    start_date = Date.beginning_of_month(Date.utc_today())
    end_date = Date.utc_today()

    # We use a cached value in Redis to avoid hitting DB on every request
    # The cache key expires every hour or so, and we add the estimated cost of current request?
    # For now, let's query the DB but cache the result for a short period (e.g. 1 minute)

    # TODO: Optimization - Cache this query result
    current_spend = Mcp.Ai.LlmUsage.calculate_spend(id, start_date, end_date)

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
