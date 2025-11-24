# GDPR Compliance Engine - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP GDPR compliance system. Includes privacy engineering patterns, data protection workflows, consent management, and regulatory reporting implementation.

## Architecture Overview

The GDPR compliance engine follows a privacy-by-design architecture:

- **Consent Management Layer**: Dynamic consent collection, tracking, and management
- **Data Subject Rights Layer**: Automated processing of access, rectification, and deletion requests
- **Retention Management Layer**: Automated data retention, anonymization, and deletion workflows
- **Audit Trail Layer**: Comprehensive logging and compliance documentation
- **Privacy Controls Layer**: Real-time privacy enforcement and policy management
- **Reporting Layer**: Regulatory reporting and compliance analytics

## Database Schema for Compliance

```elixir
defmodule Mcp.Gdpr.Migrations.CreateComplianceTables do
  use Ecto.Migration

  def change do
    # Data categories and processing purposes
    create table(:gdpr_data_categories) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :name, :string, null: false
      add :description, :text
      add :retention_period_months, :integer, null: false
      add :anonymization_method, :string
      add :requires_consent, :boolean, default: false
      add :special_category, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:gdpr_data_categories, [:tenant_id, :name])

    # Consent records
    create table(:gdpr_consents) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false
      add :data_category_id, references(:gdpr_data_categories, type: :binary_id), null: false
      add :purpose, :string, null: false
      add :consent_given, :boolean, null: false
      add :consent_timestamp, :utc_datetime, null: false
      add :ip_address, :string
      add :user_agent, :string
      add :consent_version, :string
      add :withdrawn_at, :utc_datetime
      add :withdrawal_reason, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:gdpr_consents, [:tenant_id, :user_id])
    create index(:gdpr_consents, [:data_category_id, :consent_given])

    # Data subject rights requests
    create table(:gdpr_data_subject_requests) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false
      add :request_type, :string, null: false  # access, rectification, erasure, restriction, portability
      add :status, :string, default: "pending"  # pending, processing, completed, rejected
      add :request_data, :map, default: %{}
      add :response_data, :map, default: %{}
      add :verification_method, :string
      add :verification_data, :map, default: %{}
      add :processed_by, references(:users, type: :binary_id)
      add :processed_at, :utc_datetime
      add :response_sent_at, :utc_datetime
      add :notes, :text
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:gdpr_data_subject_requests, [:tenant_id, :user_id, :status])

    # Data processing records
    create table(:gdpr_processing_records) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :data_category_id, references(:gdpr_data_categories, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id)
      add :processing_purpose, :string, null: false
      add :legal_basis, :string, null: false  # consent, contractual, legal_obligation, vital_interests, public_task, legitimate_interests
      add :processing_activity, :string, null: false
      add :data_controller, :string
      add :data_processor, :string
      add :third_countries, :string  # comma-separated list of countries
      add :security_measures, :text
      add :retention_period_months, :integer
      add :automated_decision_making, :boolean, default: false
      add :profiling, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:gdpr_processing_records, [:tenant_id, :user_id])
    create index(:gdpr_processing_records, [:data_category_id])

    # Retention policies and schedules
    create table(:gdpr_retention_policies) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :data_category_id, references(:gdpr_data_categories, type: :binary_id), null: false
      add :action, :string, null: false  # retain, delete, anonymize
      add :retention_period_months, :integer
      add :condition_type, :string  # time_based, event_based, manual
      add :condition_data, :map, default: %{}
      add :active, :boolean, default: true
      add :last_executed_at, :utc_datetime
      add :next_execution_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:gdpr_retention_policies, [:tenant_id, :active, :next_execution_at])

    # Audit trail
    create table(:gdpr_audit_logs) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id)
      add :action_type, :string, null: false  # consent_given, consent_withdrawn, data_accessed, data_modified, data_deleted, policy_executed
      add :resource_type, :string, null: false
      add :resource_id, :string, null: false
      add :old_values, :map
      add :new_values, :map
      add :ip_address, :string
      add :user_agent, :string
      add :session_id, :string
      add :request_id, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:gdpr_audit_logs, [:tenant_id, :user_id])
    create index(:gdpr_audit_logs, [:action_type])
    create index(:gdpr_audit_logs, [:inserted_at])
  end
end
```

