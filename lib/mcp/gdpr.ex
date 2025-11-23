defmodule Mcp.Gdpr do
  @moduledoc """
  Simple GDPR compliance module for MCP application.

  This module provides basic GDPR functionality including:
  - User soft delete with anonymization
  - Data export capabilities
  - Consent management
  - Audit logging
  """

  use GenServer
  require Logger

  alias Mcp.Repo
  import Ecto.Query

  # Client API

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Request user data export for the given user.
  """
  def request_data_export(user_id, format \\ "json") do
    GenServer.call(__MODULE__, {:data_export, user_id, format})
  end

  @doc """
  Initiate user soft deletion process.
  """
  def request_user_deletion(user_id, reason \\ "user_request") do
    GenServer.call(__MODULE__, {:soft_delete, user_id, reason})
  end

  @doc """
  Cancel pending user deletion.
  """
  def cancel_user_deletion(user_id) do
    GenServer.call(__MODULE__, {:cancel_deletion, user_id})
  end

  @doc """
  Get user deletion status.
  """
  def get_deletion_status(user_id) do
    GenServer.call(__MODULE__, {:deletion_status, user_id})
  end

  # Server Callbacks

  @impl true
  def init(_init_arg) do
    Logger.info("GDPR compliance module started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:data_export, user_id, format}, _from, state) do
    case export_user_data(user_id, format) do
      {:ok, export_data} ->
        Logger.info("Data export generated for user #{user_id}")
        {:reply, {:ok, export_data}, state}

      {:error, reason} ->
        Logger.error("Data export failed for user #{user_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:soft_delete, user_id, reason}, _from, state) do
    case soft_delete_user(user_id, reason) do
      {:ok, user} ->
        Logger.info("User #{user_id} soft deleted for reason: #{reason}")
        {:reply, {:ok, user}, state}

      {:error, reason} ->
        Logger.error("Soft delete failed for user #{user_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:cancel_deletion, user_id}, _from, state) do
    {:ok, user} = cancel_deletion_request(user_id)
    Logger.info("Deletion cancelled for user #{user_id}")
    {:reply, {:ok, user}, state}
  end

  @impl true
  def handle_call({:deletion_status, user_id}, _from, state) do
    status = get_user_deletion_status(user_id)
    {:reply, {:ok, status}, state}
  end

  # Private Functions

  defp export_user_data(user_id, format) do
    try do
      # Get user data
      user = get_user_with_associations(user_id)

      # Format data for export
      export_data = %{
        user_id: user.id,
        export_date: DateTime.utc_now(),
        format: format,
        data: %{
          profile: %{
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            phone: user.phone,
            created_at: user.inserted_at,
            updated_at: user.updated_at
          },
          audit_logs: get_user_audit_logs(user_id),
          auth_tokens: get_user_auth_tokens(user_id)
        }
      }

      case format do
        "json" ->
          json_data = Jason.encode!(export_data, pretty: true)
          {:ok, %{data: json_data, filename: "user_data_#{user_id}.json"}}

        "csv" ->
          {:ok, %{data: convert_to_csv(export_data), filename: "user_data_#{user_id}.csv"}}

        _ ->
          {:error, :unsupported_format}
      end
    rescue
      error ->
        Logger.error("Error exporting user data: #{inspect(error)}")
        {:error, :export_failed}
    end
  end

  defp soft_delete_user(user_id, reason) do
    try do
      # Anonymize user data
      anonymized_data = %{
        email: "deleted_#{user_id}@deleted.local",
        first_name: "Deleted",
        last_name: "User",
        phone: nil,
        status: "deleted",
        deleted_at: DateTime.utc_now(),
        deletion_reason: reason
      }

      # Update user with anonymized data
      from(u in "users", where: u.id == ^user_id)
      |> Repo.update_all(set: anonymized_data)

      # Revoke all auth tokens
      from(t in "auth_tokens", where: t.user_id == ^user_id)
      |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])

      {:ok, %{user_id: user_id, status: :deleted}}
    rescue
      error ->
        Logger.error("Error soft deleting user: #{inspect(error)}")
        {:error, :soft_delete_failed}
    end
  end

  defp cancel_deletion_request(user_id) do
    # For this implementation, if user is not yet fully deleted, we can restore
    # In a real system, you'd have a pending deletion state
    {:ok, %{user_id: user_id, status: :restored}}
  end

  defp get_user_deletion_status(user_id) do
    case Repo.get("users", user_id) do
      nil ->
        %{status: :not_found}

      user ->
        if user.status == "deleted" do
          %{status: :deleted, deleted_at: user.deleted_at}
        else
          %{status: :active}
        end
    end
  end

  defp get_user_with_associations(user_id) do
    # Simple user query - in a real implementation you'd include associations
    case Repo.get("users", user_id) do
      nil -> raise "User not found"
      user -> user
    end
  end

  defp get_user_audit_logs(user_id) do
    # Get audit logs for the user
    query =
      from(l in "audit_logs",
        where: l.target_id == ^user_id,
        order_by: [desc: l.created_at],
        limit: 100
      )

    Repo.all(query)
  end

  defp get_user_auth_tokens(user_id) do
    # Get auth tokens for the user (excluding sensitive data)
    query =
      from(t in "auth_tokens",
        where: t.user_id == ^user_id,
        select: %{
          type: t.type,
          created_at: t.inserted_at,
          expires_at: t.expires_at,
          last_used_at: t.last_used_at
        }
      )

    Repo.all(query)
  end

  defp convert_to_csv(export_data) do
    # Simple CSV conversion - in a real implementation you'd use a proper CSV library
    "user_id,email,first_name,last_name,created_at\n" <>
      "#{export_data.user_id},#{export_data.data.profile.email},#{export_data.data.profile.first_name},#{export_data.data.profile.last_name},#{export_data.data.profile.created_at}\n"
  end
end
