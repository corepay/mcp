defmodule Mcp.Utils.RateLimiter do
  @moduledoc """
  A simple sliding window rate limiter using Redis.
  """

  alias Mcp.Redis, as: Redis

  # Default window size in seconds (e.g., 60 seconds)
  @window_size 60

  @doc """
  Checks if the given key has exceeded the limit within the window.
  Returns :ok if allowed, {:error, :rate_limit_exceeded} if not.
  """
  def check_limit(key, limit) do
    now = System.system_time(:millisecond)
    window_start = now - @window_size * 1000

    # Use a sorted set to store timestamps of requests
    redis_key = "rate_limit:#{key}"

    # Transaction to ensure atomicity
    commands = [
      # Remove old entries
      ["ZREMRANGEBYSCORE", redis_key, "-inf", window_start],
      # Add current request with unique member
      ["ZADD", redis_key, now, "#{now}:#{System.unique_integer()}"],
      # Count requests in window
      ["ZCARD", redis_key],
      # Set expiry
      ["EXPIRE", redis_key, @window_size + 1]
    ]

    case Redis.pipeline(commands) do
      {:ok, [_, _, count, _]} ->
        if count <= limit do
          :ok
        else
          {:error, :rate_limit_exceeded}
        end

      {:error, reason} ->
        # Fail open if Redis is down, but log error
        require Logger
        Logger.error("Rate limiter Redis error: #{inspect(reason)}")
        :ok
    end
  end
end