## Consent Management System

```elixir
defmodule Mcp.Gdpr.ConsentManager do
  @moduledoc """
  Manages user consent for data processing activities
  """

  alias Mcp.Gdpr.{Consent, DataCategory, AuditLogger}

  def record_consent(user_id, data_category_id, purpose, consent_details \\ %{}) do
    consent_params = %{
      user_id: user_id,
      data_category_id: data_category_id,
      purpose: purpose,
      consent_given: Map.get(consent_details, :consent_given, true),
      consent_timestamp: DateTime.utc_now(),
      ip_address: Map.get(consent_details, :ip_address),
      user_agent: Map.get(consent_details, :user_agent),
      consent_version: Map.get(consent_details, :consent_version, "1.0"),
      metadata: Map.get(consent_details, :metadata, %{})
    }

    Multi.new()
    |> Multi.insert(:consent, Consent.changeset(%Consent{}, consent_params))
    |> Multi.run(:audit, fn _repo, _changes ->
      AuditLogger.log_action(
        user_id,
        :consent_given,
        "consent",
        to_string(consent_params.data_category_id),
        nil,
        consent_params,
        consent_details.ip_address,
        consent_details.user_agent
      )
    end)
    |> Repo.transaction()
  end

  def withdraw_consent(consent_id, withdrawal_reason \\ "") do
    consent = Repo.get!(Consent, consent_id)

    withdrawal_params = %{
      consent_given: false,
      withdrawn_at: DateTime.utc_now(),
      withdrawal_reason: withdrawal_reason
    }

    Multi.new()
    |> Multi.update(:consent, Consent.changeset(consent, withdrawal_params))
    |> Multi.run(:audit, fn _repo, changes ->
      AuditLogger.log_action(
        consent.user_id,
        :consent_withdrawn,
        "consent",
        consent_id,
        %{consent_given: true},
        changes.consent.changes,
        nil,
        nil
      )
    end)
    |> Repo.transaction()
  end

  def has_valid_consent?(user_id, data_category_id, purpose \\ nil) do
    query = from c in Consent,
      where: c.user_id == ^user_id,
      where: c.data_category_id == ^data_category_id,
      where: c.consent_given == true,
      where: is_nil(c.withdrawn_at)

    query = if purpose do
      from c in query, where: c.purpose == ^purpose
    else
      query
    end

    Repo.exists?(query)
  end

  def get_user_consents(user_id) do
    Repo.all(from c in Consent,
      where: c.user_id == ^user_id,
      preload: [:data_category]
    )
  end

  def get_consent_analytics(tenant_id, date_range \\ nil) do
    base_query = from c in Consent,
      join: dc in DataCategory, on: c.data_category_id == dc.id,
      where: dc.tenant_id == ^tenant_id

    query = if date_range do
      from c in base_query,
        where: c.inserted_at >= ^date_range.start_date,
        where: c.inserted_at <= ^date_range.end_date
    else
      base_query
    end

    # Consent analytics
    total_consents = Repo.aggregate(query, :count, :id)
    active_consents = from(c in query, where: c.consent_given == true and is_nil(c.withdrawn_at))
                      |> Repo.aggregate(:count, :id)
    withdrawn_consents = from(c in query, where: not is_nil(c.withdrawn_at))
                         |> Repo.aggregate(:count, :id)

    %{
      total_consents: total_consents,
      active_consents: active_consents,
      withdrawn_consents: withdrawn_consents,
      withdrawal_rate: if(total_consents > 0, do: withdrawn_consents / total_consents * 100, else: 0)
    }
  end
end
```

