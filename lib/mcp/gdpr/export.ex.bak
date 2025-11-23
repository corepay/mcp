defmodule Mcp.Gdpr.Export do
  @moduledoc """
  GDPR data export functionality for Data Subject Access Requests (DSAR).

  This module handles:
  - Creating export requests
  - Generating data exports in multiple formats
  - Managing export file lifecycle
  - Secure token-based access to exports
  """

  require Logger

  alias Mcp.Repo
  alias Ecto.{UUID, Multi}

  # Export schemas (these would need to be created)
  defmodule ExportRequest do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id
    schema "gdpr_data_export_requests" do
      field :user_id, :binary_id
      field :export_token, :binary_id
      field :requested_format, :string
      field :data_categories, {:array, :string}
      field :status, :string, default: "requested"
      field :requested_at, :utc_datetime
      field :processing_started_at, :utc_datetime
      field :completed_at, :utc_datetime
      field :expires_at, :utc_datetime
      field :file_path, :string
      field :file_size_bytes, :integer
      field :download_count, :integer, default: 0
      field :max_downloads, :integer, default: 5
      field :last_downloaded_at, :utc_datetime
      field :ip_address, :string
      field :user_agent, :string
      field :request_id, :string
      field :error_details, :map
      field :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end

    def changeset(export, attrs) do
      export
      |> cast(attrs, [
        :user_id, :export_token, :requested_format, :data_categories, :status,
        :requested_at, :processing_started_at, :completed_at, :expires_at,
        :file_path, :file_size_bytes, :download_count, :max_downloads,
        :last_downloaded_at, :ip_address, :user_agent, :request_id,
        :error_details, :oban_job_id
      ])
      |> validate_required([:user_id, :export_token, :requested_format])
      |> validate_inclusion(:requested_format, ["json", "csv", "pdf"])
      |> validate_inclusion(:status, ["requested", "processing", "completed", "expired", "failed"])
      |> validate_number(:download_count, less_than: :max_downloads)
      |> unique_constraint(:export_token)
      |> unique_constraint(:oban_job_id)
    end
  end

  @doc """
  Creates a new data export request.

  ## Parameters
  - user_id: UUID of the user requesting data export
  - format: Export format ("json", "csv", "pdf")
  - categories: List of data categories to include (nil for all)
  - opts: Additional options

  ## Returns
  - {:ok, export_request} on success
  - {:error, reason} on failure
  """
  def create_export_request(user_id, format \\ "json", categories \\ nil, opts \\ []) do
    export_token = UUID.generate()
    expires_at = calculate_expires_at()

    attrs = %{
      user_id: user_id,
      export_token: export_token,
      requested_format: format,
      data_categories: categories || get_all_categories(),
      status: "requested",
      requested_at: DateTime.utc_now(),
      expires_at: expires_at,
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      request_id: Keyword.get(opts, :request_id)
    }

    %ExportRequest{}
    |> ExportRequest.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, export} ->
        Logger.info("Created export request #{export.id} for user #{user_id}")
        {:ok, export}

      {:error, changeset} ->
        Logger.error("Failed to create export request: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Retrieves an export request by token.

  ## Parameters
  - token: The export token

  ## Returns
  - {:ok, export_request} if found and valid
  - {:error, :not_found} if not found
  - {:error, :expired} if expired
  - {:error, :max_downloads} if download limit exceeded
  """
  def get_export_by_token(token) do
    case Repo.get_by(ExportRequest, export_token: token) do
      nil ->
        {:error, :not_found}

      export ->
        cond do
          export.status != "completed" ->
            {:error, :not_ready}

          DateTime.compare(export.expires_at, DateTime.utc_now()) == :lt ->
            {:error, :expired}

          export.download_count >= export.max_downloads ->
            {:error, :max_downloads}

          true ->
            {:ok, export}
        end
    end
  end

  @doc """
  Downloads an export file and updates download tracking.

  ## Parameters
  - token: The export token

  ## Returns
  - {:ok, file_path, filename, content_type} on success
  - {:error, reason} on failure
  """
  def download_export(token) do
    with {:ok, export} <- get_export_by_token(token),
         :ok <- ensure_file_exists(export.file_path) do

      # Update download tracking
      update_download_count(export)

      filename = generate_filename(export)
      content_type = get_content_type(export.requested_format)

      {:ok, export.file_path, filename, content_type}
    else
      error -> error
    end
  end

  @doc """
  Generates the actual data export file for a request.

  ## Parameters
  - export_id: ID of the export request

  ## Returns
  - {:ok, export_request} with file_path set
  - {:error, reason} on failure
  """
  def generate_export_file(export_id) do
    Multi.new()
    |> Multi.run(:export, fn _repo, _changes -> get_export_request(export_id) end)
    |> Multi.run(:data, fn _repo, changes -> collect_user_data(changes.export) end)
    |> Multi.run(:file, fn _repo, changes -> create_export_file(changes.export, changes.data) end)
    |> Multi.run(:update, fn _repo, changes ->
      update_export_with_file(changes.export, changes.file)
    end)
    |> Repo.transaction()
    |> handle_export_generation_result()
  end

  @doc """
  Collects all user data for export.

  ## Parameters
  - export_request: The export request struct
  - opts: Additional options

  ## Returns
  - {:ok, data_map} containing all user data
  - {:error, reason} on failure
  """
  def collect_user_data(export_request, opts \\ []) do
    user_id = export_request.user_id
    categories = export_request.data_categories

    data = %{
      user_identity: get_user_identity_data(user_id),
      authentication_data: get_authentication_data(user_id),
      activity_logs: get_activity_logs(user_id, opts),
      communication_history: get_communication_history(user_id, opts),
      user_preferences: get_user_preferences(user_id, opts),
      consent_records: get_consent_records(user_id, opts),
      audit_trail: get_audit_trail_data(user_id, opts)
    }
    |> filter_by_categories(categories)

    {:ok, data}
  end

  @doc """
  Expires old export requests and cleans up files.

  ## Returns
  - {:ok, count} of expired requests cleaned up
  """
  def cleanup_expired_exports do
    expired_threshold = DateTime.add(DateTime.utc_now(), -1, :day)

    from(e in ExportRequest,
      where: e.status == "completed" and e.expires_at < ^expired_threshold
    )
    |> Repo.all()
    |> Enum.map(&cleanup_export_request/1)
    |> Enum.filter(&match?({:error, _}, &1))
    |> case do
      [] -> {:ok, :all_cleaned}
      errors -> {:error, errors}
    end
  end

  # Private helper functions

  defp get_all_categories do
    [
      "user_identity",
      "authentication_data",
      "activity_logs",
      "communication_history",
      "user_preferences",
      "consent_records",
      "audit_trail"
    ]
  end

  defp calculate_expires_at do
    DateTime.add(DateTime.utc_now(), 48, :hour) # 48 hours from now
  end

  defp get_export_request(export_id) do
    case Repo.get(ExportRequest, export_id) do
      nil -> {:error, :not_found}
      export -> {:ok, export}
    end
  end

  defp get_user_identity_data(user_id) do
    # Implementation would fetch user identity data
    %{
      id: user_id,
      email: "user@example.com", # This would come from actual user data
      first_name: "John",
      last_name: "Doe",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp get_authentication_data(user_id) do
    # Implementation would fetch authentication data (excluding sensitive secrets)
    %{
      user_id: user_id,
      has_2fa: false,
      oauth_providers: [],
      last_sign_in_at: DateTime.utc_now(),
      sign_in_count: 0
    }
  end

  defp get_activity_logs(user_id, _opts) do
    # Implementation would fetch user activity logs
    []
  end

  defp get_communication_history(user_id, _opts) do
    # Implementation would fetch communication history
    []
  end

  defp get_user_preferences(user_id, _opts) do
    # Implementation would fetch user preferences
    %{}
  end

  defp get_consent_records(user_id, _opts) do
    # Implementation would fetch consent records
    []
  end

  defp get_audit_trail_data(user_id, _opts) do
    # Implementation would fetch audit trail data
    []
  end

  defp filter_by_categories(data, categories) do
    if categories do
      Map.take(data, categories)
    else
      data
    end
  end

  defp create_export_file(export_request, data) do
    format = export_request.requested_format
    user_id = export_request.user_id

    case format do
      "json" -> create_json_export(data, user_id)
      "csv" -> create_csv_export(data, user_id)
      "pdf" -> create_pdf_export(data, user_id)
      _ -> {:error, :unsupported_format}
    end
  end

  defp create_json_export(data, user_id) do
    filename = "user_data_export_#{user_id}_#{DateTime.utc_now()}.json"
    file_path = Path.join([System.tmp_dir!(), "gdpr_exports", filename])

    # Ensure directory exists
    File.mkdir_p!(Path.dirname(file_path))

    case Jason.encode(data, pretty: true) do
      {:ok, json_content} ->
        case File.write(file_path, json_content) do
          :ok ->
            file_size = byte_size(json_content)
            {:ok, %{file_path: file_path, file_size: file_size}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_csv_export(_data, _user_id) do
    # CSV export implementation
    {:error, :not_implemented}
  end

  defp create_pdf_export(_data, _user_id) do
    # PDF export implementation
    {:error, :not_implemented}
  end

  defp update_export_with_file(export, file_data) do
    attrs = %{
      status: "completed",
      file_path: file_data.file_path,
      file_size_bytes: file_data.file_size,
      completed_at: DateTime.utc_now()
    }

    export
    |> ExportRequest.changeset(attrs)
    |> Repo.update()
  end

  defp update_download_count(export) do
    attrs = %{
      download_count: export.download_count + 1,
      last_downloaded_at: DateTime.utc_now()
    }

    export
    |> ExportRequest.changeset(attrs)
    |> Repo.update()
  end

  defp generate_filename(export) do
    timestamp = DateTime.to_string(export.requested_at) |> String.replace([" ", ":"], "-")
    "user_data_export_#{export.user_id}_#{timestamp}.#{export.requested_format}"
  end

  defp get_content_type("json"), do: "application/json"
  defp get_content_type("csv"), do: "text/csv"
  defp get_content_type("pdf"), do: "application/pdf"

  defp ensure_file_exists(file_path) do
    if File.exists?(file_path) do
      :ok
    else
      {:error, :file_not_found}
    end
  end

  defp cleanup_export_request(export) do
    # Delete the file
    if export.file_path && File.exists?(export.file_path) do
      File.rm(export.file_path)
    end

    # Mark as expired
    export
    |> ExportRequest.changeset(%{status: "expired"})
    |> Repo.update()
  end

  defp handle_export_generation_result({:ok, result}) do
    Logger.info("Successfully generated export file for request #{result.export.id}")
    {:ok, result.update}
  end

  defp handle_export_generation_result({:error, failed_op, reason, _changes}) do
    Logger.error("Failed to generate export at #{failed_op}: #{inspect(reason)}")
    {:error, reason}
  end
end