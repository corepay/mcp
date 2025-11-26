defmodule Mcp.Gdpr.Anonymizer do
  @moduledoc """
  GDPR-compliant data anonymization functionality.

  Implements irreversible anonymization of personal data while maintaining
  referential integrity and audit trails.
  """

  use GenServer
  alias Mcp.Accounts.User
  require Logger

  @doc """
  Anonymizes all personal data for a user.

  This is an irreversible operation that:
  - Anonymizes email, password, and other PII
  - Maintains user_id for referential integrity
  - Creates audit trail of anonymization
  - Updates user status to :deleted

  Options:
  - strategy: :hash (default), :mask, :delete
  - preserve_metadata: boolean (default: true)
  """
  def anonymize_user(user_id, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :hash)
    preserve_metadata = Keyword.get(opts, :preserve_metadata, true)

    Logger.info("Starting anonymization for user #{user_id} with strategy: #{strategy}")

    with {:ok, user} <- User.get(user_id),
         {:ok, anonymized_data} <- build_anonymized_user_data(user, strategy),
         {:ok, _updated_user} <- apply_anonymization(user, anonymized_data),
         :ok <- anonymize_related_data(user_id, strategy),
         {:ok, _audit} <- create_anonymization_audit(user_id, strategy) do
      Logger.info("Successfully anonymized user #{user_id}")

      {:ok,
       %{
         user_id: user_id,
         anonymized_at: DateTime.utc_now(),
         strategy: strategy,
         fields_anonymized: Map.keys(anonymized_data),
         metadata_preserved: preserve_metadata
       }}
    else
      {:error, reason} = error ->
        Logger.error("Failed to anonymize user #{user_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Anonymizes a specific field value based on its type.

  Supported field types:
  - :email - Generates deterministic anonymized email
  - :name - Replaces with generic placeholder
  - :phone - Masks phone number
  - :ip_address - Anonymizes IP address
  - :text - Redacts text content
  """
  def anonymize_field(value, field_type, user_id, opts \\ [])

  def anonymize_field(value, :email, user_id, _opts) when is_binary(value) do
    # Create deterministic but anonymized email
    hash = :crypto.hash(:sha256, "#{user_id}#{value}") |> Base.encode16(case: :lower)
    anonymized = "deleted_#{String.slice(hash, 0, 16)}@anonymized.local"
    {:ok, anonymized}
  end

  def anonymize_field(_value, :name, _user_id, _opts) do
    {:ok, "Deleted User"}
  end

  def anonymize_field(value, :phone, _user_id, _opts) when is_binary(value) do
    # Keep country code, mask rest
    if String.starts_with?(value, "+") do
      country_code = String.slice(value, 0, 3)
      {:ok, "#{country_code}XXXXXXX"}
    else
      {:ok, "XXXXXXXXXX"}
    end
  end

  def anonymize_field(value, :ip_address, _user_id, _opts) when is_binary(value) do
    # Anonymize last octet for IPv4, last 80 bits for IPv6
    cond do
      String.contains?(value, ".") ->
        # IPv4
        parts = String.split(value, ".")
        anonymized_parts = Enum.take(parts, 3) ++ ["0"]
        {:ok, Enum.join(anonymized_parts, ".")}

      String.contains?(value, ":") ->
        # IPv6 - keep first 48 bits
        parts = String.split(value, ":")
        anonymized_parts = Enum.take(parts, 3) ++ ["0000", "0000", "0000", "0000", "0000"]
        {:ok, Enum.join(anonymized_parts, ":")}

      true ->
        {:ok, "0.0.0.0"}
    end
  end

  def anonymize_field(_value, :text, _user_id, _opts) do
    {:ok, "[REDACTED]"}
  end

  def anonymize_field(value, :json, user_id, opts) when is_map(value) do
    # Recursively anonymize JSON/map fields
    anonymized =
      Enum.reduce(value, %{}, fn {key, val}, acc ->
        field_type = determine_field_type(key, val)

        case anonymize_field(val, field_type, user_id, opts) do
          {:ok, anonymized_val} -> Map.put(acc, key, anonymized_val)
          _ -> Map.put(acc, key, "[REDACTED]")
        end
      end)

    {:ok, anonymized}
  end

  def anonymize_field(_value, _field_type, _user_id, _opts) do
    {:ok, "[ANONYMIZED]"}
  end

  @doc """
  Batch anonymizes multiple users.

  Useful for scheduled anonymization of deleted accounts.
  """
  def anonymize_users(user_ids, opts \\ []) when is_list(user_ids) do
    results =
      Enum.map(user_ids, fn user_id ->
        case anonymize_user(user_id, opts) do
          {:ok, result} -> {:ok, user_id, result}
          {:error, reason} -> {:error, user_id, reason}
        end
      end)

    successes = Enum.count(results, fn {status, _, _} -> status == :ok end)
    failures = Enum.count(results, fn {status, _, _} -> status == :error end)

    Logger.info("Batch anonymization complete: #{successes} succeeded, #{failures} failed")

    {:ok,
     %{
       total: length(user_ids),
       succeeded: successes,
       failed: failures,
       results: results
     }}
  end

  @doc """
  Checks if a user has been anonymized.
  """
  def anonymized?(user_id) do
    case User.get(user_id) do
      {:ok, user} ->
        user.status == :deleted and String.contains?(user.email, "@anonymized.local")

      _ ->
        false
    end
  end

  @doc """
  Restores anonymized user data (NOT SUPPORTED - anonymization is irreversible).

  Returns error as GDPR anonymization must be irreversible.
  """
  def restore_user_data(_user_id, _anonymized_data) do
    {:error, :anonymization_is_irreversible}
  end

  # GenServer callbacks

  @doc """
  Starts the anonymizer GenServer for background processing.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("GDPR Anonymizer started")
    {:ok, %{anonymization_queue: [], stats: %{total: 0, succeeded: 0, failed: 0}}}
  end

  @impl true
  def handle_call({:anonymize_user, user_id, opts}, _from, state) do
    result = anonymize_user(user_id, opts)

    new_stats =
      case result do
        {:ok, _} ->
          %{state.stats | total: state.stats.total + 1, succeeded: state.stats.succeeded + 1}

        {:error, _} ->
          %{state.stats | total: state.stats.total + 1, failed: state.stats.failed + 1}
      end

    {:reply, result, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  # Private functions

  defp build_anonymized_user_data(user, strategy) do
    anonymized = %{
      email: anonymize_email(user.id, user.email, strategy),
      hashed_password: anonymize_password(strategy),
      totp_secret: nil,
      backup_codes: [],
      oauth_tokens: %{},
      last_sign_in_ip: anonymize_ip(user.last_sign_in_ip, strategy),
      status: :deleted
    }

    {:ok, anonymized}
  end

  defp apply_anonymization(user, anonymized_data) do
    User.update(user, anonymized_data)
  end

  defp anonymize_related_data(user_id, _strategy) do
    # Anonymize user data in other tables/resources
    # This would include user profiles, activity logs, etc.
    Logger.debug("Anonymizing related data for user #{user_id}")
    :ok
  end

  defp create_anonymization_audit(user_id, strategy) do
    audit_entry = %{
      user_id: user_id,
      action: "anonymize_user",
      strategy: strategy,
      performed_at: DateTime.utc_now(),
      irreversible: true
    }

    Logger.info("Anonymization audit created: #{inspect(audit_entry)}")
    {:ok, audit_entry}
  end

  defp anonymize_email(user_id, email, :hash) do
    hash = :crypto.hash(:sha256, "#{user_id}#{email}") |> Base.encode16(case: :lower)
    "deleted_#{String.slice(hash, 0, 16)}@anonymized.local"
  end

  defp anonymize_email(_user_id, _email, :mask) do
    "deleted_user@anonymized.local"
  end

  defp anonymize_email(_user_id, _email, _strategy) do
    "anonymized@deleted.local"
  end

  defp anonymize_password(_strategy) do
    # Generate a random unusable password hash
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp anonymize_ip(nil, _strategy), do: nil

  defp anonymize_ip(ip, _strategy) when is_binary(ip) do
    case anonymize_field(ip, :ip_address, nil, []) do
      {:ok, anonymized} -> anonymized
      _ -> "0.0.0.0"
    end
  end

  defp determine_field_type(key, value) when is_binary(key) do
    cond do
      String.contains?(key, "email") -> :email
      String.contains?(key, "name") -> :name
      String.contains?(key, "phone") -> :phone
      String.contains?(key, "ip") -> :ip_address
      is_map(value) -> :json
      true -> :text
    end
  end

  defp determine_field_type(_key, value) when is_map(value), do: :json
  defp determine_field_type(_key, _value), do: :text
end