## Data Subject Rights Implementation

```elixir
defmodule Mcp.Gdpr.DataSubjectRights do
  @moduledoc """
  Implements GDPR data subject rights: access, rectification, erasure, restriction, portability
  """

  alias Mcp.Gdpr.{DataSubjectRequest, ProcessingRecord, AuditLogger}

  def create_access_request(user_id, request_details \\ %{}) do
    request_params = %{
      user_id: user_id,
      request_type: "access",
      status: "pending",
      request_data: %{
        data_types: Map.get(request_details, :data_types, ["all"]),
        format: Map.get(request_details, :format, "json"),
        verification_method: Map.get(request_details, :verification_method, "email")
      },
      metadata: Map.get(request_details, :metadata, %{})
    }

    changeset = DataSubjectRequest.changeset(%DataSubjectRequest{}, request_params)
    Repo.insert(changeset)
  end

  def process_access_request(request_id) do
    request = Repo.get!(DataSubjectRequest, request_id)
    user_id = request.user_id
    data_types = request.request_data["data_types"]

    # Collect user data from various sources
    user_data = collect_user_data(user_id, data_types)

    # Format data according to requested format
    formatted_data = format_export_data(user_data, request.request_data["format"])

    # Update request with response
    response_data = %{
      data: formatted_data,
      export_format: request.request_data["format"],
      generated_at: DateTime.utc_now(),
      record_count: count_records(user_data)
    }

    Multi.new()
    |> Multi.update(:request, DataSubjectRequest.changeset(request, %{
      status: "completed",
      response_data: response_data,
      processed_at: DateTime.utc_now()
    }))
    |> Multi.run(:audit, fn _repo, _changes ->
      AuditLogger.log_action(
        user_id,
        :data_accessed,
        "data_subject_request",
        request_id,
        nil,
        %{request_completed: true, record_count: response_data.record_count}
      )
    end)
    |> Repo.transaction()
  end

  def create_erasure_request(user_id, request_details \\ %{}) do
    request_params = %{
      user_id: user_id,
      request_type: "erasure",
      status: "pending",
      request_data: %{
        data_categories: Map.get(request_details, :data_categories, ["all"]),
        reason: Map.get(request_details, :reason, "user_request"),
        verification_method: Map.get(request_details, :verification_method, "email")
      },
      metadata: Map.get(request_details, :metadata, %{})
    }

    changeset = DataSubjectRequest.changeset(%DataSubjectRequest{}, request_params)
    Repo.insert(changeset)
  end

  def process_erasure_request(request_id) do
    request = Repo.get!(DataSubjectRequest, request_id)
    user_id = request.user_id
    data_categories = request.request_data["data_categories"]

    Multi.new()
    |> Multi.run(:identify_data, fn _repo, _changes ->
      {:ok, identify_user_data(user_id, data_categories)}
    end)
    |> Multi.run(:anonymize_data, fn _repo, %{identify_data: user_data} ->
      anonymize_user_data(user_data)
    end)
    |> Multi.run(:update_request, fn _repo, changes ->
      {:ok, DataSubjectRequest.changeset(request, %{
        status: "completed",
        response_data: %{
          categories_processed: data_categories,
          records_processed: length(changes.identify_data),
          processed_at: DateTime.utc_now()
        },
        processed_at: DateTime.utc_now()
      })}
    end)
    |> Multi.run(:audit, fn _repo, %{update_request: request_changeset} ->
      request_changeset = Ecto.Changeset.apply_changes(request_changeset)
      AuditLogger.log_action(
        user_id,
        :data_deleted,
        "data_subject_request",
        request_id,
        nil,
        request_changeset.response_data
      )
    end)
    |> Repo.transaction()
  end

  defp collect_user_data(user_id, data_types) do
    user_data = %{}

    user_data = if "profile" in data_types or "all" in data_types do
      Map.put(user_data, :profile, collect_profile_data(user_id))
    else
      user_data
    end

    user_data = if "consents" in data_types or "all" in data_types do
      Map.put(user_data, :consents, collect_consent_data(user_id))
    else
      user_data
    end

    user_data = if "activity" in data_types or "all" in data_types do
      Map.put(user_data, :activity, collect_activity_data(user_id))
    else
      user_data
    end

    user_data = if "processing_records" in data_types or "all" in data_types do
      Map.put(user_data, :processing_records, collect_processing_records(user_id))
    else
      user_data
    end

    user_data
  end

  defp collect_profile_data(user_id) do
    # Collect user profile information
    user = Repo.get!(Mcp.Accounts.User, user_id)

    %{
      id: user.id,
      email: user.email,
      name: user.name,
      created_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp collect_consent_data(user_id) do
    consents = Mcp.Gdpr.ConsentManager.get_user_consents(user_id)

    Enum.map(consents, fn consent ->
      %{
        data_category: consent.data_category.name,
        purpose: consent.purpose,
        consent_given: consent.consent_given,
        consent_timestamp: consent.consent_timestamp,
        withdrawn_at: consent.withdrawn_at
      }
    end)
  end

  defp collect_activity_data(user_id) do
    # Collect user activity logs
    Repo.all(from al in Mcp.Audit.ActivityLog,
      where: al.user_id == ^user_id,
      order_by: [desc: al.inserted_at],
      limit: 1000
    )
  end

  defp collect_processing_records(user_id) do
    Repo.all(from pr in ProcessingRecord,
      where: pr.user_id == ^user_id,
      preload: [:data_category]
    )
  end

  defp format_export_data(data, "json") do
    Jason.encode!(%{
      exported_at: DateTime.utc_now(),
      user_id: get_user_id_from_data(data),
      data: data
    }, pretty: true)
  end

  defp format_export_data(data, "csv") do
    # Implement CSV formatting
    ""
  end

  defp identify_user_data(user_id, data_categories) do
    # Return list of records to be processed
    []
  end

  defp anonymize_user_data(user_data) do
    # Anonymize user data according to GDPR requirements
    :ok
  end

  defp count_records(user_data) do
    # Count total records in user_data structure
    0
  end

  defp get_user_id_from_data(data) do
    # Extract user ID from data structure
    ""
  end
end
```

