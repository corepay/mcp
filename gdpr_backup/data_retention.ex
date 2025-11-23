defmodule Mcp.Gdpr.DataRetention do
  @moduledoc """
  Data retention management module for GDPR compliance.

  This module handles the scheduling and execution of data retention policies
  including automatic cleanup, anonymization, and deletion of user data after
  the retention period expires.
  """

  alias Mcp.Repo
  import Ecto.Query

  @default_retention_days 90
  @grace_period_days 7

  @data_categories [
    "core_identity",    # Email, name, phone, etc.
    "authentication",   # Passwords, tokens, 2FA
    "activity_data",    # Login history, audit logs
    "communication",    # Emails, messages, notifications
    "behavioral",       # Preferences, settings, analytics
    "derived",          # Generated reports, insights
    "financial",        # Payment information (longer retention)
    "legal_hold"        # Data preserved for legal reasons
  ]

  @doc """
  Schedules data retention cleanup for a user.

  ## Parameters
  - user_id: UUID of the user
  - expires_at: DateTime when retention period expires
  - opts: Additional options
    - :categories - List of data categories to include (default: all)
    - :priority - Priority level for processing
    - :custom_retention_days - Override default retention period

  ## Returns
  - {:ok, schedule} on successful scheduling
  - {:error, reason} on failure
  """
  def schedule_cleanup(user_id, expires_at, opts \\ []) do
    categories = Keyword.get(opts, :categories, @data_categories)
    priority = Keyword.get(opts, :priority, "normal")
    custom_retention_days = Keyword.get(opts, :custom_retention_days)

    Repo.transaction(fn ->
      results = Enum.map(categories, fn category ->
        retention_days = calculate_retention_days(category, custom_retention_days)
        category_expires_at = calculate_category_expiry(expires_at, retention_days)

        schedule_data_category_retention(user_id, category, category_expires_at, priority)
      end)

      # Check if all schedules were created successfully
      if Enum.all?(results, fn {status, _} -> status == :ok end) do
        {:ok, Enum.map(results, fn {:ok, schedule} -> schedule end)}
      else
        errors = Enum.filter(results, fn {status, _} -> status == :error end)
        Repo.rollback({:partial_failure, errors})
      end
    end)
  end

  @doc """
  Cancels scheduled data retention cleanup for a user.

  ## Parameters
  - user_id: UUID of the user
  - opts: Additional options
    - :categories - List of categories to cancel (default: all)

  ## Returns
  - :ok on successful cancellation
  - {:error, reason} on failure
  """
  def cancel_cleanup(user_id, opts \\ []) do
    categories = Keyword.get(opts, :categories, @data_categories)

    from(r in "data_retention_schedule",
      where: r.user_id == ^user_id and r.data_category in ^categories,
      where: r.status in ["scheduled", "processing"]
    )
    |> Repo.update_all([set: [status: "cancelled", updated_at: DateTime.utc_now()]], prefix: "platform")
    |> case do
      {count, _} when count >= 0 -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Gets all scheduled retention items that are due for processing.

  ## Parameters
  - opts: Options for filtering
    - :batch_size - Maximum number of items to return
    - :priority - Filter by priority level
    - :category - Filter by data category

  ## Returns
  - {:ok, retention_items} list of items due for processing
  - {:error, reason} on failure
  """
  def get_due_retention_items(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 100)
    priority = Keyword.get(opts, :priority)
    category = Keyword.get(opts, :category)

    current_time = DateTime.utc_now()
    grace_cutoff = DateTime.add(current_time, -@grace_period_days, :day)

    query =
      from(r in "data_retention_schedule",
        where: r.status == "scheduled",
        where: r.expires_at <= ^current_time,
        where: r.expires_at >= ^grace_cutoff,
        order_by: [asc: r.expires_at],
        limit: ^batch_size,
        select: map(r, [:id, :user_id, :data_category, :retention_days, :expires_at,
                       :status, :processing_started_at, :processing_completed_at,
                       :error_details, :created_at, :updated_at]))

    query =
      query
      |> maybe_filter_by_priority(priority)
      |> maybe_filter_by_category(category)

    case Repo.all(query, prefix: "platform") do
      items when is_list(items) -> {:ok, items}
      error -> {:error, error}
    end
  end

  @doc """
  Gets overdue retention items that should be prioritized.

  ## Parameters
  - opts: Options for filtering

  ## Returns
  - {:ok, overdue_items} list of overdue retention items
  - {:error, reason} on failure
  """
  def get_overdue_retention_items(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 50)

    grace_cutoff = DateTime.add(DateTime.utc_now(), -@grace_period_days, :day)

    query =
      from(r in "data_retention_schedule",
        where: r.status == "scheduled",
        where: r.expires_at < ^grace_cutoff,
        order_by: [asc: r.expires_at],
        limit: ^batch_size,
        select: map(r, [:id, :user_id, :data_category, :retention_days, :expires_at,
                       :status, :processing_started_at, :processing_completed_at,
                       :error_details, :created_at, :updated_at]))

    case Repo.all(query, prefix: "platform") do
      items when is_list(items) -> {:ok, items}
      error -> {:error, error}
    end
  end

  @doc """
  Marks a retention item as being processed.

  ## Parameters
  - retention_id: UUID of the retention schedule item

  ## Returns
  - {:ok, retention} on successful update
  - {:error, reason} on failure
  """
  def mark_as_processing(retention_id) do
    from(r in "data_retention_schedule",
      where: r.id == ^retention_id,
      where: r.status == "scheduled"
    )
    |> Repo.update_all([
      set: [
        status: "processing",
        processing_started_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      ]
    ], prefix: "platform")
    |> case do
      {1, [retention]} -> {:ok, retention}
      {0, []} -> {:error, :not_found_or_already_processed}
      error -> {:error, error}
    end
  end

  @doc """
  Marks a retention item as completed successfully.

  ## Parameters
  - retention_id: UUID of the retention schedule item

  ## Returns
  - {:ok, retention} on successful update
  - {:error, reason} on failure
  """
  def mark_as_completed(retention_id) do
    from(r in "data_retention_schedule",
      where: r.id == ^retention_id,
      where: r.status == "processing"
    )
    |> Repo.update_all([
      set: [
        status: "processed",
        processing_completed_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      ]
    ], prefix: "platform")
    |> case do
      {1, [retention]} -> {:ok, retention}
      {0, []} -> {:error, :not_found_or_not_processing}
      error -> {:error, error}
    end
  end

  @doc """
  Marks a retention item as failed with error details.

  ## Parameters
  - retention_id: UUID of the retention schedule item
  - error_details: Map containing error information

  ## Returns
  - {:ok, retention} on successful update
  - {:error, reason} on failure
  """
  def mark_as_failed(retention_id, error_details) do
    error_json = Jason.encode!(error_details)

    from(r in "data_retention_schedule",
      where: r.id == ^retention_id,
      where: r.status == "processing"
    )
    |> Repo.update_all([
      set: [
        status: "failed",
        error_details: error_json,
        updated_at: DateTime.utc_now()
      ]
    ], prefix: "platform")
    |> case do
      {1, [retention]} -> {:ok, retention}
      {0, []} -> {:error, :not_found_or_not_processing}
      error -> {:error, error}
    end
  end

  @doc """
  Gets retention status for a user.

  ## Parameters
  - user_id: UUID of the user

  ## Returns
  - {:ok, retention_status} map containing retention information
  - {:error, reason} on failure
  """
  def get_user_retention_status(user_id) do
    query =
      from(r in "data_retention_schedule",
        where: r.user_id == ^user_id,
        select: map(r, [:data_category, :retention_days, :expires_at, :status,
                       :processing_started_at, :processing_completed_at, :error_details]))

    case Repo.all(query, prefix: "platform") do
      records when is_list(records) ->
        status_by_category = Enum.group_by(records, & &1.data_category)

        overall_status = determine_overall_retention_status(status_by_category)

        {:ok, %{
          user_id: user_id,
          overall_status: overall_status,
          categories: status_by_category,
          summary: generate_retention_summary(status_by_category),
          checked_at: DateTime.utc_now()
        }}
      error -> {:error, error}
    end
  end

  @doc """
  Gets retention statistics for monitoring and reporting.

  ## Parameters
  - opts: Options for statistics calculation

  ## Returns
  - Map containing retention statistics
  """
  def get_retention_statistics(opts \\ []) do
    # Get counts by status
    status_counts =
      from(r in "data_retention_schedule",
        group_by: r.status,
        select: {r.status, count(r.id)})
      |> Repo.all(prefix: "platform")
      |> Map.new()

    # Get overdue count
    grace_cutoff = DateTime.add(DateTime.utc_now(), -@grace_period_days, :day)
    overdue_count =
      from(r in "data_retention_schedule",
        where: r.status == "scheduled" and r.expires_at < ^grace_cutoff,
        select: count(r.id))
      |> Repo.one(prefix: "platform") || 0

    # Get category breakdown
    category_counts =
      from(r in "data_retention_schedule",
        group_by: r.data_category,
        select: {r.data_category, count(r.id)})
      |> Repo.all(prefix: "platform")
      |> Map.new()

    # Get average retention periods
    avg_retention_days =
      from(r in "data_retention_schedule",
        where: r.status != "cancelled",
        select: avg(r.retention_days))
      |> Repo.one(prefix: "platform") || @default_retention_days

    %{
      total_scheduled: Map.get(status_counts, "scheduled", 0),
      processing: Map.get(status_counts, "processing", 0),
      processed: Map.get(status_counts, "processed", 0),
      failed: Map.get(status_counts, "failed", 0),
      cancelled: Map.get(status_counts, "cancelled", 0),
      overdue: overdue_count,
      by_category: category_counts,
      average_retention_days: round(avg_retention_days),
      grace_period_days: @grace_period_days,
      calculated_at: DateTime.utc_now()
    }
  end

  @doc """
  Calculates retention period for a specific data category.

  ## Parameters
  - category: Data category string
  - custom_days: Optional custom retention period

  ## Returns
  - Integer number of days for retention
  """
  def calculate_retention_days(category, custom_days \\ nil) do
    case custom_days do
      days when is_integer(days) and days > 0 -> days
      _ -> get_default_retention_days(category)
    end
  end

  # Private functions

  defp schedule_data_category_retention(user_id, category, expires_at, priority) do
    retention_days = calculate_retention_days(category)

    retention_data = %{
      user_id: user_id,
      data_category: category,
      retention_days: retention_days,
      expires_at: expires_at,
      status: "scheduled",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    case Repo.insert_all("data_retention_schedule", [retention_data], prefix: "platform") do
      {1, [schedule]} -> {:ok, schedule}
      error -> {:error, error}
    end
  end

  defp calculate_category_expiry(base_expires_at, retention_days) do
    DateTime.add(base_expires_at, retention_days, :day)
  end

  defp get_default_retention_days(category) do
    case category do
      "core_identity" -> 90
      "authentication" -> 0  # Immediate deletion
      "activity_data" -> 90
      "communication" -> 90
      "behavioral" -> 90
      "derived" -> 90
      "financial" -> 2555  # 7 years for financial data
      "legal_hold" -> 3650  # 10 years for legal holds
      _ -> @default_retention_days
    end
  end

  defp maybe_filter_by_priority(query, priority) do
    if priority do
      # Assuming priority is stored in details or another field
      # This is a placeholder implementation
      query
    else
      query
    end
  end

  defp maybe_filter_by_category(query, category) do
    if category do
      from(r in query, where: r.data_category == ^category)
    else
      query
    end
  end

  defp determine_overall_retention_status(status_by_category) do
    statuses = Enum.flat_map(status_by_category, fn {_category, records} ->
      Enum.map(records, & &1.status)
    end)

    cond do
      Enum.any?(statuses, &(&1 == "failed")) -> "failed"
      Enum.any?(statuses, &(&1 == "processing")) -> "processing"
      Enum.any?(statuses, &(&1 == "scheduled")) -> "scheduled"
      Enum.all?(statuses, &(&1 == "processed")) -> "completed"
      Enum.all?(statuses, &(&1 == "cancelled")) -> "cancelled"
      true -> "unknown"
    end
  end

  defp generate_retention_summary(status_by_category) do
    Enum.map(status_by_category, fn {category, records} ->
      latest_record = Enum.max_by(records, & &1.created_at, DateTime)

      %{
        category: category,
        status: latest_record.status,
        expires_at: latest_record.expires_at,
        days_until_expiry: calculate_days_until_expiry(latest_record.expires_at)
      }
    end)
    |> Enum.sort_by(& &1.days_until_expiry)
  end

  defp calculate_days_until_expiry(expires_at) do
    now = DateTime.utc_now()
    DateTime.diff(expires_at, now, :day)
  end
end