defmodule McpCache.RedisClient do
  @moduledoc """
  Redis client wrapper with connection pooling and tenant isolation.
  Handles caching operations for AI-powered MSP platform.
  """

  use GenServer
  require Logger

  # 1 hour
  @default_ttl 3600

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Cache RedisClient")
    {:ok, %{connections: %{}}}
  end

  def set(key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:set, key, value, opts})
  end

  def get(key, opts \\ []) do
    GenServer.call(__MODULE__, {:get, key, opts})
  end

  def delete(key, opts \\ []) do
    GenServer.call(__MODULE__, {:delete, key, opts})
  end

  def exists?(key, opts \\ []) do
    GenServer.call(__MODULE__, {:exists, key, opts})
  end

  def set_with_ttl(key, value, ttl, opts \\ []) do
    GenServer.call(__MODULE__, {:set_with_ttl, key, value, ttl, opts})
  end

  def increment(key, amount \\ 1, opts \\ []) do
    GenServer.call(__MODULE__, {:increment, key, amount, opts})
  end

  def get_and_set(key, value, opts \\ []) do
    case get(key, opts) do
      {:ok, old_value} -> {:ok, old_value, set(key, value, opts)}
      {:error, :not_found} -> {:ok, nil, set(key, value, opts)}
      error -> error
    end
  end

  def clear_pattern(pattern, opts \\ []) do
    GenServer.call(__MODULE__, {:clear_pattern, pattern, opts})
  end

  @impl true
  def handle_call({:set, key, value, opts}, _from, state) do
    tenant_key = build_tenant_key(key, opts)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    serialized_value = serialize_value(value)

    command =
      if ttl > 0 do
        ["SETEX", tenant_key, to_string(ttl), serialized_value]
      else
        ["SET", tenant_key, serialized_value]
      end

    case Redix.command(:redix_cache, command) do
      {:ok, _result} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get, key, opts}, _from, state) do
    tenant_key = build_tenant_key(key, opts)

    case Redix.command(:redix_cache, ["GET", tenant_key]) do
      {:ok, nil} -> {:reply, {:error, :not_found}, state}
      {:ok, value} -> {:reply, {:ok, deserialize_value(value)}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete, key, opts}, _from, state) do
    tenant_key = build_tenant_key(key, opts)

    case Redix.command(:redix_cache, ["DEL", tenant_key]) do
      {:ok, _count} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:exists, key, opts}, _from, state) do
    tenant_key = build_tenant_key(key, opts)

    case Redix.command(:redix_cache, ["EXISTS", tenant_key]) do
      {:ok, 0} -> {:reply, false, state}
      {:ok, 1} -> {:reply, true, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:set_with_ttl, key, value, ttl, opts}, from, state) do
    new_opts = Keyword.put(opts, :ttl, ttl)
    handle_call({:set, key, value, new_opts}, from, state)
  end

  @impl true
  def handle_call({:increment, key, amount, opts}, _from, state) do
    tenant_key = build_tenant_key(key, opts)

    case Redix.command(:redix_cache, ["INCRBY", tenant_key, to_string(amount)]) do
      {:ok, result} -> {:reply, {:ok, String.to_integer(result)}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:clear_pattern, pattern, opts}, _from, state) do
    search_pattern = build_tenant_key(pattern, opts)

    with {:ok, keys} when is_list(keys) <- Redix.command(:redix_cache, ["KEYS", search_pattern]),
         {:ok, _count} <- delete_keys_if_exists(keys) do
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp build_tenant_key(key, opts) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    "tenant:#{tenant_id}:#{key}"
  end

  defp serialize_value(value) do
    :erlang.term_to_binary(value)
  end

  defp deserialize_value(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary)
  end

  defp delete_keys_if_exists([]), do: {:ok, []}

  defp delete_keys_if_exists(keys) do
    Redix.command(:redix_cache, ["DEL" | keys])
  end
end