## Retention Management System

```elixir
defmodule Mcp.Gdpr.RetentionManager do
  @moduledoc """
  Manages data retention policies and automated data processing
  """

  alias Mcp.Gdpr.{RetentionPolicy, ProcessingRecord, AuditLogger}

  def create_retention_policy(tenant_id, data_category_id, policy_params) do
    retention_params = %{
      tenant_id: tenant_id,
      data_category_id: data_category_id,
      action: Map.get(policy_params, :action, "delete"),
      retention_period_months: Map.get(policy_params, :retention_period_months),
      condition_type: Map.get(policy_params, :condition_type, "time_based"),
      condition_data: Map.get(policy_params, :condition_data, %{}),
      active: true,
      next_execution_at: calculate_next_execution(policy_params),
      metadata: Map.get(policy_params, :metadata, %{})
    }

    changeset = RetentionPolicy.changeset(%RetentionPolicy{}, retention_params)
    Repo.insert(changeset)
  end

  def execute_retention_policies() do
    now = DateTime.utc_now()

    policies_to_execute = Repo.all(from rp in RetentionPolicy,
      where: rp.active == true,
      where: rp.next_execution_at <= ^now
    )

    Enum.each(policies_to_execute, &execute_single_policy/1)
  end

  def execute_single_policy(policy) do
    case policy.action do
      "delete" -> execute_deletion_policy(policy)
      "anonymize" -> execute_anonymization_policy(policy)
      "retain" -> execute_retain_policy(policy)
    end
  end

  defp execute_deletion_policy(policy) do
    records_to_delete = identify_records_for_policy(policy)
    deleted_count = 0

    Enum.each(records_to_delete, fn record ->
      case delete_record(record) do
        :ok ->
          deleted_count = deleted_count + 1
          AuditLogger.log_action(
            record.user_id,
            :data_deleted,
            "retention_policy",
            policy.id,
            nil,
            %{policy_id: policy.id, record_type: record.__struct__.__name__}
          )
        {:error, reason} ->
          Logger.error("Failed to delete record #{record.id}: #{inspect(reason)}")
      end
    end)

    update_policy_execution(policy, deleted_count)
  end

  defp execute_anonymization_policy(policy) do
    records_to_anonymize = identify_records_for_policy(policy)
    anonymized_count = 0

    Enum.each(records_to_anonymize, fn record ->
      case anonymize_record(record) do
        :ok ->
          anonymized_count = anonymized_count + 1
          AuditLogger.log_action(
            record.user_id,
            :data_anonymized,
            "retention_policy",
            policy.id,
            nil,
            %{policy_id: policy.id, record_type: record.__struct__.__name__}
          )
        {:error, reason} ->
          Logger.error("Failed to anonymize record #{record.id}: #{inspect(reason)}")
      end
    end)

    update_policy_execution(policy, anonymized_count)
  end

  defp execute_retain_policy(_policy) do
    # Retain policies don't require action, just update next execution
    :ok
  end

  defp identify_records_for_policy(policy) do
    case policy.condition_type do
      "time_based" -> identify_time_based_records(policy)
      "event_based" -> identify_event_based_records(policy)
      "manual" -> []
    end
  end

  defp identify_time_based_records(policy) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -policy.retention_period_months * 30 * 24 * 60 * 60, :second)

    # Query records older than retention period
    # This would be implemented based on specific data types
    []
  end

  defp identify_event_based_records(_policy) do
    # Identify records based on specific events
    []
  end

  defp delete_record(_record) do
    # Delete record from database
    :ok
  end

  defp anonymize_record(_record) do
    # Anonymize record (remove or mask personal data)
    :ok
  end

  defp update_policy_execution(policy, records_processed) do
    next_execution = calculate_next_execution(policy)

    policy
    |> RetentionPolicy.changeset(%{
      last_executed_at: DateTime.utc_now(),
      next_execution_at: next_execution,
      metadata: Map.put(policy.metadata, :last_execution_records, records_processed)
    })
    |> Repo.update()
  end

  defp calculate_next_execution(policy) do
    case policy.condition_type do
      "time_based" ->
        # Schedule next execution (e.g., daily, weekly, monthly)
        DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)
      "event_based" ->
        nil # Event-based policies don't have scheduled execution
      _ ->
        nil
    end
  end
end
```

