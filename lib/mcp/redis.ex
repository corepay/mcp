defmodule Mcp.Redis do
  @moduledoc """
  Redis connection and caching service for the AI-powered MSP platform.
  """

  use GenServer
  require Logger

  @redis_name __MODULE__

  # Client API

  def start_link(opts) do
    GenServer.start_link(@redis_name, opts, name: @redis_name)
  end

  def get(key) when is_binary(key) do
    GenServer.call(@redis_name, {:get, key})
  end

  def set(key, value, ttl_seconds \\ nil) when is_binary(key) do
    GenServer.call(@redis_name, {:set, key, value, ttl_seconds})
  end

  def delete(key) when is_binary(key) do
    GenServer.call(@redis_name, {:delete, key})
  end

  def exists?(key) when is_binary(key) do
    GenServer.call(@redis_name, {:exists, key})
  end

  def clear_pattern(pattern) when is_binary(pattern) do
    GenServer.call(@redis_name, {:clear_pattern, pattern})
  end

  def pipeline(commands) when is_list(commands) do
    GenServer.call(@redis_name, {:pipeline, commands})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    config = Application.get_env(:mcp, Mcp.Redis, [])
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 48_234)
    database = Keyword.get(config, :database, 0)
    reconnect_interval = Keyword.get(config, :reconnect_interval, :timer.seconds(5))

    {:ok, conn} = Redix.start_link(host: host, port: port, database: database)

    state = %{
      conn: conn,
      reconnect_interval: reconnect_interval
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, %{conn: conn} = state) do
    case Redix.command(conn, ["GET", key]) do
      {:ok, nil} ->
        {:reply, {:ok, nil}, state}

      {:ok, value} ->
        {:reply, {:ok, value}, state}

      {:error, reason} ->
        Logger.error("Redis GET error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:set, key, value, ttl_seconds}, _from, %{conn: conn} = state) do
    command =
      case ttl_seconds do
        nil -> ["SET", key, value]
        _ttl -> ["SET", key, value, "EX", to_string(ttl_seconds)]
      end

    case Redix.command(conn, command) do
      {:ok, "OK"} ->
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Redis SET error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete, key}, _from, %{conn: conn} = state) do
    case Redix.command(conn, ["DEL", key]) do
      {:ok, count} ->
        {:reply, {:ok, count}, state}

      {:error, reason} ->
        Logger.error("Redis DELETE error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:exists, key}, _from, %{conn: conn} = state) do
    case Redix.command(conn, ["EXISTS", key]) do
      {:ok, 0} ->
        {:reply, false, state}

      {:ok, 1} ->
        {:reply, true, state}

      {:error, reason} ->
        Logger.error("Redis EXISTS error for key #{key}: #{inspect(reason)}")
        {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:clear_pattern, pattern}, _from, %{conn: conn} = state) do
    case Redix.command(conn, ["KEYS", pattern]) do
      {:ok, []} ->
        {:reply, {:ok, 0}, state}

      {:ok, keys} ->
        case Redix.command(conn, ["DEL" | keys]) do
          {:ok, count} ->
            {:reply, {:ok, count}, state}

          {:error, reason} ->
            Logger.error("Redis DELETE error for pattern #{pattern}: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        Logger.error("Redis KEYS error for pattern #{pattern}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:pipeline, commands}, _from, %{conn: conn} = state) do
    case Redix.pipeline(conn, commands) do
      {:ok, results} ->
        {:reply, {:ok, results}, state}

      {:error, reason} ->
        Logger.error("Redis pipeline error: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  # Connection handling
  @impl true
  def handle_info({:redix_disconnect, _reason}, state) do
    Logger.warning("Redis disconnected, attempting reconnect...")
    {:noreply, state}
  end

  @impl true
  def handle_info(:reconnect, state) do
    case Redix.start_link(
           host: state.config.host,
           port: state.config.port,
           database: state.config.database
         ) do
      {:ok, conn} ->
        Logger.info("Redis reconnected successfully")
        {:noreply, %{state | conn: conn}}

      {:error, reason} ->
        Logger.error("Redis reconnection failed: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, state.reconnect_interval)
        {:noreply, state}
    end
  end
end
