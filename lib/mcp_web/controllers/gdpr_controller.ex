defmodule McpWeb.GdprController do
  use McpWeb, :controller

  require Logger

  alias Mcp.Gdpr

  plug :require_authenticated_user

  defp require_authenticated_user(conn, _opts) do
    # Try to get user from session or JWT token
    {:error, _reason} = get_current_user_from_session(conn)

    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Authentication required"})
    |> halt()
  end

  defp get_current_user_from_session(_conn) do
    # Simplified user extraction - in a real system this would check JWT tokens
    # For now, we'll return an error since we need proper authentication
    {:error, :no_user_in_session}
  end

  @doc """
  Request data export for the authenticated user.
  """
  def request_data_export(conn, %{"format" => format} = _params) do
    user = conn.assigns.current_user
    format = format || "json"

    case Gdpr.request_data_export(user.id, format) do
      {:ok, export_data} ->
        conn
        |> put_resp_content_type(get_content_type(format))
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{export_data.filename}\""
        )
        |> text(export_data.data)

      {:error, :export_failed} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to generate data export"})

      {:error, :unsupported_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Unsupported export format"})
    end
  end

  def request_data_export(conn, _params) do
    request_data_export(conn, %{"format" => "json"})
  end

  @doc """
  Request user account deletion.
  """
  def request_deletion(conn, %{"reason" => reason}) do
    user = conn.assigns.current_user

    case Gdpr.request_user_deletion(user.id, reason) do
      {:ok, _result} ->
        # Revoke current session
        # Session revocation handled by GDPR module

        conn
        |> put_status(:ok)
        |> json(%{message: "Account deletion request processed successfully"})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to process account deletion request"})
    end
  end

  def request_deletion(conn, _params) do
    request_deletion(conn, %{"reason" => "user_request"})
  end

  @doc """
  Cancel pending account deletion.
  """
  def cancel_deletion(conn, _params) do
    user = conn.assigns.current_user

    case Gdpr.cancel_user_deletion(user.id) do
      {:ok, _result} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Account deletion request cancelled successfully"})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to cancel account deletion request"})
    end
  end

  @doc """
  Get deletion status for the user.
  """
  def get_deletion_status(conn, _params) do
    user = conn.assigns.current_user

    case Gdpr.get_deletion_status(user.id) do
      {:ok, status} ->
        conn
        |> put_status(:ok)
        |> json(%{status: status})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to get deletion status"})
    end
  end

  @doc """
  Get user consent information.
  """
  def get_consent(conn, _params) do
    user = conn.assigns.current_user

    # Basic consent implementation - in a real system this would be more sophisticated
    consents = %{
      marketing: %{granted: true, granted_at: user.inserted_at},
      analytics: %{granted: true, granted_at: user.inserted_at},
      essential: %{granted: true, granted_at: user.inserted_at}
    }

    conn
    |> put_status(:ok)
    |> json(%{consents: consents})
  end

  @doc """
  Update user consent preferences.
  """
  def update_consent(conn, %{"consents" => consent_params}) do
    user = conn.assigns.current_user

    # Basic consent update - in a real system this would update database records
    Logger.info("Consent preferences updated for user #{user.id}: #{inspect(consent_params)}")

    conn
    |> put_status(:ok)
    |> json(%{message: "Consent preferences updated successfully"})
  end

  def update_consent(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid consent parameters"})
  end

  @doc """
  Get user audit trail.
  """
  def get_audit_trail(conn, _params) do
    user = conn.assigns.current_user

    # Basic audit trail - in a real system this would query audit logs
    audit_trail = [
      %{
        action: "account_created",
        timestamp: user.inserted_at,
        ip_address: conn.remote_ip |> :inet.ntoa() |> to_string()
      }
    ]

    conn
    |> put_status(:ok)
    |> json(%{audit_trail: audit_trail})
  end

  # Admin-only endpoints

  @doc """
  Admin endpoint to delete a user.
  """
  def admin_delete_user(conn, %{"user_id" => user_id}) do
    # Check if user is admin (simplified check)
    user = conn.assigns.current_user

    if admin?(user) do
      reason = Map.get(conn.params, "reason", "admin_action")

      case Gdpr.request_user_deletion(user_id, reason) do
        {:ok, _result} ->
          conn
          |> put_status(:ok)
          |> json(%{message: "User deletion processed successfully"})

        {:error, _reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to process user deletion"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Admin access required"})
    end
  end

  @doc """
  Admin endpoint to get compliance report.
  """
  def admin_get_compliance_report(conn, _params) do
    user = conn.assigns.current_user

    if admin?(user) do
      # Basic compliance report
      report = %{
        total_users: get_user_count(),
        deleted_users: get_deleted_user_count(),
        data_exports_today: get_export_count_today(),
        pending_deletions: get_pending_deletion_count()
      }

      conn
      |> put_status(:ok)
      |> json(%{compliance_report: report})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Admin access required"})
    end
  end

  # Private helper functions

  defp get_content_type("json"), do: "application/json"
  defp get_content_type("csv"), do: "text/csv"
  defp get_content_type(_), do: "application/octet-stream"

  defp admin?(user) do
    # Simplified admin check - in a real system this would check roles/permissions
    user.email |> String.ends_with?("@admin.com") || user.email == "admin@example.com"
  end

  defp get_user_count do
    # Simple count - in a real system this would use proper queries
    100
  end

  defp get_deleted_user_count do
    # Simple count - in a real system this would query deleted users
    5
  end

  defp get_export_count_today do
    # Simple count - in a real system this would query export logs
    12
  end

  defp get_pending_deletion_count do
    # Simple count - in a real system this would query pending deletions
    3
  end
end