## Audit Logging System

```elixir
defmodule Mcp.Gdpr.AuditLogger do
  @moduledoc """
  Comprehensive audit logging for all GDPR-related activities
  """

  alias Mcp.Gdpr.AuditLog

  def log_action(user_id, action_type, resource_type, resource_id, old_values, new_values, ip_address \\ nil, user_agent \\ nil, metadata \\ %{}) do
    audit_params = %{
      user_id: user_id,
      action_type: action_type,
      resource_type: resource_type,
      resource_id: resource_id,
      old_values: old_values,
      new_values: new_values,
      ip_address: ip_address,
      user_agent: user_agent,
      session_id: get_session_id(),
      request_id: get_request_id(),
      metadata: metadata
    }

    changeset = AuditLog.changeset(%AuditLog{}, audit_params)
    Repo.insert(changeset)
  end

  def get_audit_trail(user_id, date_range \\ nil, action_types \\ nil) do
    base_query = from al in AuditLog,
      where: al.user_id == ^user_id,
      order_by: [desc: al.inserted_at]

    query = base_query
    |> apply_date_filter(date_range)
    |> apply_action_type_filter(action_types)

    Repo.all(query)
  end

  def get_compliance_report(tenant_id, report_type, date_range) do
    case report_type do
      :consent_report -> generate_consent_report(tenant_id, date_range)
      :data_subject_requests -> generate_data_subject_requests_report(tenant_id, date_range)
      :retention_policy_executions -> generate_retention_policy_report(tenant_id, date_range)
      :audit_trail -> generate_audit_trail_report(tenant_id, date_range)
    end
  end

  defp generate_consent_report(tenant_id, date_range) do
    # Generate comprehensive consent report
    %{
      report_type: "consent_report",
      tenant_id: tenant_id,
      period: date_range,
      data: %{
        total_consents: 0,
        active_consents: 0,
        withdrawn_consents: 0,
        consent_by_category: %{},
        consent_trends: []
      }
    }
  end

  defp generate_data_subject_requests_report(tenant_id, date_range) do
    # Generate data subject requests report
    %{
      report_type: "data_subject_requests",
      tenant_id: tenant_id,
      period: date_range,
      data: %{
        total_requests: 0,
        completed_requests: 0,
        pending_requests: 0,
        average_processing_time_days: 0,
        requests_by_type: %{}
      }
    }
  end

  defp generate_retention_policy_report(tenant_id, date_range) do
    # Generate retention policy execution report
    %{
      report_type: "retention_policy_executions",
      tenant_id: tenant_id,
      period: date_range,
      data: %{
        policies_executed: 0,
        records_processed: 0,
        records_deleted: 0,
        records_anonymized: 0,
        execution_summary: %{}
      }
    }
  end

  defp generate_audit_trail_report(tenant_id, date_range) do
    # Generate audit trail summary
    %{
      report_type: "audit_trail",
      tenant_id: tenant_id,
      period: date_range,
      data: %{
        total_audit_entries: 0,
        actions_by_type: %{},
        unique_users_affected: 0,
        high_risk_activities: []
      }
    }
  end

  defp apply_date_filter(query, nil), do: query
  defp apply_date_filter(query, %{start_date: start_date, end_date: end_date}) do
    from al in query,
      where: al.inserted_at >= ^start_date,
      where: al.inserted_at <= ^end_date
  end

  defp apply_action_type_filter(query, nil), do: query
  defp apply_action_type_filter(query, action_types) when is_list(action_types) do
    from al in query, where: al.action_type in ^action_types
  end

  defp get_session_id do
    # Get current session ID
    ""
  end

  defp get_request_id do
    # Get current request ID
    ""
  end
end
```

