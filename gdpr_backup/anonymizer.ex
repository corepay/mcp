defmodule Mcp.Gdpr.Anonymizer do
  @moduledoc """
  Data anonymization module for GDPR compliance.

  This module provides comprehensive data anonymization capabilities including:
  - Personal data pseudonymization and irreversible anonymization
  - Field-level anonymization strategies for different data types
  - Consistent anonymization across all user data
  - Audit logging of all anonymization activities
  """

  alias Mcp.Gdpr.AuditTrail
  alias Mcp.Repo
  import Ecto.Query

  def anonymize_field(nil, _strategy, _user_id, _opts), do: nil

  def anonymize_field(value, strategy, user_id, opts) do
    case strategy do
      :email -> anonymize_email(value, user_id, opts)
      :name -> anonymize_name(value, user_id, opts)
      :phone -> anonymize_phone(value, user_id, opts)
      :address -> anonymize_address(value, user_id, opts)
      :ip_address -> anonymize_ip_address(value, user_id, opts)
      :free_text -> anonymize_free_text(value, user_id, opts)
      :identifier -> anonymize_identifier(value, user_id, opts)
      :date -> anonymize_date(value, user_id, opts)
      _ -> {:error, :unknown_strategy}
    end
  end

  @reversible_salt "gdpr_anonymization_salt_v1"

  @doc """
  Performs complete anonymization of all user data.

  ## Parameters
  - user_id: UUID of the user to anonymize
  - opts: Anonymization options
    - :mode - :reversible (retention period) or :irreversible (final deletion)
    - :preserve_analytics - Keep analytics data with user anonymization
    - :dry_run - Preview changes without executing them

  ## Returns
  - {:ok, anonymization_result} containing applied changes
  - {:error, reason} on failure

  ## Examples
      iex> Anonymizer.anonymize_user(user_uuid, mode: :reversible)
      {:ok, %{fields_anonymized: 15, tables_updated: 5}}
  """
  def anonymize_user(user_id, opts \\ []) do
    mode = Keyword.get(opts, :mode, :reversible)
    preserve_analytics = Keyword.get(opts, :preserve_analytics, true)
    dry_run = Keyword.get(opts, :dry_run, false)

    Repo.transaction(fn ->
      with {:ok, user_data} <- collect_user_identifiable_data(user_id),
           anonymization_plan <- create_anonymization_plan(user_data, mode),
           :ok <- validate_anonymization_plan(anonymization_plan) do

        if dry_run do
          {:ok, %{plan: anonymization_plan, preview: true}}
        else
          execute_anonymization_plan(user_id, anonymization_plan, preserve_analytics)
        end
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Anonymizes a specific field with the given strategy.

  ## Parameters
  - value: The value to anonymize
  - strategy: Atom indicating anonymization strategy
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized value according to the strategy
  """
  
  @doc """
  Generates a consistent pseudonym for a user.

  ## Parameters
  - user_id: UUID of the user
  - prefix: Optional prefix for the pseudonym

  ## Returns
  - String containing the generated pseudonym
  """
  def generate_pseudonym(user_id, prefix \\ "user") do
    # Create a consistent hash for the user ID
    hash = :crypto.hash(:sha256, "#{user_id}#{@reversible_salt}")
    hash_suffix = Base.encode16(hash) |> String.slice(0, 8)
    "#{prefix}_#{hash_suffix}"
  end

  @doc """
  Anonymizes email address while maintaining format validity.

  ## Parameters
  - email: Email address to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized email address
  """
  def anonymize_email(email, user_id \\ nil, opts \\ [])

  def anonymize_email(nil, _user_id, _opts), do: nil

  def anonymize_email(email, user_id, _opts) do
    if user_id do
      pseudonym = generate_pseudonym(user_id, "deleted")
      "#{pseudonym}@deleted.local"
    else
      # Fallback for cases where user_id is not available
      domain = extract_domain(email)
      "deleted_#{:crypto.hash(:md5, email) |> Base.encode16() |> String.slice(0, 8)}@#{domain}"
    end
  end

  @doc """
  Anonymizes name fields.

  ## Parameters
  - name: Name to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized name
  """
  def anonymize_name(name, user_id \\ nil, _opts)

  def anonymize_name(nil, _user_id, _opts), do: nil

  def anonymize_name(_name, user_id, _opts) do
    if user_id do
      pseudonym = generate_pseudonym(user_id, "User")
      "Deleted #{pseudonym}"
    else
      "Deleted User"
    end
  end

  @doc """
  Anonymizes phone numbers.

  ## Parameters
  - phone: Phone number to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized phone number
  """
  def anonymize_phone(phone, _user_id \\ nil, _opts)

  def anonymize_phone(nil, _user_id, _opts), do: nil

  def anonymize_phone(_phone, _user_id, _opts) do
    # Return a standardized anonymous phone number
    "+1-555-555-5555"
  end

  @doc """
  Anonymizes address information.

  ## Parameters
  - address: Address to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized address
  """
  def anonymize_address(address, user_id, _opts)

  def anonymize_address(nil, _user_id, _opts), do: nil

  def anonymize_address(_address, user_id, _opts) do
    pseudonym = generate_pseudonym(user_id, "addr")
    "#{pseudonym} Street, Deleted City, DC 00000"
  end

  @doc """
  Anonymizes IP addresses for analytics purposes.

  ## Parameters
  - ip_address: IP address to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized IP address
  """
  def anonymize_ip_address(ip_address, _user_id, _opts)

  def anonymize_ip_address(nil, _user_id, _opts), do: nil

  def anonymize_ip_address(ip_address, _user_id, _opts) do
    # Convert to classful network (first 3 octets for IPv4)
    case :inet.parse_address(String.to_charlist(ip_address)) do
      {:ok, {a, b, c, _d}} -> "#{a}.#{b}.#{c}.0/24"
      {:ok, {a, b, c, d, e, f, _g, _h}} -> "#{:inet.ntoa({a, b, c, 0, 0, 0, 0, 0})}"
      _ -> "0.0.0.0/0"
    end
  end

  @doc """
  Anonymizes free text fields.

  ## Parameters
  - text: Text to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized text
  """
  def anonymize_free_text(text, _user_id, _opts)

  def anonymize_free_text(nil, _user_id, _opts), do: nil

  def anonymize_free_text(_text, _user_id, _opts) do
    "[Content removed due to GDPR deletion]"
  end

  @doc """
  Anonymizes identifiers while maintaining uniqueness.

  ## Parameters
  - identifier: Identifier to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options

  ## Returns
  - Anonymized identifier
  """
  def anonymize_identifier(identifier, user_id, _opts)

  def anonymize_identifier(nil, _user_id, _opts), do: nil

  def anonymize_identifier(identifier, user_id, _opts) do
    pseudonym = generate_pseudonym(user_id, "id")
    "#{pseudonym}_#{:crypto.hash(:md5, identifier) |> Base.encode16() |> String.slice(0, 8)}"
  end

  @doc """
  Anonymizes dates by adding random offset within acceptable range.

  ## Parameters
  - date: Date to anonymize
  - user_id: User ID for consistent anonymization
  - opts: Additional options
    - :offset_days - Maximum day offset for randomization

  ## Returns
  - Anonymized date
  """
  def anonymize_date(date, user_id, opts)

  def anonymize_date(nil, _user_id, _opts), do: nil

  def anonymize_date(date, user_id, opts) do
    offset_days = Keyword.get(opts, :offset_days, 30)
    # Create consistent offset based on user ID
    seed = :crypto.hash(:md5, "#{user_id}_date_salt") |> binary_part(0, 4)
    offset = :binary.decode_unsigned(seed) |> rem(offset_days * 2 + 1) |> Kernel.-(offset_days)
    Date.add(date, offset)
  end

  @doc """
  Restores data from reversible anonymization.

  ## Parameters
  - user_id: UUID of the user
  - anonymized_data: Map containing anonymized data

  ## Returns
  - {:ok, restored_data} on successful restoration
  - {:error, reason} on failure or if data is irreversibly anonymized
  """
  def restore_user_data(user_id, anonymized_data) do
    # Implementation would require storing mapping between original and anonymized data
    # This is a placeholder for the reversible anonymization restoration
    {:error, :restoration_not_implemented}
  end

  @doc """
  Validates that anonymization was applied correctly.

  ## Parameters
  - user_id: UUID of the user to validate
  - expected_fields: List of fields that should be anonymized

  ## Returns
  - {:ok, validation_result} containing validation status
  - {:error, reason} on failure
  """
  def validate_anonymization(user_id, expected_fields \\ []) do
    # Check if user data is properly anonymized
    validation_results = Enum.map(expected_fields, fn field ->
      field_status = check_field_anonymization(user_id, field)
      {field, field_status}
    end)

    all_valid = Enum.all?(validation_results, fn {_field, status} -> status == :anonymized end)

    {:ok, %{
      user_id: user_id,
      all_fields_anonymized: all_valid,
      field_results: validation_results,
      validated_at: DateTime.utc_now()
    }}
  end

  # Private functions

  defp collect_user_identifiable_data(user_id) do
    # Collect all personally identifiable data for a user
    user_query = from(u in "users",
      where: u.id == ^user_id,
      select: map(u, [:id, :email, :first_name, :last_name, :last_sign_in_ip]))

    user_data = Repo.one(user_query, prefix: "platform")

    # Collect data from other tables
    additional_data = %{
      user_profiles: collect_user_profile_data(user_id),
      audit_logs: collect_audit_log_data(user_id),
      communications: collect_communication_data(user_id)
    }

    {:ok, Map.merge(user_data || %{}, additional_data)}
  end

  defp collect_user_profile_data(user_id) do
    # Collect user profile data that might contain PII
    query = from(p in "user_profiles",
      where: p.user_id == ^user_id,
      select: map(p, [:id, :phone, :address, :bio, :emergency_contact]))

    Repo.all(query, prefix: "platform")
  end

  defp collect_audit_log_data(user_id) do
    # Collect audit log entries that might contain PII
    query = from(a in "audit_logs",
      where: a.actor_id == ^user_id,
      limit: 100,  # Limit for performance
      select: map(a, [:id, :changes, :ip_address, :user_agent]))

    Repo.all(query, prefix: "platform")
  end

  defp collect_communication_data(user_id) do
    # Collect communication data (emails, SMS, etc.)
    query = from(c in "communication_logs",
      where: c.user_id == ^user_id,
      limit: 100,  # Limit for performance
      select: map(c, [:id, :content, :subject, :attachments]))

    Repo.all(query, prefix: "platform")
  end

  defp create_anonymization_plan(user_data, mode) do
    %{
      user_id: user_data.id,
      mode: mode,
      tables: %{
        users: [
          %{field: :email, strategy: :email, current_value: user_data.email},
          %{field: :first_name, strategy: :name, current_value: user_data.first_name},
          %{field: :last_name, strategy: :name, current_value: user_data.last_name},
          %{field: :last_sign_in_ip, strategy: :ip_address, current_value: user_data.last_sign_in_ip}
        ],
        user_profiles: create_profile_anonymization_plan(user_data.user_profiles),
        audit_logs: create_audit_anonymization_plan(user_data.audit_logs, mode),
        communications: create_communication_anonymization_plan(user_data.communications, mode)
      }
    }
  end

  defp create_profile_anonymization_plan(profiles) do
    Enum.map(profiles, fn profile ->
      [
        %{field: :phone, strategy: :phone, current_value: profile.phone, record_id: profile.id},
        %{field: :address, strategy: :address, current_value: profile.address, record_id: profile.id},
        %{field: :bio, strategy: :free_text, current_value: profile.bio, record_id: profile.id},
        %{field: :emergency_contact, strategy: :name, current_value: profile.emergency_contact, record_id: profile.id}
      ]
    end)
    |> List.flatten()
  end

  defp create_audit_anonymization_plan(audit_logs, mode) do
    Enum.map(audit_logs, fn log ->
      case mode do
        :reversible ->
          # For retention period, we preserve audit data but anonymize user references
          [
            %{field: :ip_address, strategy: :ip_address, current_value: log.ip_address, record_id: log.id}
          ]
        :irreversible ->
          # For final deletion, we remove more detailed information
          [
            %{field: :ip_address, strategy: :ip_address, current_value: log.ip_address, record_id: log.id},
            %{field: :user_agent, strategy: :free_text, current_value: log.user_agent, record_id: log.id}
          ]
      end
    end)
    |> List.flatten()
  end

  defp create_communication_anonymization_plan(communications, mode) do
    Enum.map(communications, fn comm ->
      case mode do
        :reversible ->
          # Preserve metadata but anonymize content
          [
            %{field: :content, strategy: :free_text, current_value: comm.content, record_id: comm.id},
            %{field: :subject, strategy: :free_text, current_value: comm.subject, record_id: comm.id}
          ]
        :irreversible ->
          # Remove communication content entirely
          [
            %{field: :content, strategy: :free_text, current_value: comm.content, record_id: comm.id},
            %{field: :subject, strategy: :free_text, current_value: comm.subject, record_id: comm.id},
            %{field: :attachments, strategy: :free_text, current_value: comm.attachments, record_id: comm.id}
          ]
      end
    end)
    |> List.flatten()
  end

  defp validate_anonymization_plan(plan) do
    # Validate that the plan is safe and complete
    cond do
      is_nil(plan.user_id) -> {:error, :missing_user_id}
      plan.mode not in [:reversible, :irreversible] -> {:error, :invalid_anonymization_mode}
      true -> :ok
    end
  end

  defp execute_anonymization_plan(user_id, plan, preserve_analytics) do
    # Execute the anonymization plan
    results = %{
      tables_updated: 0,
      fields_anonymized: 0,
      errors: []
    }

    # Anonymize users table
    user_results = execute_table_anonymization("users", plan.tables.users, user_id)

    # Anonymize other tables
    profile_results = execute_table_anonymization("user_profiles", plan.tables.user_profiles, user_id)

    audit_results = if preserve_analytics do
      execute_table_anonymization("audit_logs", plan.tables.audit_logs, user_id)
    else
      {:ok, %{fields_anonymized: 0, tables_updated: 0}}
    end

    communication_results = execute_table_anonymization("communication_logs", plan.tables.communications, user_id)

    # Log the anonymization
    AuditTrail.log_action(user_id, "anonymization_complete", nil, %{
      mode: plan.mode,
      preserve_analytics: preserve_analytics,
      tables_updated: user_results.tables_updated + profile_results.tables_updated +
                      audit_results.tables_updated + communication_results.tables_updated,
      fields_anonymized: user_results.fields_anonymized + profile_results.fields_anonymized +
                        audit_results.fields_anonymized + communication_results.fields_anonymized
    })

    {:ok, %{
      user_id: user_id,
      mode: plan.mode,
      tables_updated: user_results.tables_updated + profile_results.tables_updated +
                      audit_results.tables_updated + communication_results.tables_updated,
      fields_anonymized: user_results.fields_anonymized + profile_results.fields_anonymized +
                        audit_results.fields_anonymized + communication_results.fields_anonymized,
      completed_at: DateTime.utc_now()
    }}
  end

  defp execute_table_anonymization(table_name, field_plans, user_id) do
    Enum.reduce(field_plans, %{fields_anonymized: 0, tables_updated: 0}, fn field_plan, acc ->
      case anonymize_table_field(table_name, field_plan, user_id) do
        {:ok, _result} ->
          %{acc | fields_anonymized: acc.fields_anonymized + 1}
        {:error, error} ->
          %{acc | fields_anonymized: acc.fields_anonymized, errors: [error | (acc.errors || [])]}
      end
    end)
  end

  defp anonymize_table_field(table_name, field_plan, user_id) do
    # Execute the anonymization for a specific field in a table
    anonymized_value = anonymize_field(
      field_plan.current_value,
      field_plan.strategy,
      user_id
    )

    update_query =
      from(t in fragment("? AS t", ^table_name),
        where: t.id == ^field_plan.record_id,
        where: not is_null(t.id))

    case Repo.update_all(update_query, [set: [{field_plan.field, anonymized_value}], prefix: "platform"]) do
      {1, _} -> {:ok, %{field: field_plan.field, anonymized: true}}
      {0, _} -> {:error, :record_not_found}
      error -> {:error, error}
    end
  end

  defp extract_domain(email) do
    case String.split(email, "@") do
      [_local, domain] -> domain
      _ -> "local"
    end
  end

  defp check_field_anonymization(user_id, field) do
    # Check if a specific field is properly anonymized
    case field do
      :email -> check_email_anonymization(user_id)
      :name -> check_name_anonymization(user_id)
      _ -> :unknown_field
    end
  end

  defp check_email_anonymization(user_id) do
    query = from(u in "users",
      where: u.id == ^user_id,
      select: u.email)

    case Repo.one(query, prefix: "platform") do
      nil -> :error
      email when is_binary(email) ->
        if String.ends_with?(email, "@deleted.local") do
          :anonymized
        else
          :not_anonymized
        end
    end
  end

  defp check_name_anonymization(user_id) do
    query = from(u in "users",
      where: u.id == ^user_id,
      select: {u.first_name, u.last_name})

    case Repo.one(query, prefix: "platform") do
      nil -> :error
      {first_name, last_name} ->
        if String.contains?(first_name, "Deleted") or String.contains?(last_name, "Deleted") do
          :anonymized
        else
          :not_anonymized
        end
    end
  end
end