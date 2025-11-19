defmodule Mcp.Secrets.CredentialManager do
  @moduledoc """
  Credential management service.
  Handles secure storage and rotation of application credentials.
  """

  use GenServer
  require Logger

  alias Mcp.Secrets.EncryptionService

  @credential_types [:api_key, :database, :oauth, :certificate, :service_account]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Secrets CredentialManager")
    {:ok, %{credentials: %{}}}
  end

  def store_credential(name, credential_data, type, opts \\ []) do
    GenServer.call(__MODULE__, {:store_credential, name, credential_data, type, opts})
  end

  def get_credential(name, opts \\ []) do
    GenServer.call(__MODULE__, {:get_credential, name, opts})
  end

  def rotate_credential(name, opts \\ []) do
    GenServer.call(__MODULE__, {:rotate_credential, name, opts})
  end

  def delete_credential(name, opts \\ []) do
    GenServer.call(__MODULE__, {:delete_credential, name, opts})
  end

  def list_credentials(opts \\ []) do
    GenServer.call(__MODULE__, {:list_credentials, opts})
  end

  def validate_credential(name, validation_data, opts \\ []) do
    GenServer.call(__MODULE__, {:validate_credential, name, validation_data, opts})
  end

  @impl true
  def handle_call({:store_credential, name, credential_data, type, opts}, _from, state) do
    if type in @credential_types do
      tenant_id = Keyword.get(opts, :tenant_id, "global")
      full_name = "#{tenant_id}:#{name}"

      credential = %{
        name: full_name,
        type: type,
        data: credential_data,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        version: 1,
        tenant_id: tenant_id
      }

      # Encrypt sensitive credential data
      case EncryptionService.encrypt_field(
             Jason.encode!(credential_data),
             Keyword.merge(opts, key_id: "credential_storage")
           ) do
        {:ok, encrypted_data} ->
          encrypted_credential = %{credential | data: encrypted_data}
          new_credentials = Map.put(state.credentials, full_name, encrypted_credential)
          new_state = %{state | credentials: new_credentials}

          Logger.info("Stored credential: #{full_name} (type: #{type})")
          {:reply, {:ok, encrypted_credential}, new_state}

        error ->
          Logger.error("Failed to encrypt credential data: #{inspect(error)}")
          {:reply, error, state}
      end
    else
      {:reply, {:error, :invalid_credential_type}, state}
    end
  end

  @impl true
  def handle_call({:get_credential, name, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_name = "#{tenant_id}:#{name}"

    case Map.get(state.credentials, full_name) do
      nil ->
        {:reply, {:error, :credential_not_found}, state}

      credential ->
        # Decrypt credential data
        with {:ok, decrypted_data} <-
               EncryptionService.decrypt_field(
                 credential.data,
                 Keyword.merge(opts, key_id: "credential_storage")
               ),
             {:ok, credential_data} <- Jason.decode(decrypted_data) do
          decrypted_credential = %{credential | data: credential_data}
          {:reply, {:ok, decrypted_credential}, state}
        else
          error ->
            Logger.error("Failed to decrypt credential data: #{inspect(error)}")
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:rotate_credential, name, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_name = "#{tenant_id}:#{name}"

    case Map.get(state.credentials, full_name) do
      nil ->
        {:reply, {:error, :credential_not_found}, state}

      credential ->
        # In a real implementation, this would generate new credentials
        # For now, just update the version and timestamp
        rotated_credential = %{
          credential
          | updated_at: DateTime.utc_now(),
            version: credential.version + 1
        }

        new_credentials = Map.put(state.credentials, full_name, rotated_credential)
        new_state = %{state | credentials: new_credentials}

        Logger.info("Rotated credential: #{full_name} to version #{rotated_credential.version}")
        {:reply, {:ok, rotated_credential}, new_state}
    end
  end

  @impl true
  def handle_call({:delete_credential, name, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_name = "#{tenant_id}:#{name}"

    case Map.pop(state.credentials, full_name) do
      {nil, _} ->
        {:reply, {:error, :credential_not_found}, state}

      {_credential, new_credentials} ->
        new_state = %{state | credentials: new_credentials}
        Logger.info("Deleted credential: #{full_name}")
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:list_credentials, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    credentials =
      Enum.filter(state.credentials, fn {_name, cred} ->
        cred.tenant_id == tenant_id
      end)

    credential_list =
      Enum.map(credentials, fn {name, cred} ->
        %{
          name: name,
          type: cred.type,
          created_at: cred.created_at,
          updated_at: cred.updated_at,
          version: cred.version
        }
      end)

    {:reply, {:ok, credential_list}, state}
  end

  @impl true
  def handle_call({:validate_credential, name, validation_data, opts}, _from, state) do
    case get_credential(name, opts) do
      {:ok, credential} ->
        # Perform validation based on credential type
        result = validate_credential_by_type(credential, validation_data)
        {:reply, result, state}

      error ->
        {:reply, error, state}
    end
  end

  defp validate_credential_by_type(
         %{type: :api_key, data: %{"key" => stored_key}},
         validation_data
       ) do
    case Map.get(validation_data, "key") do
      ^stored_key -> {:ok, :valid}
      _ -> {:ok, :invalid}
    end
  end

  defp validate_credential_by_type(
         %{type: :database, data: %{"host" => host, "database" => db}},
         validation_data
       ) do
    # In a real implementation, would attempt database connection
    validation_host = Map.get(validation_data, "host")
    validation_db = Map.get(validation_data, "database")

    cond do
      host != validation_host -> {:ok, :host_mismatch}
      db != validation_db -> {:ok, :database_mismatch}
      true -> {:ok, :valid}
    end
  end

  defp validate_credential_by_type(_credential, _validation_data) do
    # Default validation - would implement specific logic for each type
    {:ok, :valid}
  end
end
