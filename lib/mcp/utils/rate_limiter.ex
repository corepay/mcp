defmodule Mcp.Utils.RateLimiter do
  @moduledoc """
  A simple sliding window rate limiter using Redis.
  """
  
  alias Mcp.Redix, as: Redis

  # Default window size in seconds (e.g., 60 seconds)
  @window_size 60

  @doc """
  Checks if the given key has exceeded the limit within the window.
  Returns :ok if allowed, {:error, :rate_limit_exceeded} if not.
  """
  def check_limit(key, limit) do
    now = System.system_time(:millisecond)
    window_start = now - (@window_size * 1000)
    
    # Use a sorted set to store timestamps of requests
    redis_key = "rate_limit:#{key}"
    
    # Transaction to ensure atomicity
    commands = [
      ["ZREMRANGEBYSCORE", redis_key, "-inf", window_start], # Remove old entries
      ["ZADD", redis_key, now, now], # Add current request
      ["ZCARD", redis_key], # Count requests in window
      ["EXPIRE", redis_key, @window_size + 1] # Set expiry
    ]

    case Redix.pipeline(Redis, commands) do
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
