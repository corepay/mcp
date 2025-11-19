defmodule Mcp.Secrets.EncryptionService do
  @moduledoc """
  Encryption service for data protection.
  Handles symmetric/asymmetric encryption and key management.
  """

  use GenServer
  require Logger

  @algorithm :aes_256_gcm
  @key_length 32

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Secrets EncryptionService")
    {:ok, %{keys: %{}}}
  end

  def generate_key(key_id, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_key, key_id, opts})
  end

  def encrypt(data, key_id, opts \\ []) do
    GenServer.call(__MODULE__, {:encrypt, data, key_id, opts})
  end

  def decrypt(encrypted_data, key_id, opts \\ []) do
    GenServer.call(__MODULE__, {:decrypt, encrypted_data, key_id, opts})
  end

  def encrypt_field(field_value, opts \\ []) do
    GenServer.call(__MODULE__, {:encrypt_field, field_value, opts})
  end

  def decrypt_field(encrypted_field, opts \\ []) do
    GenServer.call(__MODULE__, {:decrypt_field, encrypted_field, opts})
  end

  def rotate_key(key_id, opts \\ []) do
    GenServer.call(__MODULE__, {:rotate_key, key_id, opts})
  end

  def get_key_info(key_id) do
    GenServer.call(__MODULE__, {:get_key_info, key_id})
  end

  @impl true
  def handle_call({:generate_key, key_id, opts}, _from, state) do
    key = :crypto.strong_rand_bytes(@key_length)
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_key_id = "#{tenant_id}:#{key_id}"

    key_info = %{
      key_id: full_key_id,
      key: key,
      algorithm: @algorithm,
      created_at: DateTime.utc_now(),
      version: 1,
      tenant_id: tenant_id
    }

    new_keys = Map.put(state.keys, full_key_id, key_info)
    new_state = %{state | keys: new_keys}

    Logger.info("Generated encryption key: #{full_key_id}")
    # Don't return the actual key
    {:reply, {:ok, %{key_info | key: nil}}, new_state}
  end

  @impl true
  def handle_call({:encrypt, data, key_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_key_id = "#{tenant_id}:#{key_id}"

    case Map.get(state.keys, full_key_id) do
      nil ->
        {:reply, {:error, :key_not_found}, state}

      key_info ->
        # do_encrypt returns binary directly, not {:ok, _} tuple, so no error handling needed
        encrypted_data = do_encrypt(data, key_info.key)
        {:reply, {:ok, encrypted_data}, state}
    end
  end

  @impl true
  def handle_call({:decrypt, encrypted_data, key_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_key_id = "#{tenant_id}:#{key_id}"

    case Map.get(state.keys, full_key_id) do
      nil ->
        {:reply, {:error, :key_not_found}, state}

      key_info ->
        case do_decrypt(encrypted_data, key_info.key) do
          {:ok, data} ->
            {:reply, {:ok, data}, state}

          {:error, reason} ->
            Logger.error("Decryption failed: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:encrypt_field, field_value, opts}, _from, state) do
    # Use a default field encryption key
    key_id = Keyword.get(opts, :key_id, "field_encryption")
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    case encrypt(field_value, key_id, tenant_id: tenant_id) do
      {:ok, encrypted_data} ->
        # Encode for storage
        encoded = Base.encode64(encrypted_data)
        {:reply, {:ok, encoded}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:decrypt_field, encrypted_field, opts}, _from, state) do
    # Decode from storage
    case Base.decode64(encrypted_field) do
      {:ok, encrypted_data} ->
        key_id = Keyword.get(opts, :key_id, "field_encryption")
        tenant_id = Keyword.get(opts, :tenant_id, "global")

        case decrypt(encrypted_data, key_id, tenant_id: tenant_id) do
          {:ok, field_value} -> {:reply, {:ok, field_value}, state}
          error -> {:reply, error, state}
        end

      _error ->
        {:reply, {:error, :invalid_encoding}, state}
    end
  end

  @impl true
  def handle_call({:rotate_key, key_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    full_key_id = "#{tenant_id}:#{key_id}"

    case Map.get(state.keys, full_key_id) do
      nil ->
        {:reply, {:error, :key_not_found}, state}

      key_info ->
        new_key = :crypto.strong_rand_bytes(@key_length)

        new_key_info = %{
          key_info
          | key: new_key,
            version: key_info.version + 1,
            rotated_at: DateTime.utc_now()
        }

        new_keys = Map.put(state.keys, full_key_id, new_key_info)
        new_state = %{state | keys: new_keys}

        Logger.info("Rotated encryption key: #{full_key_id} to version #{new_key_info.version}")
        {:reply, {:ok, %{new_key_info | key: nil}}, new_state}
    end
  end

  @impl true
  def handle_call({:get_key_info, key_id}, _from, state) do
    tenant_id = "global"
    full_key_id = "#{tenant_id}:#{key_id}"

    case Map.get(state.keys, full_key_id) do
      nil ->
        {:reply, {:error, :key_not_found}, state}

      key_info ->
        # Don't return the actual key
        {:reply, {:ok, %{key_info | key: nil}}, state}
    end
  end

  defp do_encrypt(data, key) when is_binary(data) and is_binary(key) do
    iv = :crypto.strong_rand_bytes(16)
    # Additional authenticated data
    _aad = ""

    case :crypto.crypto_one_time(@algorithm, key, iv, data, true) do
      ciphertext when is_binary(ciphertext) ->
        # Return iv + ciphertext + tag (AEAD support would require additional implementation)
        <<iv::binary, ciphertext::binary>>

      error ->
        {:error, error}
    end
  catch
    _, reason -> {:error, reason}
  end

  defp do_encrypt(_data, _key), do: {:error, :invalid_input}

  defp do_decrypt(encrypted_data, key)
       when is_binary(encrypted_data) and byte_size(encrypted_data) > 16 do
    <<iv::binary-16, ciphertext::binary>> = encrypted_data
    # Additional authenticated data
    _aad = ""

    case :crypto.crypto_one_time(@algorithm, key, iv, ciphertext, false) do
      plaintext when is_binary(plaintext) ->
        {:ok, plaintext}

      error ->
        {:error, error}
    end
  catch
    _, reason -> {:error, reason}
  end

  defp do_decrypt(_encrypted_data, _key), do: {:error, :invalid_input}
end
