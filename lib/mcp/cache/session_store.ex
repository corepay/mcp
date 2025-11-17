defmodule McpCache.SessionStore do
  @moduledoc """
  Session storage service using Redis.
  Handles user sessions with tenant isolation and security.
  """

  use GenServer
  require Logger

  @session_ttl 86_400  # 24 hours

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Cache SessionStore")
    {:ok, %{}}
  end

  def create_session(session_id, user_data, opts \\ []) do
    GenServer.call(__MODULE__, {:create_session, session_id, user_data, opts})
  end

  def get_session(session_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_session, session_id, opts})
  end

  def update_session(session_id, user_data, opts \\ []) do
    GenServer.call(__MODULE__, {:update_session, session_id, user_data, opts})
  end

  def delete_session(session_id, opts \\ []) do
    GenServer.call(__MODULE__, {:delete_session, session_id, opts})
  end

  def session_exists?(session_id, opts \\ []) do
    GenServer.call(__MODULE__, {:session_exists, session_id, opts})
  end

  def refresh_session(session_id, opts \\ []) do
    GenServer.call(__MODULE__, {:refresh_session, session_id, opts})
  end

  def list_user_sessions(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:list_user_sessions, user_id, opts})
  end

  @impl true
  def handle_call({:create_session, session_id, user_data, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    ttl = Keyword.get(opts, :ttl, @session_ttl)

    session_data = %{
      session_id: session_id,
      user_id: user_data.user_id,
      tenant_id: tenant_id,
      data: user_data,
      created_at: DateTime.utc_now(),
      last_accessed: DateTime.utc_now(),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent)
    }

    cache_opts = [tenant_id: tenant_id, ttl: ttl]

    case McpCache.RedisClient.set("session:#{session_id}", session_data, cache_opts) do
      :ok ->
        # Also store in user session index for management
        user_sessions_key = "user_sessions:#{user_data.user_id}"
        case McpCache.RedisClient.get(user_sessions_key, cache_opts) do
          {:ok, sessions} ->
            updated_sessions = [session_id | sessions] |> Enum.uniq()
            McpCache.RedisClient.set(user_sessions_key, updated_sessions, cache_opts)
          {:error, :not_found} ->
            McpCache.RedisClient.set(user_sessions_key, [session_id], cache_opts)
          _ -> :ok
        end
        {:reply, {:ok, session_data}, state}
      error ->
        Logger.error("Failed to create session: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_session, session_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case McpCache.RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        # Update last accessed time
        updated_session = %{session_data | last_accessed: DateTime.utc_now()}
        McpCache.RedisClient.set("session:#{session_id}", updated_session, cache_opts)
        {:reply, {:ok, updated_session}, state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:update_session, session_id, user_data, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case McpCache.RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        updated_session = %{
          session_data |
          data: Map.merge(session_data.data, user_data),
          last_accessed: DateTime.utc_now()
        }
        case McpCache.RedisClient.set("session:#{session_id}", updated_session, cache_opts) do
          :ok -> {:reply, {:ok, updated_session}, state}
          error -> {:reply, error, state}
        end
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete_session, session_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case McpCache.RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        # Remove from user session index
        user_sessions_key = "user_sessions:#{session_data.user_id}"
        case McpCache.RedisClient.get(user_sessions_key, cache_opts) do
          {:ok, sessions} ->
            updated_sessions = List.delete(sessions, session_id)
            update_user_sessions_cache(user_sessions_key, updated_sessions, cache_opts)
          _ -> :ok
        end

        # Delete the session
        McpCache.RedisClient.delete("session:#{session_id}", cache_opts)
        {:reply, :ok, state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:session_exists, session_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case McpCache.RedisClient.exists?("session:#{session_id}", cache_opts) do
      exists -> {:reply, exists, state}
    end
  end

  @impl true
  def handle_call({:refresh_session, session_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    ttl = Keyword.get(opts, :ttl, @session_ttl)
    cache_opts = [tenant_id: tenant_id, ttl: ttl]

    case McpCache.RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        updated_session = %{session_data | last_accessed: DateTime.utc_now()}
        McpCache.RedisClient.set("session:#{session_id}", updated_session, cache_opts)
        {:reply, {:ok, updated_session}, state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:list_user_sessions, user_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case McpCache.RedisClient.get("user_sessions:#{user_id}", cache_opts) do
      {:ok, session_ids} ->
        sessions = session_ids
                   |> Enum.map(&get_session_data(&1, cache_opts))
                   |> Enum.reject(&is_nil/1)
        {:reply, {:ok, sessions}, state}
      error ->
        {:reply, error, state}
    end
  end

  defp get_session_data(session_id, cache_opts) do
    case McpCache.RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} -> session_data
      {:error, :not_found} -> nil
    end
  end

  defp update_user_sessions_cache(key, sessions, cache_opts) do
    if sessions == [] do
      McpCache.RedisClient.delete(key, cache_opts)
    else
      McpCache.RedisClient.set(key, sessions, cache_opts)
    end
  end
end