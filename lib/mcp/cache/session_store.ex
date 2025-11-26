defmodule Mcp.Cache.SessionStore do
  @moduledoc """
  Enhanced session storage service using Redis with multi-tenant support.

  Handles user sessions with tenant isolation, cross-tenant access,
  and comprehensive security features for multi-tenant applications.
  """

  use GenServer
  require Logger

  alias Mcp.Cache.RedisClient

  # 24 hours
  @session_ttl 86_400

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

  @doc """
  Create a cross-tenant session that allows user access across multiple tenants.

  This enables users who belong to multiple tenants to maintain a single session
  while accessing different tenant contexts.
  """
  @spec create_cross_tenant_session(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_cross_tenant_session(session_id, user_data, opts \\ []) do
    GenServer.call(__MODULE__, {:create_cross_tenant_session, session_id, user_data, opts})
  end

  @doc """
  Switch a user's session context to a different tenant.

  Updates the current tenant context for an existing session while maintaining
  authentication state.
  """
  @spec switch_tenant_context(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def switch_tenant_context(session_id, tenant_id, opts \\ []) do
    GenServer.call(__MODULE__, {:switch_tenant_context, session_id, tenant_id, opts})
  end

  @doc """
  Get all tenants a user has access to based on their sessions.

  Returns list of tenant IDs where the user has active sessions.
  """
  @spec get_user_accessible_tenants(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def get_user_accessible_tenants(user_id) do
    GenServer.call(__MODULE__, {:get_user_accessible_tenants, user_id})
  end

  @doc """
  Validate that a session has access to a specific tenant.

  Checks if the user session is authorized to access the given tenant.
  """
  @spec validate_tenant_access(String.t(), String.t()) :: {:ok, boolean()} | {:error, term()}
  def validate_tenant_access(session_id, tenant_id) do
    GenServer.call(__MODULE__, {:validate_tenant_access, session_id, tenant_id})
  end

  @doc """
  Clean up expired or invalid cross-tenant sessions.

  Maintenance operation to remove stale sessions and free up resources.
  """
  @spec cleanup_cross_tenant_sessions() :: {:ok, map()} | {:error, term()}
  def cleanup_cross_tenant_sessions do
    GenServer.call(__MODULE__, :cleanup_cross_tenant_sessions)
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

    case RedisClient.set("session:#{session_id}", session_data, cache_opts) do
      :ok ->
        # Also store in user session index for management
        user_sessions_key = "user_sessions:#{user_data.user_id}"

        case RedisClient.get(user_sessions_key, cache_opts) do
          {:ok, sessions} ->
            updated_sessions = [session_id | sessions] |> Enum.uniq()
            RedisClient.set(user_sessions_key, updated_sessions, cache_opts)

          {:error, :not_found} ->
            RedisClient.set(user_sessions_key, [session_id], cache_opts)

          _ ->
            :ok
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

    case RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        # Update last accessed time
        updated_session = %{session_data | last_accessed: DateTime.utc_now()}
        RedisClient.set("session:#{session_id}", updated_session, cache_opts)
        {:reply, {:ok, updated_session}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:update_session, session_id, user_data, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        updated_session = %{
          session_data
          | data: Map.merge(session_data.data, user_data),
            last_accessed: DateTime.utc_now()
        }

        case RedisClient.set("session:#{session_id}", updated_session, cache_opts) do
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

    case RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        # Remove from user session index
        user_sessions_key = "user_sessions:#{session_data.user_id}"

        case RedisClient.get(user_sessions_key, cache_opts) do
          {:ok, sessions} ->
            updated_sessions = List.delete(sessions, session_id)
            update_user_sessions_cache(user_sessions_key, updated_sessions, cache_opts)

          _ ->
            :ok
        end

        # Delete the session
        RedisClient.delete("session:#{session_id}", cache_opts)
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:session_exists, session_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case RedisClient.exists?("session:#{session_id}", cache_opts) do
      exists -> {:reply, exists, state}
    end
  end

  @impl true
  def handle_call({:refresh_session, session_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    ttl = Keyword.get(opts, :ttl, @session_ttl)
    cache_opts = [tenant_id: tenant_id, ttl: ttl]

    case RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} ->
        updated_session = %{session_data | last_accessed: DateTime.utc_now()}
        RedisClient.set("session:#{session_id}", updated_session, cache_opts)
        {:reply, {:ok, updated_session}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:list_user_sessions, user_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    cache_opts = [tenant_id: tenant_id]

    case RedisClient.get("user_sessions:#{user_id}", cache_opts) do
      {:ok, session_ids} ->
        sessions =
          session_ids
          |> Enum.map(&get_session_data(&1, cache_opts))
          |> Enum.reject(&is_nil/1)

        {:reply, {:ok, sessions}, state}

      error ->
        {:reply, error, state}
    end
  end

  defp get_session_data(session_id, cache_opts) do
    case RedisClient.get("session:#{session_id}", cache_opts) do
      {:ok, session_data} -> session_data
      {:error, :not_found} -> nil
    end
  end

  defp update_user_sessions_cache(key, sessions, cache_opts) do
    if sessions == [] do
      RedisClient.delete(key, cache_opts)
    else
      RedisClient.set(key, sessions, cache_opts)
    end
  end
end