## Privacy Controls Implementation

```elixir
defmodule Mcp.Gdpr.PrivacyControls do
  @moduledoc """
  Real-time privacy controls and enforcement mechanisms
  """

  def check_processing_consent(user_id, data_category, purpose) do
    # Check if user has given consent for specific processing
    Mcp.Gdpr.ConsentManager.has_valid_consent?(user_id, data_category, purpose)
  end

  def enforce_data_minimization(user_id, data_types) do
    # Ensure only necessary data types are collected/processed
    allowed_data_types = get_allowed_data_types(user_id)
    Enum.filter(data_types, &(&1 in allowed_data_types))
  end

  def apply_purpose_limitation(user_id, data, intended_purpose) do
    # Ensure data is only used for specified purpose
    consent_purposes = get_consent_purposes(user_id)

    if intended_purpose in consent_purposes do
      {:ok, data}
    else
      {:error, :purpose_limitation_violation}
    end
  end

  def enforce_storage_limitation(user_id, data_category) do
    # Check if data retention period has expired
    retention_policy = get_retention_policy(user_id, data_category)

    if retention_period_expired?(retention_policy) do
      trigger_retention_action(user_id, data_category, retention_policy)
    end
  end

  def ensure_data_accuracy(user_id, data) do
    # Validate data accuracy and provide correction mechanisms
    validation_result = validate_data_accuracy(data)

    case validation_result do
      {:ok, validated_data} -> {:ok, validated_data}
      {:error, validation_errors} ->
        {:error, %{validation_errors: validation_errors, correction_required: true}}
    end
  end

  defp get_allowed_data_types(user_id) do
    # Get allowed data types based on user consents
    []
  end

  defp get_consent_purposes(user_id) do
    # Get purposes for which user has given consent
    []
  end

  defp get_retention_policy(user_id, data_category) do
    # Get retention policy for specific data category
    nil
  end

  defp retention_period_expired?(policy) do
    # Check if retention period has expired
    false
  end

  defp trigger_retention_action(user_id, data_category, policy) do
    # Trigger appropriate retention action (delete, anonymize, etc.)
    :ok
  end

  defp validate_data_accuracy(data) do
    # Validate data accuracy based on business rules
    {:ok, data}
  end
end
```

