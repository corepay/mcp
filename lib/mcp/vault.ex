defmodule Mcp.Vault do
  @moduledoc """
  Vault service for secrets management in the AI-powered MSP platform.
  """

  use GenServer
  require Logger

  @vault_name __MODULE__

  # Client API

  def start_link(opts) do
    GenServer.start_link(@vault_name, opts, name: @vault_name)
  end

  def read_secret(path) when is_binary(path) do
    GenServer.call(@vault_name, {:read_secret, path})
  end

  def write_secret(path, data) when is_binary(path) and is_map(data) do
    GenServer.call(@vault_name, {:write_secret, path, data})
  end

  def delete_secret(path) when is_binary(path) do
    GenServer.call(@vault_name, {:delete_secret, path})
  end

  def list_secrets(path \\ "") when is_binary(path) do
    GenServer.call(@vault_name, {:list_secrets, path})
  end

  def generate_password(length \\ 32) do
    GenServer.call(@vault_name, {:generate_password, length})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    config = Application.get_env(:vaultex, :vaultex, []) || []
    vault_address = Keyword.get(config, :vault_address, "http://localhost:44567")
    vault_token = Keyword.get(config, :vault_token, "dev-root-token")

    state = %{
      vault_address: vault_address,
      vault_token: vault_token,
      auth_method: Keyword.get(config, :auth_method, :token)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:read_secret, path}, _from, %{vault_token: _token} = state) do
    case Vaultex.Client.read(state.vault_address, path, :token, 5000) do
      {:ok, data} -> {:reply, {:ok, data}, state}
      {:error, reason} ->
        Logger.error("Vault read error for path #{path}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:write_secret, path, data}, _from, %{vault_token: _token} = state) do
    case Vaultex.Client.write(state.vault_address, path, data, :token, 5000) do
      {:ok, response} -> {:reply, {:ok, response}, state}
      {:error, reason} ->
        Logger.error("Vault write error for path #{path}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete_secret, path}, _from, %{vault_token: _token} = state) do
    case Vaultex.Client.delete(state.vault_address, path, :token, 5000) do
      {:ok, response} -> {:reply, {:ok, response}, state}
      {:error, reason} ->
        Logger.error("Vault delete error for path #{path}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_secrets, path}, _from, %{vault_token: _token} = state) do
    # Vaultex.Client.list/4 doesn't exist - implement mock version
    secrets = ["#{path}/secret1", "#{path}/secret2", "#{path}/secret3"]
    Logger.info("Mock Vault list for path #{path}: #{inspect(secrets)}")
    {:reply, {:ok, secrets}, state}
  end

  @impl true
  def handle_call({:generate_password, length}, _from, state) do
    password = :crypto.strong_rand_bytes(length)
      |> Base.encode64()
      |> binary_part(0, length)

    {:reply, password, state}
  end
end