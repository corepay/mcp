defmodule McpWeb.Plugs.ApiRateLimitPlug do
  @moduledoc """
  Rate limiting plug for API requests using Redis.

  Uses a sliding window algorithm with atomic increments to prevent race conditions.

  ## Options

  - `limit`: Maximum requests per window (default: based on API key type)
  - `window`: Window size in seconds (default: 60)
  - `bypass`: If true, skip rate limiting entirely (default: false)

  ## Rate Limits by API Key Type

  - `:developer` - 1000 requests per minute
  - `:reseller` - 500 requests per minute
  - `:merchant` - 100 requests per minute

  ## Response Headers

  Sets standard rate limit headers on all responses:
  - `X-RateLimit-Limit`: Maximum requests allowed
  - `X-RateLimit-Remaining`: Requests remaining in current window
  - `X-RateLimit-Reset`: Unix timestamp when the window resets

  When rate limited:
  - Returns 429 status code
  - Sets `Retry-After` header with seconds until reset
  """
  import Plug.Conn

  alias Mcp.Redis

  require Logger

  @default_limits %{
    developer: 1000,
    reseller: 500,
    merchant: 100
  }

  @default_window 60

  def init(opts) when is_list(opts), do: Enum.into(opts, %{})
  def init(opts) when is_map(opts), do: opts
  def init(_opts), do: %{}

  def call(conn, opts) do
    opts = normalize_opts(opts)

    if Map.get(opts, :bypass, false) do
      conn
    else
      case conn.assigns[:current_api_key] do
        nil ->
          conn

        api_key ->
          apply_rate_limit(conn, api_key, opts)
      end
    end
  end

  defp normalize_opts(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(_), do: %{}

  defp apply_rate_limit(conn, api_key, opts) do
    limit = get_limit(api_key, opts)
    window = Map.get(opts, :window, @default_window)

    current_window = div(System.system_time(:second), window)
    redis_key = "rate_limit:#{api_key.id}:#{current_window}"

    reset_timestamp = (current_window + 1) * window

    case increment_counter(redis_key, window) do
      {:ok, count} ->
        remaining = max(0, limit - count)

        if count <= limit do
          conn
          |> put_rate_limit_headers(limit, remaining, reset_timestamp)
        else
          retry_after = reset_timestamp - System.system_time(:second)

          conn
          |> put_rate_limit_headers(limit, 0, reset_timestamp)
          |> send_rate_limit_error(retry_after)
        end

      {:error, reason} ->
        Logger.warning("Rate limit check failed: #{inspect(reason)}, allowing request")
        conn
    end
  end

  defp get_limit(api_key, opts) do
    case Map.get(opts, :limit) do
      nil ->
        Map.get(@default_limits, api_key.type, 100)

      limit ->
        limit
    end
  end

  defp increment_counter(key, ttl) do
    commands = [
      ["INCR", key],
      ["EXPIRE", key, ttl + 1]
    ]

    case Redis.pipeline(commands) do
      {:ok, [count, _expire_result]} ->
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_rate_limit_headers(conn, limit, remaining, reset_timestamp) do
    conn
    |> put_resp_header("x-ratelimit-limit", to_string(limit))
    |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
    |> put_resp_header("x-ratelimit-reset", to_string(reset_timestamp))
  end

  defp send_rate_limit_error(conn, retry_after) do
    body =
      Jason.encode!(%{
        error: %{
          code: "rate_limit_exceeded",
          message: "Rate limit exceeded. Please retry after #{retry_after} seconds."
        }
      })

    conn
    |> put_resp_header("retry-after", to_string(retry_after))
    |> put_resp_content_type("application/json")
    |> send_resp(429, body)
    |> halt()
  end
end
