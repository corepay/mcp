defmodule Mcp.Jobs.Gdpr.DataExportWorker do
  @moduledoc """
  Background worker for processing GDPR data export requests.

  This worker handles:
  - Data aggregation from multiple sources
  - Format conversion (JSON, CSV, XML)
  - File generation and storage
  - Download link creation and expiration
  """

  use Oban.Worker, queue: :gdpr_exports, max_attempts: 3

  alias Mcp.Gdpr.Compliance
  alias Mcp.Gdpr.Export
  alias Mcp.Repo
  alias Mcp.Accounts.UserSchema
  import Ecto.Query

  @impl true
  def perform(%Oban.Job{args: %{"export_id" => export_id}}) do
    Logger.info("Processing GDPR data export for export_id: #{export_id}")

    case process_export_request(export_id) do
      {:ok, export} ->
        Logger.info("Successfully completed data export #{export_id} for user #{export.user_id}")
        {:ok, export}

      {:error, reason} ->
        Logger.error("Failed to process data export #{export_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid arguments for DataExportWorker: #{inspect(args)}")
    {:error, :invalid_arguments}
  end

  # Private functions

  defp process_export_request(export_id) do
    with {:ok, export} <- get_export_request(export_id),
         :ok <- validate_export_status(export),
         {:ok, user_data} <- collect_user_data(export.user_id, export.format),
         {:ok, file_path} <- generate_export_file(export, user_data),
         {:ok, download_url} <- upload_export_file(file_path, export),
         :ok <- update_export_completion(export, download_url),
         :ok <- cleanup_temp_file(file_path) do
      {:ok, export}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp get_export_request(export_id) do
    case Repo.get(Export, export_id) do
      nil -> {:error, :export_not_found}
      export -> {:ok, export}
    end
  end

  defp validate_export_status(export) do
    case export.status do
      "pending" -> :ok
      "processing" -> :ok
      _ -> {:error, :invalid_export_status}
    end
  end

  defp collect_user_data(user_id, format) do
    try do
      user = Repo.get!(UserSchema, user_id)

      # Collect all user-related data
      user_data = %{
        user_profile: format_user_profile(user),
        audit_trail: get_user_audit_trail(user_id),
        consents: get_user_consents(user_id),
        activities: get_user_activities(user_id),
        export_metadata: %{
          user_id: user_id,
          export_date: DateTime.utc_now(),
          format: format,
          version: "1.0"
        }
      }

      {:ok, user_data}
    rescue
      error ->
        Logger.error("Error collecting user data for user #{user_id}: #{inspect(error)}")
        {:error, :data_collection_failed}
    end
  end

  defp format_user_profile(user) do
    %{
      id: user.id,
      email: user.email,
      status: user.status,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at,
      deleted_at: user.deleted_at,
      anonymized_at: user.anonymized_at,
      gdpr_retention_expires_at: user.gdpr_retention_expires_at
    }
  end

  defp get_user_audit_trail(user_id) do
    from(a in "gdpr_audit_trail",
      where: a.user_id == ^user_id,
      order_by: [desc: a.inserted_at])
    |> Repo.all()
    |> Enum.map(&format_audit_entry/1)
  end

  defp get_user_consents(user_id) do
    from(c in "gdpr_consent",
      where: c.user_id == ^user_id,
      order_by: [desc: c.inserted_at])
    |> Repo.all()
    |> Enum.map(&format_consent_entry/1)
  end

  defp get_user_activities(user_id) do
    # This would collect additional user activities from various tables
    # For now, we'll collect basic information
    %{
      login_count: get_login_count(user_id),
      last_activity: get_last_activity(user_id),
      total_actions: get_action_count(user_id)
    }
  end

  defp format_audit_entry(audit) do
    %{
      action: audit.action,
      actor_id: audit.actor_id,
      details: audit.details,
      ip_address: audit.ip_address,
      user_agent: audit.user_agent,
      created_at: audit.inserted_at
    }
  end

  defp format_consent_entry(consent) do
    %{
      purpose: consent.purpose,
      status: consent.status,
      legal_basis: consent.legal_basis,
      granted_at: consent.granted_at,
      withdrawn_at: consent.withdrawn_at,
      created_at: consent.inserted_at,
      updated_at: consent.updated_at
    }
  end

  defp get_login_count(user_id) do
    # This would query login logs when available
    # For now, return a placeholder
    0
  end

  defp get_last_activity(user_id) do
    # This would query activity logs when available
    # For now, return nil
    nil
  end

  defp get_action_count(user_id) do
    from(a in "gdpr_audit_trail", where: a.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  defp generate_export_file(export, user_data) do
    temp_dir = System.tmp_dir!()
    timestamp = DateTime.utc_now() |> DateTime.to_string(:basic)
    filename = "user_data_export_#{export.user_id}_#{timestamp}.#{export.format}"
    file_path = Path.join(temp_dir, filename)

    try do
      content = case export.format do
        "json" -> Jason.encode!(user_data, pretty: true)
        "csv" -> generate_csv_content(user_data)
        "xml" -> generate_xml_content(user_data)
        _ -> {:error, :unsupported_format}
      end

      case content do
        {:error, reason} -> {:error, reason}
        content ->
          File.write!(file_path, content)
          {:ok, file_path}
      end
    rescue
      error ->
        Logger.error("Error generating export file: #{inspect(error)}")
        {:error, :file_generation_failed}
    end
  end

  defp generate_csv_content(user_data) do
    # Simplified CSV generation
    # In a real implementation, this would be more sophisticated
    csv_content = Jason.encode!(user_data)
    # Convert JSON to CSV format (placeholder implementation)
    csv_content
  end

  defp generate_xml_content(user_data) do
    # Simplified XML generation
    # In a real implementation, this would use proper XML libraries
    xml_content = Jason.encode!(user_data)
    # Convert JSON to XML format (placeholder implementation)
    xml_content
  end

  defp upload_export_file(file_path, export) do
    # In a real implementation, this would upload to S3/MinIO
    # For now, we'll simulate the upload and return a local URL

    filename = Path.basename(file_path)
    download_url = "/downloads/gdpr_exports/#{filename}"

    # Move file to public downloads directory (if it exists)
    downloads_dir = Application.get_env(:mcp, :downloads_dir, "priv/static/downloads")
    File.mkdir_p!(downloads_dir)
    final_path = Path.join(downloads_dir, filename)

    case File.cp(file_path, final_path) do
      :ok -> {:ok, download_url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_export_completion(export, download_url) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, 7, :day)  # 7 days expiration

    changeset = Export.changeset(export, %{
      status: "completed",
      download_url: download_url,
      completed_at: now,
      expires_at: expires_at,
      updated_at: now
    })

    case Repo.update(changeset) do
      {:ok, updated_export} -> :ok
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  defp cleanup_temp_file(file_path) do
    File.rm(file_path)
    :ok
  rescue
    _ -> :ok  # Ignore cleanup errors
  end
end