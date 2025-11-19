defmodule Mcp.Secrets.VaultClient do
  @moduledoc """
  Vault client for secrets management.
  Handles secure storage and retrieval of sensitive data.
  """

  use GenServer
  require Logger

  # @vault_addr System.get_env("VAULT_ADDR", "http://localhost:48200")  # Currently unused
  @vault_token System.get_env("VAULT_TOKEN", "mock-token")

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Secrets VaultClient")
    {:ok, %{authenticated: false, token: @vault_token}}
  end

  def authenticate(token \\ @vault_token) do
    GenServer.call(__MODULE__, {:authenticate, token})
  end

  def get_secret(path, opts \\ []) do
    GenServer.call(__MODULE__, {:get_secret, path, opts})
  end

  def set_secret(path, value, opts \\ []) do
    GenServer.call(__MODULE__, {:set_secret, path, value, opts})
  end

  def delete_secret(path, opts \\ []) do
    GenServer.call(__MODULE__, {:delete_secret, path, opts})
  end

  def list_secrets(path_prefix, opts \\ []) do
    GenServer.call(__MODULE__, {:list_secrets, path_prefix, opts})
  end

  def create_tenant_secrets(tenant_id, secrets, opts \\ []) do
    GenServer.call(__MODULE__, {:create_tenant_secrets, tenant_id, secrets, opts})
  end

  def get_tenant_secrets(tenant_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_tenant_secrets, tenant_id, opts})
  end

  @impl true
  def handle_call({:authenticate, token}, _from, state) do
    # In real implementation, would authenticate with Vault
    # For now, simulate authentication
    Logger.info("Authenticating with Vault")
    new_state = %{state | authenticated: true, token: token}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_secret, path, opts}, _from, state) do
    if state.authenticated do
      tenant_id = Keyword.get(opts, :tenant_id)
      full_path = build_tenant_path(path, tenant_id)

      # Mock implementation - in real scenario would call Vault API
      case get_mock_secret(full_path) do
        {:ok, value} -> {:reply, {:ok, value}, state}
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_authenticated}, state}
    end
  end

  @impl true
  def handle_call({:set_secret, path, value, opts}, _from, state) do
    if state.authenticated do
      tenant_id = Keyword.get(opts, :tenant_id)
      full_path = build_tenant_path(path, tenant_id)

      # Mock implementation - in real scenario would call Vault API
      # set_mock_secret always returns :ok, so no error handling needed
      set_mock_secret(full_path, value)
      {:reply, :ok, state}
    else
      {:reply, {:error, :not_authenticated}, state}
    end
  end

  @impl true
  def handle_call({:delete_secret, path, opts}, _from, state) do
    if state.authenticated do
      tenant_id = Keyword.get(opts, :tenant_id)
      full_path = build_tenant_path(path, tenant_id)

      # Mock implementation - in real scenario would call Vault API
      # delete_mock_secret always returns :ok, so no error handling needed
      delete_mock_secret(full_path)
      {:reply, :ok, state}
    else
      {:reply, {:error, :not_authenticated}, state}
    end
  end

  @impl true
  def handle_call({:list_secrets, path_prefix, opts}, _from, state) do
    if state.authenticated do
      tenant_id = Keyword.get(opts, :tenant_id)
      full_path = build_tenant_path(path_prefix, tenant_id)

      # Mock implementation
      secrets = list_mock_secrets(full_path)
      {:reply, {:ok, secrets}, state}
    else
      {:reply, {:error, :not_authenticated}, state}
    end
  end

  @impl true
  def handle_call({:create_tenant_secrets, tenant_id, secrets, opts}, _from, state) do
    if state.authenticated do
      create_tenant_secrets_authenticated(tenant_id, secrets, opts, state)
    else
      {:reply, {:error, :not_authenticated}, state}
    end
  end

  @impl true
  def handle_call({:get_tenant_secrets, tenant_id, opts}, _from, state) do
    if state.authenticated do
      path_prefix = "tenants/#{tenant_id}"

      with {:ok, secret_paths} <-
             list_secrets(path_prefix, Keyword.put(opts, :tenant_id, tenant_id)),
           secrets <-
             secret_paths
             |> Enum.map(&extract_secret_value(&1, opts))
             |> Enum.filter(&(&1 != nil)) do
        {:reply, {:ok, secrets}, state}
      else
        error -> {:reply, error, state}
      end
    else
      {:reply, {:error, :not_authenticated}, state}
    end
  end

  defp create_tenant_secrets_authenticated(tenant_id, secrets, _opts, state) do
    results =
      Enum.map(secrets, fn {key, value} ->
        path = "tenants/#{tenant_id}/#{key}"
        full_path = build_tenant_path(path, tenant_id)

        case set_mock_secret(full_path, value) do
          :ok -> {:ok, key}
          error -> {:error, {key, error}}
        end
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Created #{successful}/#{length(secrets)} tenant secrets for #{tenant_id}")

    {:reply, {:ok, results}, state}
  end

  defp build_tenant_path(path, nil), do: path

  defp build_tenant_path(path, tenant_id) do
    if String.starts_with?(path, "tenants/") do
      path
    else
      "tenants/#{tenant_id}/#{path}"
    end
  end

  # Mock implementations - in real scenario would call Vault HTTP API
  defp get_mock_secret(_path) do
    # Simulate some mock secrets
    case :rand.uniform(3) do
      1 -> {:ok, %{"value" => "mock-secret-value-1"}}
      2 -> {:ok, %{"value" => "mock-secret-value-2"}}
      3 -> {:error, :not_found}
    end
  end

  defp set_mock_secret(_path, _value) do
    # Simulate successful secret storage
    :ok
  end

  defp delete_mock_secret(_path) do
    # Simulate successful secret deletion
    :ok
  end

  defp list_mock_secrets(_path_prefix) do
    # Simulate secret listing
    ["secret1", "secret2", "database_credentials", "api_keys"]
  end

  defp extract_secret_value(path, opts) do
    case get_secret(path, opts) do
      {:ok, value} -> {Path.basename(path), value}
      _ -> nil
    end
  end
end
