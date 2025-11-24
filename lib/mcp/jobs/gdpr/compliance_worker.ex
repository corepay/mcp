defmodule Mcp.Jobs.Gdpr.ComplianceWorker do
  @moduledoc """
  Background worker for GDPR compliance monitoring and reporting.

  This worker handles:
  - Daily compliance monitoring and checks
  - GDPR compliance scoring and metrics
  - Automated compliance report generation
  - Retention policy enforcement
  - Anomaly detection and alerts
  - Legal hold monitoring and management
  """

  use Oban.Worker, queue: :gdpr_compliance, max_attempts: 1
  require Logger

  alias Mcp.Repo
  import Ecto.Query

  @impl true
  def perform(%Oban.Job{args: %{"type" => "daily_monitoring"}}) do
    Logger.info("Running daily GDPR compliance monitoring")

    perform_daily_compliance_check()
  end

  def perform(%Oban.Job{args: %{"type" => "weekly_report"}}) do
    Logger.info("Generating weekly GDPR compliance report")

    generate_weekly_compliance_report()
  end

  def perform(%Oban.Job{args: %{"type" => "retention_enforcement"}}) do
    Logger.info("Enforcing GDPR retention policies")

    enforce_retention_policies()
  end

  def perform(%Oban.Job{args: %{"type" => "legal_hold_check"}}) do
    Logger.info("Checking GDPR legal holds")

    check_legal_holds()
  end

  def perform(%Oban.Job{args: args}) when args == %{} do
    # Called by Oban Cron plugin with empty args
    perform_daily_compliance_check()
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid arguments for ComplianceWorker: #{inspect(args)}")
    {:error, :invalid_arguments}
  end

  # Private functions

  defp perform_daily_compliance_check do
    compliance_metrics = collect_compliance_metrics()
    compliance_score = calculate_compliance_score(compliance_metrics)
    issues = identify_compliance_issues(compliance_metrics)

    # Log compliance status
    Logger.info("Daily compliance check completed - Score: #{compliance_score}%")

    # Alert on critical issues
    if length(issues) > 0 do
      alert_compliance_issues(issues)
    end

    # Store metrics for reporting
    store_compliance_metrics(compliance_metrics, compliance_score)

    {:ok, %{
      score: compliance_score,
      issues_count: length(issues),
      metrics: compliance_metrics,
      timestamp: DateTime.utc_now()
    }}
  end

  defp generate_weekly_compliance_report do
    start_date = DateTime.add(DateTime.utc_now(), -7, :day)
    end_date = DateTime.utc_now()

    # Collect weekly data
    weekly_data = %{
      period_start: start_date,
      period_end: end_date,
      total_users: get_total_user_count(),
      deleted_users: get_deleted_user_count(start_date),
      anonymized_users: get_anonymized_user_count(start_date),
      exports_processed: get_export_count(start_date),
      consent_changes: get_consent_changes_count(start_date),
      legal_holds: get_active_legal_holds_count(),
      retention_overdue: get_overdue_retention_count()
    }

    # Calculate compliance metrics
    compliance_score = calculate_weekly_compliance_score(weekly_data)
    recommendations = generate_compliance_recommendations(weekly_data)

    # Generate and store report
    report = %{
      weekly_data: weekly_data,
      compliance_score: compliance_score,
      recommendations: recommendations,
      generated_at: DateTime.utc_now()
    }

    store_compliance_report(report)
    log_weekly_compliance_summary(report)

    {:ok, report}
  end

  defp enforce_retention_policies do
    # Check for overdue anonymizations
    overdue_count = get_overdue_retention_count()

    if overdue_count > 0 do
      Logger.warning("Found #{overdue_count} overdue anonymizations")
      schedule_anonymization_jobs()
    end

    # Check for expired exports
    expired_count = get_expired_exports_count()

    if expired_count > 0 do
      Logger.info("Found #{expired_count} expired exports")
      schedule_export_cleanup_jobs()
    end

    # Check for old audit entries
    old_audit_count = get_old_audit_entries_count()

    if old_audit_count > 0 do
      Logger.info("Found #{old_audit_count} old audit entries")
      schedule_audit_cleanup_jobs()
    end

    {:ok, %{
      overdue_anonymizations: overdue_count,
      expired_exports: expired_count,
      old_audit_entries: old_audit_count,
      timestamp: DateTime.utc_now()
    }}
  end

  defp check_legal_holds do
    # Check for legal holds that are approaching expiration
    approaching_expiration = get_legal_holds_approaching_expiration()

    # Check for legal holds that have expired but weren't released
    expired_holds = get_expired_legal_holds()

    # Alert on legal hold status
    legal_hold_summary = %{
      total_active: get_active_legal_holds_count(),
      approaching_expiration: length(approaching_expiration),
      expired_unreleased: length(expired_holds),
      timestamp: DateTime.utc_now()
    }

    if length(expired_holds) > 0 do
      Logger.warning("Found #{length(expired_holds)} legal holds that expired but weren't released")
    end

    {:ok, legal_hold_summary}
  end

  # Compliance data collection functions

  defp collect_compliance_metrics do
    %{
      total_users: get_total_user_count(),
      active_users: get_active_user_count(),
      deleted_users: get_deleted_user_count(),
      anonymized_users: get_anonymized_user_count(),
      pending_deletions: get_pending_deletion_count(),
      active_exports: get_active_export_count(),
      active_consents: get_active_consent_count(),
      legal_holds: get_active_legal_holds_count(),
      audit_entries_24h: get_audit_entries_count(24),
      audit_entries_7d: get_audit_entries_count(7 * 24)
    }
  end

  defp calculate_compliance_score(metrics) do
    # Weighted compliance scoring
    base_score = 100

    # Deductions for compliance issues
    score = base_score
    |> deduct_overdue_anonymizations(metrics.total_users, metrics.anonymized_users)
    |> deduct_unreleased_legal_holds(metrics.legal_holds)
    |> deduct_missing_user_consents(metrics.active_users, metrics.active_consents)
    |> deduct_export_cleanup(metrics.active_exports)

    max(score, 0)
  end

  defp deduct_overdue_anonymizations(score, total_users, anonymized_users) do
    if total_users > 0 do
      expected_anonymized = total_users * 0.01  # 1% should be anonymized over time
      if anonymized_users > expected_anonymized do
        score - 5  # Penalty for not processing anonymizations
      else
        score
      end
    else
      score
    end
  end

  defp deduct_unreleased_legal_holds(score, legal_holds) do
    # Small deduction if too many legal holds (might indicate process issues)
    if legal_holds > 100 do
      score - 2
    else
      score
    end
  end

  defp deduct_missing_user_consents(score, active_users, active_consents) do
    if active_users > 0 do
      consent_rate = active_consents / active_users
      if consent_rate < 0.95 do  # 95% consent rate target
        score - 10
      else
        score
      end
    else
      score
    end
  end

  defp deduct_export_cleanup(score, active_exports) do
    # Deduction for too many active exports (might indicate cleanup issues)
    if active_exports > 50 do
      score - 5
    else
      score
    end
  end

  defp identify_compliance_issues(metrics) do
    issues = []

    issues =
      if metrics.overdue_anonymizations > 0 do
        ["Overdue anonymizations: #{metrics.overdue_anonymizations}" | issues]
      else
        issues
      end

    issues =
      if metrics.expired_exports > 0 do
        ["Expired exports not cleaned up: #{metrics.expired_exports}" | issues]
      else
        issues
      end

    issues =
      if metrics.legal_holds > 100 do
        ["High number of legal holds: #{metrics.legal_holds}" | issues]
      else
        issues
      end

    issues
  end

  defp alert_compliance_issues(issues) do
    # In a real implementation, this would send alerts via email, Slack, etc.
    Logger.error("GDPR Compliance Issues Detected:")
    Enum.each(issues, &Logger.error("  - #{&1}"))
  end

  defp store_compliance_metrics(_metrics, score) do
    # Store metrics for reporting and analysis
    # In a real implementation, this would store to a metrics table
    Logger.debug("Storing compliance metrics: score #{score}")
    :ok
  end

  # Weekly report functions

  defp calculate_weekly_compliance_score(weekly_data) do
    # Calculate score based on weekly performance
    base_score = 100

    score = base_score
    |> deduct_processing_delays(weekly_data)
    |> deduct_legal_hold_duration(weekly_data)
    |> deduct_retention_compliance(weekly_data)

    max(score, 0)
  end

  defp deduct_processing_delays(score, data) do
    # Check if deletions are processed within SLA
    if data.pending_deletions > 10 do
      score - 15
    else
      score
    end
  end

  defp deduct_legal_hold_duration(score, _data) do
    # Check if legal holds are resolved within reasonable time
    score  # Placeholder for more complex logic
  end

  defp deduct_retention_compliance(score, data) do
    # Check if data retention policies are followed
    if data.retention_overdue > 0 do
      score - 20
    else
      score
    end
  end

  defp generate_compliance_recommendations(weekly_data) do
    recommendations = []

    recommendations =
      if weekly_data.pending_deletions > 10 do
        ["Consider reviewing deletion processing workflow to reduce backlog" | recommendations]
      else
        recommendations
      end

    recommendations =
      if weekly_data.legal_holds > 50 do
        ["Review legal hold processes to ensure timely resolution" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp store_compliance_report(_report) do
    # Store the weekly compliance report
    Logger.debug("Storing weekly compliance report")
    :ok
  end

  defp log_weekly_compliance_summary(report) do
    Logger.info("Weekly Compliance Report:")
    Logger.info("  Compliance Score: #{report.compliance_score}%")
    Logger.info("  Total Users: #{report.weekly_data.total_users}")
    Logger.info("  Deleted Users: #{report.weekly_data.deleted_users}")
    Logger.info("  Anonymized Users: #{report.weekly_data.anonymized_users}")
    Logger.info("  Exports Processed: #{report.weekly_data.exports_processed}")
    Logger.info("  Legal Holds: #{report.weekly_data.legal_holds}")
  end

  # Data collection helper functions

  defp get_total_user_count do
    Repo.aggregate(from(u in "mcp_users"), :count, :id)
  end

  defp get_active_user_count do
    from(u in "mcp_users", where: u.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  defp get_deleted_user_count(since \\ nil) do
    query = from(u in "mcp_users", where: u.status == "deleted")
    query = if since, do: where(query, [u], u.deleted_at >= ^since), else: query
    Repo.aggregate(query, :count, :id)
  end

  defp get_anonymized_user_count(since \\ nil) do
    query = from(u in "mcp_users", where: not is_nil(u.anonymized_at))
    query = if since, do: where(query, [u], u.anonymized_at >= ^since), else: query
    Repo.aggregate(query, :count, :id)
  end

  defp get_pending_deletion_count do
    from(u in "mcp_users",
      where: u.status == "deleted",
      where: is_nil(u.anonymized_at))
    |> Repo.aggregate(:count, :id)
  end

  defp get_active_export_count do
    from(e in "gdpr_exports",
      where: e.status in ["pending", "processing"])
    |> Repo.aggregate(:count, :id)
  end

  defp get_active_consent_count do
    from(c in "gdpr_consent",
      where: c.status == "granted")
    |> Repo.aggregate(:count, :id)
  end

  defp get_active_legal_holds_count do
    from(lh in "gdpr_legal_holds",
      where: is_nil(lh.released_at))
    |> Repo.aggregate(:count, :id)
  end

  defp get_audit_entries_count(hours_ago) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours_ago * 60 * 60, :second)
    from(a in "gdpr_audit_trail", where: a.inserted_at >= ^cutoff_time)
    |> Repo.aggregate(:count, :id)
  end

  defp get_export_count(since) do
    query = from(e in "gdpr_exports", where: e.status == "completed")
    query = if since, do: where(query, [e], e.completed_at >= ^since), else: query
    Repo.aggregate(query, :count, :id)
  end

  defp get_consent_changes_count(since) do
    query = from(c in "gdpr_consent")
    query = if since, do: where(query, [c], c.updated_at >= ^since), else: query
    Repo.aggregate(query, :count, :id)
  end

  defp get_overdue_retention_count do
    cutoff_time = DateTime.utc_now()
    from(u in "mcp_users",
      where: u.status == "deleted",
      where: not is_nil(u.gdpr_retention_expires_at),
      where: u.gdpr_retention_expires_at <= ^cutoff_time,
      where: is_nil(u.anonymized_at))
    |> Repo.aggregate(:count, :id)
  end

  defp get_expired_exports_count do
    cutoff_time = DateTime.add(DateTime.utc_now(), -7, :day)
    from(e in "gdpr_exports",
      where: e.status == "completed",
      where: e.expires_at <= ^cutoff_time)
    |> Repo.aggregate(:count, :id)
  end

  defp get_old_audit_entries_count do
    # Consider entries older than 2 years as old
    cutoff_time = DateTime.add(DateTime.utc_now(), -730, :day)
    from(a in "gdpr_audit_trail", where: a.inserted_at <= ^cutoff_time)
    |> Repo.aggregate(:count, :id)
  end

  defp get_legal_holds_approaching_expiration do
    # Legal holds expiring within 7 days
    cutoff_time = DateTime.add(DateTime.utc_now(), 7, :day)
    from(lh in "gdpr_legal_holds",
      where: is_nil(lh.released_at),
      where: lh.expires_at <= ^cutoff_time)
    |> Repo.all()
  end

  defp get_expired_legal_holds do
    cutoff_time = DateTime.utc_now()
    from(lh in "gdpr_legal_holds",
      where: is_nil(lh.released_at),
      where: lh.expires_at <= ^cutoff_time)
    |> Repo.all()
  end

  # Job scheduling functions

  defp schedule_anonymization_jobs do
    # Schedule individual anonymization jobs for overdue users
    overdue_users = get_overdue_user_ids()

    Enum.each(overdue_users, fn user_id ->
      Mcp.Jobs.Gdpr.AnonymizationWorker.new(%{
        "user_id" => user_id,
        "mode" => "full"
      })
      |> Oban.insert()
    end)
  end

  defp schedule_export_cleanup_jobs do
    Mcp.Jobs.Gdpr.RetentionCleanupWorker.new(%{
      "type" => "export_cleanup"
    })
    |> Oban.insert()
  end

  defp schedule_audit_cleanup_jobs do
    Mcp.Jobs.Gdpr.RetentionCleanupWorker.new(%{
      "type" => "audit_cleanup"
    })
    |> Oban.insert()
  end

  defp get_overdue_user_ids do
    cutoff_time = DateTime.utc_now()
    from(u in "mcp_users",
      where: u.status == "deleted",
      where: not is_nil(u.gdpr_retention_expires_at),
      where: u.gdpr_retention_expires_at <= ^cutoff_time,
      where: is_nil(u.anonymized_at),
      select: u.id)
    |> Repo.all()
  end
end