## Reactor Workflows for Complex GDPR Operations

```elixir
defmodule Mcp.Gdpr.Workflows.CompleteDataErasure do
  use Reactor

  input(:user_id)
  input(:request_id)
  input(:data_categories, default: ["all"])
  input(:verification_required, default: true)

  step :verify_request, fn %{user_id: user_id, verification_required: required} ->
    if required do
      case verify_user_identity(user_id) do
        {:ok, verification_result} -> {:ok, verification_result}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, %{verified: true, method: "admin_bypass"}}
    end
  end

  step :identify_user_data, fn %{user_id: user_id, data_categories: categories} ->
    {:ok, identify_all_user_data(user_id, categories)}
  end

  step :validate_legal_holds, fn %{user_id: user_id} ->
    legal_holds = check_legal_holds(user_id)
    if legal_holds == [] do
      {:ok, :no_legal_holds}
    else
      {:error, {:legal_hold_exists, legal_holds}}
    end
  end

  step :backup_data, fn %{identify_user_data: user_data} ->
    create_backup_record(user_data)
  end

  step :anonymize_data, fn %{identify_user_data: user_data} ->
    Enum.each(user_data, &anonymize_record/1)
    {:ok, :anonymization_complete}
  end

  step :delete_records, fn %{identify_user_data: user_data} ->
    Enum.each(user_data, &delete_record/1)
    {:ok, :deletion_complete}
  end

  step :update_request_status, fn %{request_id: request_id} ->
    update_erasure_request_status(request_id, "completed")
  end

  step :send_confirmation, fn %{user_id: user_id} do
    send_erasure_confirmation(user_id)
  end

  step :audit_complete, fn %{user_id: user_id, request_id: request_id, identify_user_data: user_data} ->
    Mcp.Gdpr.AuditLogger.log_action(
      user_id,
      :data_deleted,
      "complete_data_erasure",
      request_id,
      nil,
      %{records_processed: length(user_data)}
    )
  end

  defp verify_user_identity(user_id) do
    # Implement identity verification logic
    {:ok, %{verified: true, method: "email"}}
  end

  defp identify_all_user_data(user_id, categories) do
    # Implement comprehensive data identification
    []
  end

  defp check_legal_holds(user_id) do
    # Check for any legal holds on user data
    []
  end

  defp create_backup_record(user_data) do
    # Create backup record before deletion
    {:ok, :backup_created}
  end

  defp anonymize_record(record) do
    # Anonymize individual record
    :ok
  end

  defp delete_record(record) do
    # Delete individual record
    :ok
  end

  defp update_erasure_request_status(request_id, status) do
    # Update data subject request status
    {:ok, :status_updated}
  end

  defp send_erasure_confirmation(user_id) do
    # Send confirmation to user
    {:ok, :confirmation_sent}
  end
end
```

This developer guide provides comprehensive technical implementation details for the GDPR compliance system, including privacy engineering patterns, consent management, data subject rights, retention policies, and audit logging for building GDPR-compliant applications on the MCP platform.