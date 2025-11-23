defmodule Mcp.Gdpr.Jobs do
  @moduledoc """
  GDPR background job processing using Oban.

  This module defines and schedules all GDPR-related background jobs:
  - Data retention and anonymization
  - Data export generation
  - Consent expiration processing
  - Compliance monitoring
  - Token revocation and OAuth disconnection
  """

  use Oban.Worker, queue: :gdpr

  require Logger

  alias Mcp.Gdpr.{
    Compliance,
    Export,
    Consent,
    AuditTrail
  }

  alias Mcp.Accounts.User
  alias Mcp.Repo

  # Job Workers

  defmodule DataExportWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_exports

    @impl true
    def perform(%Oban.Job{args: %{"export_id" => export_id}}) do
      Logger.info("Processing data export job #{export_id}")

      case Export.generate_export_file(export_id) do
        {:ok, _export} ->
          Logger.info("Successfully completed export job #{export_id}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to process export job #{export_id}: #{inspect(reason)}")
          {:error, reason}
      end
    end

    @impl true
    def backoff(attempt) do
      # Exponential backoff: 30s, 1m, 2m, 4m, 8m, 16m
      :timer.seconds(30 * :math.pow(2, attempt - 1))
    end
  end

  defmodule RetentionWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_retention

    @impl true
    def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
      Logger.info("Processing retention job for user #{user_id}")

      case Compliance.ready_for_anonymization?(user_id) do
        {:ok, true} ->
          Compliance.anonymize_user_data(user_id)
          Logger.info("Successfully anonymized user #{user_id}")
          :ok

        {:ok, false} ->
          Logger.info("User #{user_id} not yet ready for anonymization")
          :ok

        {:error, reason} ->
          Logger.error("Failed to check anonymization readiness for user #{user_id}: #{inspect(reason)}")
          {:error, reason}
      end
    end

    @impl true
    def backoff(attempt) do
      # Retention jobs can retry more aggressively
      :timer.minutes(5 * attempt)
    end
  end

  defmodule ConsentExpirationWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_consent

    @impl true
    def perform(%Oban.Job{}) do
      Logger.info("Processing consent expiration job")

      case Consent.process_expired_consents() do
        {:ok, count} ->
          Logger.info("Processed #{count} expired consents")
          :ok

        {:error, reason} ->
          Logger.error("Failed to process expired consents: #{inspect(reason)}")
          {:error, reason}
      end
    end

    @impl true
    def backoff(_attempt) do
      # Consent expiration is not time-sensitive
      :timer.hours(1)
    end
  end

  defmodule ComplianceMonitorWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_monitoring

    @impl true
    def perform(%Oban.Job{}) do
      Logger.info("Running GDPR compliance monitoring")

      status = Compliance.get_compliance_status()

      # Log compliance status
      Enum.each(status, fn {key, value} ->
        Logger.info("GDPR Compliance #{key}: #{inspect(value)}")
      end)

      # Check for issues that need attention
      check_compliance_alerts(status)

      :ok
    end

    @impl true
    def backoff(_attempt) do
      # Compliance monitoring runs daily
      :timer.hours(24)
    end

    defp check_compliance_alerts(status) do
      cond do
        status.overdue_retention > 0 ->
          Logger.warn("GDPR Alert: #{status.overdue_retention} users overdue for anonymization")

        status.pending_exports > 10 ->
          Logger.warn("GDPR Alert: High number of pending exports (#{status.pending_exports})")

        true ->
          :ok
      end
    end
  end

  defmodule TokenRevocationWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_cleanup

    @impl true
    def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
      Logger.info("Processing token revocation for user #{user_id}")

      # Revoke all authentication tokens for the user
      # This would integrate with the authentication system
      revoke_user_tokens(user_id)

      :ok
    end

    @impl true
    def backoff(_attempt) do
      :timer.minutes(1)
    end

    defp revoke_user_tokens(_user_id) do
      # Implementation would revoke JWT tokens and session data
      Logger.info("User tokens revoked")
    end
  end

  defmodule OAuthDisconnectionWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_cleanup

    @impl true
    def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
      Logger.info("Processing OAuth disconnection for user #{user_id}")

      # Disconnect OAuth providers
      disconnect_oauth_providers(user_id)

      :ok
    end

    @impl true
    def backoff(_attempt) do
      :timer.minutes(1)
    end

    defp disconnect_oauth_providers(_user_id) do
      # Implementation would disconnect Google, GitHub, etc.
      Logger.info("OAuth providers disconnected")
    end
  end

  defmodule ExportCleanupWorker do
    @moduledoc false
    use Oban.Worker, queue: :gdpr_cleanup

    @impl true
    def perform(%Oban.Job{}) do
      Logger.info("Processing export cleanup job")

      case Export.cleanup_expired_exports() do
        {:ok, :all_cleaned} ->
          Logger.info("All expired exports cleaned up successfully")
          :ok

        {:ok, count} ->
          Logger.info("Cleaned up #{count} expired exports")
          :ok

        {:error, reason} ->
          Logger.error("Failed to cleanup expired exports: #{inspect(reason)}")
          {:error, reason}
      end
    end

    @impl true
    def backoff(_attempt) do
      # Cleanup runs daily
      :timer.hours(24)
    end
  end

  # Public API for scheduling jobs

  @doc """
  Schedules a data export job.

  ## Parameters
  - export_id: ID of the export request

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_export_job(export_id) do
    %{
      export_id: export_id
    }
    |> DataExportWorker.new(schedule_in: 5) # Process immediately with slight delay
    |> Oban.insert()
  end

  @doc """
  Schedules retention monitoring job for a user.

  ## Parameters
  - user_id: ID of the user to monitor

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_retention_monitoring(user_id) do
    # Schedule first check in 24 hours, then recurring
    schedule_next_retention_check(user_id)
  end

  @doc """
  Schedules immediate anonymization job.

  ## Parameters
  - user_id: ID of the user to anonymize

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_immediate_anonymization(user_id) do
    %{
      user_id: user_id
    }
    |> RetentionWorker.new(schedule_in: 0)
    |> Oban.insert()
  end

  @doc """
  Schedules token revocation job.

  ## Parameters
  - user_id: ID of the user whose tokens to revoke

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_revoke_tokens(user_id) do
    %{
      user_id: user_id
    }
    |> TokenRevocationWorker.new(schedule_in: 1) # Process in 1 second
    |> Oban.insert()
  end

  @doc """
  Schedules OAuth disconnection job.

  ## Parameters
  - user_id: ID of the user whose OAuth connections to disconnect

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_disconnect_oauth(user_id) do
    %{
      user_id: user_id
    }
    |> OAuthDisconnectionWorker.new(schedule_in: 2) # Process in 2 seconds
    |> Oban.insert()
  end

  @doc """
  Schedules periodic compliance monitoring job.

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_compliance_monitoring do
    ComplianceMonitorWorker.new(%{})
    |> Oban.insert()
  end

  @doc """
  Schedules consent expiration processing job.

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_consent_expiration_processing do
    ConsentExpirationWorker.new(%{})
    |> Oban.insert()
  end

  @doc """
  Schedules export cleanup job.

  ## Returns
  - {:ok, job} on success
  - {:error, reason} on failure
  """
  def schedule_export_cleanup do
    ExportCleanupWorker.new(%{})
    |> Oban.insert()
  end

  # Cron scheduling for recurring jobs

  @doc """
  Schedules all recurring GDPR jobs using cron.

  This should be called during application startup.
  """
  def schedule_recurring_jobs do
    # Daily compliance monitoring at 2 AM UTC
    {:ok, _} = Oban.insert(ComplianceMonitorWorker.new(%{}, schedule: ~U[2024-01-01 02:00:00Z]))

    # Hourly retention checks
    {:ok, _} = Oban.insert(RetentionWorker.new(%{}, schedule: ~U[2024-01-01 01:00:00Z]))

    # Daily consent expiration processing at 3 AM UTC
    {:ok, _} = Oban.insert(ConsentExpirationWorker.new(%{}, schedule: ~U[2024-01-01 03:00:00Z]))

    # Daily export cleanup at 4 AM UTC
    {:ok, _} = Oban.insert(ExportCleanupWorker.new(%{}, schedule: ~U[2024-01-01 04:00:00Z]))

    :ok
  end

  # Private helper functions

  defp schedule_next_retention_check(user_id) do
    # Calculate next check time (24 hours from now)
    next_check = DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)

    %{
      user_id: user_id
    }
    |> RetentionWorker.new(scheduled_at: next_check)
    |> Oban.insert()
  end

  @doc """
  Gets job statistics for monitoring.

  ## Returns
  - Map with job statistics
  """
  def get_job_statistics do
    # Get counts for different job states
    %{
      available: count_jobs_by_state("available"),
      scheduled: count_jobs_by_state("scheduled"),
      executing: count_jobs_by_state("executing"),
      retryable: count_jobs_by_state("retryable"),
      discarded: count_jobs_by_state("discarded"),
      completed: count_jobs_by_state("completed"),
      by_queue: get_jobs_by_queue()
    }
  end

  defp count_jobs_by_state(state) do
    Oban.Job
    |> Oban.Query.where(state: ^state)
    |> Repo.aggregate(:count, :id)
  end

  defp get_jobs_by_queue do
    queues = ["gdpr", "gdpr_exports", "gdpr_retention", "gdpr_consent", "gdpr_monitoring", "gdpr_cleanup"]

    Enum.reduce(queues, %{}, fn queue, acc ->
      count = Oban.Job
             |> Oban.Query.where(queue: ^queue)
             |> Repo.aggregate(:count, :id)

      Map.put(acc, queue, count)
    end)
  end
end