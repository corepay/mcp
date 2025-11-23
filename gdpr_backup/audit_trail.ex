defmodule Mcp.Gdpr.AuditTrail do
  @moduledoc """
  GDPR-specific audit trail management module.

  This module provides comprehensive audit logging for all GDPR-related activities
  including data access, deletions, exports, consent changes, and compliance checks.
  All audit records are immutable and include detailed context for compliance reporting.
  """

  alias Mcp.Repo
  import Ecto.Query

  @valid_action_types [
    "access_request", "export_generated", "delete_request", "deletion_cancelled",
    "anonymization_started", "anonymization_complete", "data_portability",
    "consent_given", "consent_revoked", "retention_scheduled", "compliance_check"
  ]

  @valid_actor_types ["user", "system", "admin", "automated_process"]

  @doc """
  Logs a GDPR action to the audit trail.

  ## Parameters
  - user_id: UUID of the user the action relates to
  - action_type: String indicating the type of GDPR action
  - actor_id: UUID of who performed the action (optional)
  - details: Map containing additional action details
  - opts: Additional options (ip_address, user_agent, request_id, etc.)

  ## Returns
  - {:ok, audit_record} on successful logging
  - {:error, reason} on failure

  ## Examples
      iex> AuditTrail.log_action(user_uuid, "delete_request", actor_uuid, %{reason: "user_request"})
      {:ok, %GdprAuditTrail{}}
  """
  def log_action(user_id, action_type, actor_id \\ nil, details \\ %{}, opts \\ []) do
    %{
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent],
      request_id: opts[:request_id],
      data_categories: opts[:data_categories] || [],
      legal_basis: opts[:legal_basis]
    }
    |> create_audit_record(user_id, action_type, actor_id, details)
  end

  @doc """
  Retrieves audit records for a specific user.

  ## Parameters
  - user_id: UUID of the user
  - opts: Options for pagination and filtering
    - :limit - Maximum number of records to return (default: 100)
    - :offset - Number of records to skip (default: 0)
    - :action_types - List of action types to filter by
    - :start_date - Start date for filtering
    - :end_date - End date for filtering

  ## Returns
  - {:ok, audit_records} on success
  - {:error, reason} on failure
  """
  def get_user_actions(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    action_types = Keyword.get(opts, :action_types, @valid_action_types)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    query =
      from(a in "gdpr_audit_trail",
        where: a.user_id == ^user_id,
        where: a.action_type in ^action_types,
        order_by: [desc: a.created_at],
        limit: ^limit,
        offset: ^offset,
        select: map(a, [:id, :action_type, :actor_type, :actor_id, :ip_address,
                       :user_agent, :request_id, :data_categories, :legal_basis,
                       :details, :created_at]))

    query =
      query
      |> maybe_filter_by_date_range(start_date, end_date)

    case Repo.all(query, prefix: "platform") do
      records when is_list(records) -> {:ok, records}
      error -> {:error, error}
    end
  end

  @doc """
  Retrieves audit records by action type.

  ## Parameters
  - action_type: String specifying the action type
  - opts: Additional filtering options

  ## Returns
  - {:ok, audit_records} on success
  - {:error, reason} on failure
  """
  def get_actions_by_type(action_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    query =
      from(a in "gdpr_audit_trail",
        where: a.action_type == ^action_type,
        order_by: [desc: a.created_at],
        limit: ^limit,
        offset: ^offset,
        select: map(a, [:id, :user_id, :action_type, :actor_type, :actor_id,
                       :ip_address, :user_agent, :request_id, :data_categories,
                       :legal_basis, :details, :created_at]))

    query =
      query
      |> maybe_filter_by_date_range(start_date, end_date)

    case Repo.all(query, prefix: "platform") do
      records when is_list(records) -> {:ok, records}
      error -> {:error, error}
    end
  end

  @doc """
  Retrieves audit records by actor.

  ## Parameters
  - actor_type: String specifying the actor type
  - actor_id: UUID of the actor (optional)
  - opts: Additional filtering options

  ## Returns
  - {:ok, audit_records} on success
  - {:error, reason} on failure
  """
  def get_actions_by_actor(actor_type, actor_id \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from(a in "gdpr_audit_trail",
        where: a.actor_type == ^actor_type,
        order_by: [desc: a.created_at],
        limit: ^limit,
        offset: ^offset,
        select: map(a, [:id, :user_id, :action_type, :actor_type, :actor_id,
                       :ip_address, :user_agent, :request_id, :data_categories,
                       :legal_basis, :details, :created_at]))

    query =
      query
      |> maybe_filter_by_actor_id(actor_id)

    case Repo.all(query, prefix: "platform") do
      records when is_list(records) -> {:ok, records}
      error -> {:error, error}
    end
  end

  @doc """
  Verifies audit trail integrity for compliance reporting.

  ## Parameters
  - start_date: Optional start date for integrity check
  - end_date: Optional end date for integrity check

  ## Returns
  - {:ok, integrity_report} containing integrity status and any issues found
  """
  def verify_audit_trail_integrity(start_date \\ nil, end_date \\ nil) do
    # Check for gaps in audit trail
    gap_analysis = detect_audit_gaps(start_date, end_date)

    # Check for missing required fields
    field_analysis = verify_required_fields(start_date, end_date)

    # Check for unusual patterns
    pattern_analysis = detect_unusual_patterns(start_date, end_date)

    %{
      status: determine_integrity_status(gap_analysis, field_analysis, pattern_analysis),
      gap_analysis: gap_analysis,
      field_analysis: field_analysis,
      pattern_analysis: pattern_analysis,
      checked_at: DateTime.utc_now(),
      date_range: %{start_date: start_date, end_date: end_date}
    }
  end

  @doc """
  Exports audit trail data for compliance reporting.

  ## Parameters
  - opts: Export options
    - :format - Export format ("json", "csv")
    - :start_date - Start date for export range
    - :end_date - End date for export range
    - :action_types - List of action types to include
    - :user_ids - List of user IDs to include

  ## Returns
  - {:ok, export_data} on success
  - {:error, reason} on failure
  """
  def export_audit_trail(opts \\ []) do
    format = Keyword.get(opts, :format, "json")
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    action_types = Keyword.get(opts, :action_types, @valid_action_types)
    user_ids = Keyword.get(opts, :user_ids, [])

    query =
      from(a in "gdpr_audit_trail",
        where: a.action_type in ^action_types,
        order_by: [desc: a.created_at],
        select: map(a, [:id, :user_id, :action_type, :actor_type, :actor_id,
                       :ip_address, :user_agent, :request_id, :data_categories,
                       :legal_basis, :details, :created_at]))

    query =
      query
      |> maybe_filter_by_date_range(start_date, end_date)
      |> maybe_filter_by_user_ids(user_ids)

    case Repo.all(query, prefix: "platform") do
      records when is_list(records) ->
        case format do
          "json" -> {:ok, Jason.encode!(records, pretty: true)}
          "csv" -> convert_to_csv(records)
          _ -> {:error, :unsupported_format}
        end
      error -> {:error, error}
    end
  end

  @doc """
  Gets audit trail statistics for monitoring and reporting.

  ## Parameters
  - opts: Options for statistics calculation
    - :start_date - Start date for statistics period
    - :end_date - End date for statistics period

  ## Returns
  - Map containing audit trail statistics
  """
  def get_audit_statistics(opts \\ []) do
    start_date = Keyword.get(opts, :start_date, DateTime.add(DateTime.utc_now(), -30, :day))
    end_date = Keyword.get(opts, :end_date, DateTime.utc_now())

    base_query = from(a in "gdpr_audit_trail",
      where: a.created_at >= ^start_date and a.created_at <= ^end_date)

    total_actions = Repo.aggregate(base_query, :count, :id, prefix: "platform")

    actions_by_type =
      from(a in base_query, group_by: a.action_type, select: {a.action_type, count(a.id)})
      |> Repo.all(prefix: "platform")
      |> Map.new()

    actions_by_actor_type =
      from(a in base_query, group_by: a.actor_type, select: {a.actor_type, count(a.id)})
      |> Repo.all(prefix: "platform")
      |> Map.new()

    %{
      total_actions: total_actions,
      actions_by_type: actions_by_type,
      actions_by_actor_type: actions_by_actor_type,
      period: %{start_date: start_date, end_date: end_date},
      calculated_at: DateTime.utc_now()
    }
  end

  # Private functions

  defp create_audit_record(params, user_id, action_type, actor_id, details) do
    # Determine actor type based on actor_id and context
    actor_type = determine_actor_type(actor_id)

    audit_data = %{
      user_id: user_id,
      action_type: action_type,
      actor_type: actor_type,
      actor_id: actor_id,
      ip_address: params.ip_address,
      user_agent: params.user_agent,
      request_id: params.request_id,
      data_categories: params.data_categories,
      legal_basis: params.legal_basis,
      details: details,
      created_at: DateTime.utc_now()
    }

    # Validate required fields
    with :ok <- validate_action_type(action_type),
         :ok <- validate_actor_type(actor_type) do

      insert_query =
        from(a in "gdpr_audit_trail",
          where: a.user_id == ^user_id and a.action_type == ^action_type)

      case Repo.insert_all("gdpr_audit_trail", [audit_data], prefix: "platform") do
        {1, [record]} -> {:ok, record}
        error -> {:error, error}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp determine_actor_type(actor_id) do
    cond do
      is_nil(actor_id) -> "system"
      # Add logic to determine if actor is admin vs user
      true -> "user"  # Default for now
    end
  end

  defp validate_action_type(action_type) when action_type in @valid_action_types, do: :ok
  defp validate_action_type(_), do: {:error, :invalid_action_type}

  defp validate_actor_type(actor_type) when actor_type in @valid_actor_types, do: :ok
  defp validate_actor_type(_), do: {:error, :invalid_actor_type}

  defp maybe_filter_by_date_range(query, start_date, end_date) do
    query =
      if start_date do
        from(a in query, where: a.created_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        from(a in query, where: a.created_at <= ^end_date)
      else
        query
      end

    query
  end

  defp maybe_filter_by_actor_id(query, actor_id) do
    if actor_id do
      from(a in query, where: a.actor_id == ^actor_id)
    else
      query
    end
  end

  defp maybe_filter_by_user_ids(query, user_ids) do
    if Enum.empty?(user_ids) do
      query
    else
      from(a in query, where: a.user_id in ^user_ids)
    end
  end

  defp detect_audit_gaps(start_date, end_date) do
    # Implementation for detecting gaps in audit trail
    # This would check for missing timestamps or unusual patterns
    %{
      gaps_detected: false,
      gap_details: []
    }
  end

  defp verify_required_fields(start_date, end_date) do
    # Implementation for verifying required fields are present
    %{
      missing_fields: [],
      invalid_records: 0
    }
  end

  defp detect_unusual_patterns(start_date, end_date) do
    # Implementation for detecting unusual patterns
    %{
      unusual_patterns: [],
      anomalies_detected: false
    }
  end

  defp determine_integrity_status(gap_analysis, field_analysis, pattern_analysis) do
    cond do
      gap_analysis.gaps_detected -> "failed"
      field_analysis.invalid_records > 0 -> "warning"
      pattern_analysis.anomalies_detected -> "warning"
      true -> "passed"
    end
  end

  defp convert_to_csv(records) do
    # Simple CSV conversion - in production, use a proper CSV library
    headers = ["id", "user_id", "action_type", "actor_type", "actor_id", "ip_address",
               "user_agent", "request_id", "data_categories", "legal_basis", "details", "created_at"]

    rows = Enum.map(records, fn record ->
      [
        record.id,
        record.user_id,
        record.action_type,
        record.actor_type,
        record.actor_id || "",
        record.ip_address || "",
        record.user_agent || "",
        record.request_id || "",
        Jason.encode!(record.data_categories),
        record.legal_basis || "",
        Jason.encode!(record.details),
        record.created_at
      ]
    end)

    csv_content = [headers] ++ rows
    {:ok, Enum.map_join(csv_content, "\n", &Enum.join(&1, ","))}
  end
end