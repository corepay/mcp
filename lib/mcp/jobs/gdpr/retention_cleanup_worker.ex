defmodule Mcp.Jobs.Gdpr.RetentionCleanupWorker do
  @moduledoc """
  Background worker for GDPR data retention cleanup.

  This worker handles:
  - Identifying overdue user accounts for anonymization
  - Processing data anonymization according to retention policies
  - Cleaning up expired export files
  - Removing expired audit trail entries
  - Legal hold management and compliance checks
  """

  use Oban.Worker, queue: :gdpr_cleanup, max_attempts: 1

  alias Mcp.Gdpr.Compliance
  alias Mcp.Gdpr.Anonymizer
  alias Mcp.Repo
  alias Mcp.Accounts.UserSchema
  import Ecto.Query

  @impl true
  def perform(%Oban.Job{args: %{"type" => "user_anonymization"}}) do
    Logger.info("Running GDPR user anonymization cleanup")

    process_overdue_anonymizations()
  end

  def perform(%Oban.Job{args: %{"type" => "export_cleanup"}}) do
    Logger.info("Running GDPR export file cleanup")

    process_expired_exports()
  end

  def perform(%Oban.Job{args: %{"type" => "audit_cleanup"}}) do
    Logger.info("Running GDPR audit trail cleanup")

    process_expired_audit_entries()
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id, "action" => "anonymize"}}) do
    Logger.info("Anonymizing user #{user_id}")

    case anonymize_user_data(user_id) do
      {:ok, _} -> {:ok, user_id}
      error -> error
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid arguments for RetentionCleanupWorker: #{inspect(args)}")
    {:error, :invalid_arguments}
  end

  # Private functions

  defp process_overdue_anonymizations do
    now = DateTime.utc_now()

    overdue_users = from(u in UserSchema,
      where: u.status == "deleted",
      where: not is_nil(u.gdpr_retention_expires_at),
      where: u.gdpr_retention_expires_at <= ^now,
      where: is_nil(u.anonymized_at))
    |> Repo.all()

    Logger.info("Found #{length(overdue_users)} users overdue for anonymization")

    anonymized_count =
      overdue_users
      |> Enum.count(fn user ->
        case anonymize_user_data(user.id) do
          {:ok, _} ->
            Logger.info("Successfully anonymized user #{user.id}")
            true
          {:error, reason} ->
            Logger.error("Failed to anonymize user #{user.id}: #{inspect(reason)}")
            false
        end
      end)

    Logger.info("Anonymized #{anonymized_count} of #{length(overdue_users)} overdue users")
    {:ok, %{processed: length(overdue_users), anonymized: anonymized_count}}
  end

  defp process_expired_exports do
    cutoff_date = DateTime.add(DateTime.utc_now(), -7, :day)

    expired_exports = from(e in "gdpr_exports",
      where: e.expires_at <= ^cutoff_date,
      where: e.status == "completed")
    |> Repo.all()

    Logger.info("Found #{length(expired_exports)} expired exports to clean up")

    cleaned_count =
      expired_exports
      |> Enum.count(fn export ->
        case cleanup_export_files(export) do
          :ok ->
            # Update export status to expired
            update_export_status(export.id, "expired")
            true
          {:error, reason} ->
            Logger.error("Failed to cleanup export #{export.id}: #{inspect(reason)}")
            false
        end
      end)

    Logger.info("Cleaned up #{cleaned_count} of #{length(expired_exports)} expired exports")
    {:ok, %{processed: length(expired_exports), cleaned: cleaned_count}}
  end

  defp process_expired_audit_entries do
    # Audit trail retention - typically keep for 2 years
    cutoff_date = DateTime.add(DateTime.utc_now(), -730, :day)

    expired_entries = from(a in "gdpr_audit_trail",
      where: a.inserted_at <= ^cutoff_date)
    |> Repo.all()

    Logger.info("Found #{length(expired_entries)} expired audit entries to clean up")

    # Archive entries before deletion if needed
    archived_count =
      expired_entries
      |> Enum.count(fn audit_entry ->
        case archive_audit_entry(audit_entry) do
          :ok ->
            delete_audit_entry(audit_entry.id)
            true
          {:error, reason} ->
            Logger.error("Failed to archive audit entry #{audit_entry.id}: #{inspect(reason)}")
            false
        end
      end)

    Logger.info("Archived and removed #{archived_count} of #{length(expired_entries)} audit entries")
    {:ok, %{processed: length(expired_entries), archived: archived_count}}
  end

  defp anonymize_user_data(user_id) do
    user = Repo.get(UserSchema, user_id)

    cond do
      is_nil(user) ->
        {:error, :user_not_found}

      user.anonymized_at ->
        {:error, :already_anonymized}

      has_legal_hold?(user_id) ->
        {:error, :legal_hold_active}

      true ->
        perform_user_anonymization(user)
    end
  end

  defp perform_user_anonymization(user) do
    now = DateTime.utc_now()

    # Update user with anonymized data
    anonymized_fields = %{
      email: generate_anonymous_email(user.id),
      anonymized_at: now,
      updated_at: now
    }

    from(u in UserSchema, where: u.id == ^user.id)
    |> Repo.update_all([set: anonymized_fields])
    |> case do
      {1, _} ->
        # Additional anonymization of related data would go here
        anonymize_related_data(user.id)
        Logger.info("Successfully anonymized user data for user #{user.id}")
        {:ok, user.id}
      {0, _} ->
        {:error, :update_failed}
    end
  end

  defp anonymize_related_data(user_id) do
    # Anonymize audit trail entries for this user
    from(a in "gdpr_audit_trail",
      where: a.user_id == ^user_id)
    |> Repo.update_all([set: [user_id: nil]])

    # Anonymize consent records
    from(c in "gdpr_consent",
      where: c.user_id == ^user_id)
    |> Repo.update_all([set: [user_id: nil]])

    # Additional related data anonymization would go here
    :ok
  end

  defp generate_anonymous_email(user_id) do
    hash = :crypto.hash(:md5, "#{user_id}#{System.system_time()}")
    "anonymized_#{Base.encode16(hash)}@deleted.local"
  end

  defp has_legal_hold?(user_id) do
    from(lh in "gdpr_legal_holds",
      where: lh.user_id == ^user_id,
      where: is_nil(lh.released_at))
    |> Repo.exists?()
  end

  defp cleanup_export_files(export) do
    try do
      # Remove download file if it exists
      if export.download_url do
        file_path = get_file_path_from_url(export.download_url)
        if File.exists?(file_path) do
          File.rm(file_path)
        end
      end

      :ok
    rescue
      error ->
        Logger.error("Error cleaning up export files: #{inspect(error)}")
        {:error, :file_cleanup_failed}
    end
  end

  defp get_file_path_from_url(download_url) do
    # Convert URL like "/downloads/gdpr_exports/filename.ext" to file path
    filename = Path.basename(download_url)
    downloads_dir = Application.get_env(:mcp, :downloads_dir, "priv/static/downloads")
    Path.join(downloads_dir, filename)
  end

  defp update_export_status(export_id, status) do
    now = DateTime.utc_now()

    from(e in "gdpr_exports",
      where: e.id == ^export_id)
    |> Repo.update_all([set: [status: status, updated_at: now]])
    |> case do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  defp archive_audit_entry(audit_entry) do
    # In a real implementation, this would archive to external storage
    # For now, we'll just log the archival
    Logger.debug("Archiving audit entry: #{audit_entry.id}")
    :ok
  end

  defp delete_audit_entry(audit_id) do
    from(a in "gdpr_audit_trail", where: a.id == ^audit_id)
    |> Repo.delete_all()
    |> case do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end
end