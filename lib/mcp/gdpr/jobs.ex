defmodule Mcp.Gdpr.Jobs do
  @moduledoc """
  GDPR background job processing module.

  This module provides functions to enqueue and manage GDPR-related background jobs:
  - Data export processing
  - User data anonymization
  - Data retention cleanup
  - Compliance monitoring and reporting
  """

  use GenServer

  alias Mcp.Gdpr.AuditTrail
  alias Mcp.Gdpr.Schemas.GdprExport
  alias Mcp.Gdpr.Schemas.GdprRequest
  alias Mcp.Jobs.Gdpr.AnonymizationWorker
  alias Mcp.Jobs.Gdpr.ComplianceWorker
  alias Mcp.Jobs.Gdpr.DataExportWorker
  alias Mcp.Jobs.Gdpr.RetentionCleanupWorker
  alias Mcp.Repo
  import Ecto.Query

  @doc """
  Starts the GDPR jobs GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  # Data Export Jobs

  @doc """
  Enqueue a data export job for the specified user.
  """
  def enqueue_data_export(user_id, format, actor_id \\ nil) do
    # Create GDPR request first
    request_attrs = %{
      user_id: user_id,
      type: "export",
      status: "pending",
      actor_id: actor_id,
      data: %{format: format},
      expires_at: DateTime.add(DateTime.utc_now(), 7, :day)
    }

    request_changeset = GdprRequest.changeset(%GdprRequest{}, request_attrs)

    case Repo.insert(request_changeset) do
      {:ok, request} ->
        # Create export record linked to request
        export_attrs = %{
          user_id: user_id,
          request_id: request.id,
          format: format,
          status: "pending",
          expires_at: DateTime.add(DateTime.utc_now(), 7, :day),
          metadata: %{requested_by: actor_id}
        }

        export_changeset = GdprExport.changeset(%GdprExport{}, export_attrs)

        case Repo.insert(export_changeset) do
          {:ok, export} ->
            # Enqueue the background job
            DataExportWorker.new(%{
              "export_id" => export.id
            })
            |> Oban.insert()

            {:ok, export}

          {:error, changeset} ->
            {:error, changeset.errors}
        end

      {:error, changeset} ->
        {:error, changeset.errors}
    end
  end

  @doc """
  Get the status of a data export request.
  """
  def get_export_status(export_id) do
    case Repo.get(GdprExport, export_id) do
      nil -> {:error, :not_found}
      export -> {:ok, export}
    end
  end

  # Anonymization Jobs

  @doc """
  Enqueue a user anonymization job.
  """
  def enqueue_user_anonymization(user_id, mode, actor_id \\ nil) do
    args =
      case mode do
        :full ->
          %{"user_id" => user_id, "mode" => "full"}

        {:partial, fields} when is_list(fields) ->
          %{"user_id" => user_id, "mode" => "partial", "fields" => fields}

        _ ->
          %{"user_id" => user_id, "mode" => "full"}
      end

    # Log the anonymization request for audit trail
    AuditTrail.log_action(
      user_id,
      "anonymization_requested",
      actor_id,
      %{mode: mode, scheduled_at: DateTime.utc_now()}
    )

    AnonymizationWorker.new(args)
    |> Oban.insert()
  end

  # Retention Cleanup Jobs

  @doc """
  Enqueue retention cleanup jobs.
  """
  def enqueue_retention_cleanup(type) do
    types = if is_list(type), do: type, else: [type]

    Enum.each(types, fn cleanup_type ->
      RetentionCleanupWorker.new(%{
        "type" => cleanup_type
      })
      |> Oban.insert()
    end)
  end

  # Compliance Jobs

  @doc """
  Enqueue compliance monitoring job.
  """
  def enqueue_compliance_check(type) do
    args =
      case type do
        :daily -> %{"type" => "daily_monitoring"}
        :weekly -> %{"type" => "weekly_report"}
        :retention -> %{"type" => "retention_enforcement"}
        :legal_hold -> %{"type" => "legal_hold_check"}
        _ -> %{"type" => "daily_monitoring"}
      end

    ComplianceWorker.new(args)
    |> Oban.insert()
  end

  # Utility Functions

  @doc """
  Get job statistics for monitoring.
  """
  def get_job_statistics do
    # Query Oban for job statistics
    stats = %{
      pending_jobs: get_pending_job_count(),
      failed_jobs: get_failed_job_count(),
      completed_jobs: get_completed_job_count(),
      queue_stats: get_queue_statistics()
    }

    {:ok, stats}
  end

  # Private helper functions

  @gdpr_queues ["gdpr_exports", "gdpr_cleanup", "gdpr_anonymize", "gdpr_compliance"]

  defp get_pending_job_count do
    from(j in Oban.Job,
      where: j.state in ["available", "retryable"],
      where: j.queue in ^@gdpr_queues
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_failed_job_count do
    from(j in Oban.Job,
      where: j.state == "discarded",
      where: j.queue in ^@gdpr_queues
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_completed_job_count do
    from(j in Oban.Job,
      where: j.state == "completed",
      where: j.queue in ^@gdpr_queues
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_queue_statistics do
    Enum.reduce(@gdpr_queues, %{}, fn queue, acc ->
      count =
        from(j in Oban.Job, where: j.queue == ^queue)
        |> Repo.aggregate(:count, :id)

      Map.put(acc, queue, count)
    end)
  end
end
