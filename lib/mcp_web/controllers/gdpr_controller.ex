defmodule McpWeb.GdprController do
  use McpWeb, :controller

  require Logger

  alias Mcp.Gdpr.Compliance
  alias Mcp.Gdpr.AuditTrail
  alias Mcp.Accounts.UserSchema
  alias Mcp.Repo
  alias McpWeb.Auth.GdprAuthPlug
  alias McpWeb.InputValidation

  @doc """
  Request data export for the authenticated user.
  """
  def request_data_export(conn, params) do
    user = conn.assigns.current_user
    request_id = conn.assigns[:gdpr_request_id]

    # Validate input parameters
    case InputValidation.validate_export_params(params) do
      {:ok, validated_params} ->
        format = validated_params.format

        # Log specific audit action for data export request
        GdprAuthPlug.log_audit_event(conn, "DATA_EXPORT_REQUESTED", %{
          user_id: user.id,
          format: format,
          request_id: request_id
        })

        case Compliance.request_user_data_export(user.id, format, user.id) do
          {:ok, export} ->
            # Log successful export request
            GdprAuthPlug.log_audit_event(conn, "DATA_EXPORT_REQUEST_ACCEPTED", %{
              user_id: user.id,
              export_id: export.id,
              format: format,
              request_id: request_id
            })

            conn
            |> put_status(:accepted)
            |> json(%{
              message: "Data export request accepted",
              export_id: export.id,
              status: export.status,
              estimated_completion: export.estimated_completion,
              request_id: request_id
            })

          {:error, :unsupported_format} ->
            # Log invalid format attempt
            GdprAuthPlug.log_audit_event(conn, "DATA_EXPORT_INVALID_FORMAT", %{
              user_id: user.id,
              format: format,
              request_id: request_id
            })

            conn
            |> put_status(:bad_request)
            |> json(%{
              error: "Unsupported export format. Supported formats: json, csv",
              request_id: request_id
            })

          {:error, reason} ->
            # Log export request failure
            GdprAuthPlug.log_audit_event(conn, "DATA_EXPORT_REQUEST_FAILED", %{
              user_id: user.id,
              format: format,
              reason: inspect(reason),
              request_id: request_id
            })

            Logger.error("Failed to request data export for user #{user.id}: #{inspect(reason)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{
              error: "Failed to process data export request",
              request_id: request_id
            })
        end

      {:error, validation_reason} ->
        # Log validation failure
        GdprAuthPlug.log_audit_event(conn, "DATA_EXPORT_VALIDATION_FAILED", %{
          user_id: user.id,
          validation_reason: validation_reason,
          request_id: request_id
        })

        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid input parameters",
          reason: format_validation_error(validation_reason),
          request_id: request_id
        })
    end
  end

  def request_data_export(conn, _params) do
    request_data_export(conn, %{"format" => "json"})
  end

  @doc """
  Get the status of a data export request.
  """
  def get_export_status(conn, %{"export_id" => export_id}) do
    user = conn.assigns.current_user

    case get_export_for_user(export_id, user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Export not found"})

      export ->
        conn
        |> put_status(:ok)
        |> json(%{
          export_id: export.id,
          status: export.status,
          created_at: export.inserted_at,
          completed_at: export.completed_at,
          download_url: export.download_url,
          expires_at: export.expires_at
        })
    end
  end

  @doc """
  Download a completed data export.
  """
  def download_export(conn, %{"export_id" => export_id}) do
    user = conn.assigns.current_user

    case get_export_for_user(export_id, user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Export not found"})

      %{status: "completed", download_url: download_url} = export ->
        # In a real implementation, this would serve the file from storage
        conn
        |> put_status(:ok)
        |> json(%{
          message: "Export ready for download",
          download_url: download_url,
          filename: "user_data_export_#{user.id}_#{export_id}.json"
        })

      %{status: status} when status in ["pending", "processing"] ->
        conn
        |> put_status(:accepted)
        |> json(%{error: "Export not ready for download", status: status})

      export ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Export not available", status: export.status})
    end
  end

  @doc """
  Request user account deletion (right to be forgotten).
  """
  def request_deletion(conn, %{"reason" => reason}) do
    user = conn.assigns.current_user
    actor_id = user.id
    request_id = conn.assigns[:gdpr_request_id]

    # Log deletion request attempt
    GdprAuthPlug.log_audit_event(conn, "ACCOUNT_DELETION_REQUESTED", %{
      user_id: user.id,
      reason: reason,
      request_id: request_id,
      ip_address: conn.assigns[:gdpr_ip_address]
    })

    case Compliance.request_user_deletion(user.id, reason, actor_id) do
      {:ok, updated_user} ->
        # Log successful deletion request
        GdprAuthPlug.log_audit_event(conn, "ACCOUNT_DELETION_REQUEST_ACCEPTED", %{
          user_id: user.id,
          status: updated_user.status,
          deleted_at: updated_user.deleted_at,
          retention_expires_at: updated_user.gdpr_retention_expires_at,
          request_id: request_id
        })

        Logger.info("User deletion request processed for user #{user.id}, reason: #{reason}")

        conn
        |> put_status(:ok)
        |> json(%{
          message: "Account deletion request processed successfully",
          status: updated_user.status,
          deleted_at: updated_user.deleted_at,
          retention_expires_at: updated_user.gdpr_retention_expires_at,
          warning: "Your account will be permanently deleted after the retention period. This action can be cancelled within 90 days.",
          request_id: request_id
        })

      {:error, :user_not_found} ->
        GdprAuthPlug.log_audit_event(conn, "ACCOUNT_DELETION_USER_NOT_FOUND", %{
          user_id: user.id,
          reason: reason,
          request_id: request_id
        })

        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found", request_id: request_id})

      {:error, :invalid_user_status} ->
        GdprAuthPlug.log_audit_event(conn, "ACCOUNT_DELETION_INVALID_STATUS", %{
          user_id: user.id,
          current_status: user.status,
          reason: reason,
          request_id: request_id
        })

        conn
        |> put_status(:conflict)
        |> json(%{
          error: "User account is already marked for deletion",
          request_id: request_id
        })

      {:error, reason} ->
        # Log deletion request failure
        GdprAuthPlug.log_audit_event(conn, "ACCOUNT_DELETION_REQUEST_FAILED", %{
          user_id: user.id,
          reason: reason,
          error: inspect(reason),
          request_id: request_id
        })

        Logger.error("Failed to process deletion request for user #{user.id}: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to process account deletion request",
          request_id: request_id
        })
    end
  end

  def request_deletion(conn, _params) do
    request_deletion(conn, %{"reason" => "user_request"})
  end

  @doc """
  Cancel pending account deletion request.
  """
  def cancel_deletion(conn, _params) do
    user = conn.assigns.current_user
    actor_id = user.id

    case Compliance.cancel_user_deletion(user.id, actor_id) do
      {:ok, restored_user} ->
        Logger.info("User deletion request cancelled for user #{user.id}")

        conn
        |> put_status(:ok)
        |> json(%{
          message: "Account deletion request cancelled successfully",
          status: restored_user.status,
          restored_at: DateTime.utc_now()
        })

      {:error, :user_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} ->
        Logger.error("Failed to cancel deletion request for user #{user.id}: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to cancel account deletion request"})
    end
  end

  @doc """
  Get deletion status for the authenticated user.
  """
  def get_deletion_status(conn, _params) do
    user = conn.assigns.current_user

    case get_user_deletion_status(user.id) do
      {:ok, status} ->
        conn
        |> put_status(:ok)
        |> json(%{status: status})

      {:error, reason} ->
        Logger.error("Failed to get deletion status for user #{user.id}: #{inspect(reason)}")
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

    case Compliance.get_user_consents(user.id) do
      {:ok, consents} ->
        formatted_consents = Enum.map(consents, fn consent ->
          %{
            id: consent.id,
            purpose: consent.purpose,
            status: consent.status,
            granted_at: consent.granted_at,
            withdrawn_at: consent.withdrawn_at,
            legal_basis: consent.legal_basis,
            ip_address: consent.ip_address
          }
        end)

        conn
        |> put_status(:ok)
        |> json(%{consents: formatted_consents})

      {:error, reason} ->
        Logger.error("Failed to get consents for user #{user.id}: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve consent information"})
    end
  end

  @doc """
  Update user consent preferences.
  """
  def update_consent(conn, %{"consents" => consent_params}) do
    user = conn.assigns.current_user
    actor_id = user.id

    case validate_consent_params(consent_params) do
      {:ok, validated_consents} ->
        case update_multiple_consents(user.id, validated_consents, actor_id) do
          {:ok, updated_consents} ->
            Logger.info("Consent preferences updated for user #{user.id}")

            conn
            |> put_status(:ok)
            |> json(%{
              message: "Consent preferences updated successfully",
              updated_consents: updated_consents
            })

          {:error, reason} ->
            Logger.error("Failed to update consents for user #{user.id}: #{inspect(reason)}")
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to update consent preferences"})
        end

      {:error, validation_error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid consent parameters", details: validation_error})
    end
  end

  def update_consent(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Consent parameters required"})
  end

  @doc """
  Get user audit trail.
  """
  def get_audit_trail(conn, %{"limit" => limit}) do
    user = conn.assigns.current_user

    case Compliance.get_user_audit_trail(user.id, String.to_integer(limit)) do
      {:ok, audit_trail} ->
        formatted_audit = Enum.map(audit_trail, fn audit ->
          %{
            id: audit.id,
            action: audit.action,
            actor_id: audit.actor_id,
            details: audit.details,
            ip_address: audit.ip_address,
            user_agent: audit.user_agent,
            created_at: audit.inserted_at
          }
        end)

        conn
        |> put_status(:ok)
        |> json(%{audit_trail: formatted_audit})

      {:error, reason} ->
        Logger.error("Failed to get audit trail for user #{user.id}: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve audit trail"})
    end
  end

  def get_audit_trail(conn, _params) do
    get_audit_trail(conn, %{"limit" => "100"})
  end

  # Admin-only endpoints

  @doc """
  Admin endpoint to delete a user.
  """
  def admin_delete_user(conn, %{"user_id" => user_id} = params) do
    admin_user = conn.assigns.current_user
    reason = Map.get(params, "reason", "admin_action")
    request_id = conn.assigns[:gdpr_request_id]

    # Enhanced audit logging for admin action
    GdprAuthPlug.log_audit_event(conn, "ADMIN_USER_DELETION_REQUESTED", %{
      admin_user_id: admin_user.id,
      target_user_id: user_id,
      reason: reason,
      request_id: request_id,
      admin_role: admin_user.role,
      ip_address: conn.assigns[:gdpr_ip_address]
    })

    case Compliance.request_user_deletion(user_id, reason, admin_user.id) do
      {:ok, updated_user} ->
        # Log successful admin deletion
        GdprAuthPlug.log_audit_event(conn, "ADMIN_USER_DELETION_COMPLETED", %{
          admin_user_id: admin_user.id,
          target_user_id: user_id,
          reason: reason,
          status: updated_user.status,
          deleted_at: updated_user.deleted_at,
          request_id: request_id
        })

        Logger.info("Admin #{admin_user.id} deleted user #{user_id}, reason: #{reason}")

        conn
        |> put_status(:ok)
        |> json(%{
          message: "User deletion processed successfully",
          user_id: user_id,
          status: updated_user.status,
          deleted_at: updated_user.deleted_at,
          deleted_by: admin_user.id,
          request_id: request_id
        })

      {:error, :user_not_found} ->
        GdprAuthPlug.log_audit_event(conn, "ADMIN_USER_DELETION_TARGET_NOT_FOUND", %{
          admin_user_id: admin_user.id,
          target_user_id: user_id,
          reason: reason,
          request_id: request_id
        })

        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found", request_id: request_id})

      {:error, reason} ->
        # Log failed admin deletion attempt
        GdprAuthPlug.log_audit_event(conn, "ADMIN_USER_DELETION_FAILED", %{
          admin_user_id: admin_user.id,
          target_user_id: user_id,
          reason: reason,
          error: inspect(reason),
          request_id: request_id
        })

        Logger.error("Admin #{admin_user.id} failed to delete user #{user_id}: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to process user deletion",
          request_id: request_id
        })
    end
  end

  @doc """
  Admin endpoint to get compliance report.
  """
  def admin_get_compliance_report(conn, _params) do
    admin_user = conn.assigns.current_user

    case Compliance.generate_compliance_report() do
      {:ok, report} ->
        conn
        |> put_status(:ok)
        |> json(%{
          compliance_report: report,
          generated_by: admin_user.id,
          generated_at: DateTime.utc_now()
        })

      {:error, reason} ->
        Logger.error("Failed to generate compliance report: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to generate compliance report"})
    end
  end

  @doc """
  Admin endpoint to get user data for investigation.
  """
  def admin_get_user_data(conn, %{"user_id" => user_id}) do
    admin_user = conn.assigns.current_user

    case get_user_data_for_admin(user_id) do
      {:ok, user_data} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user_data: user_data,
          accessed_by: admin_user.id,
          accessed_at: DateTime.utc_now()
        })

      {:error, :user_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} ->
        Logger.error("Admin #{admin_user.id} failed to access user #{user_id} data: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve user data"})
    end
  end

  @doc """
  Admin endpoint to trigger anonymization of overdue users.
  """
  def admin_anonymize_overdue_users(conn, _params) do
    admin_user = conn.assigns.current_user

    case get_overdue_users_for_anonymization() do
      [] ->
        conn
        |> put_status(:ok)
        |> json(%{message: "No users overdue for anonymization", anonymized_count: 0})

      users ->
        anonymized_count = anonymize_overdue_users(users, admin_user.id)

        conn
        |> put_status(:ok)
        |> json(%{
          message: "Anonymization process completed",
          total_overdue: length(users),
          anonymized_count: anonymized_count,
          processed_by: admin_user.id,
          processed_at: DateTime.utc_now()
        })
    end
  end

  # Private helper functions

  defp get_export_for_user(export_id, user_id) do
    # This would query the gdpr_exports table for the user's export
    # For now, return nil as the export schema needs to be checked
    nil
  end

  defp get_user_deletion_status(user_id) do
    case Repo.get(UserSchema, user_id) do
      nil ->
        {:error, :user_not_found}
      user ->
        status = %{
          id: user.id,
          status: user.status,
          deleted_at: user.deleted_at,
          deletion_reason: user.deletion_reason,
          retention_expires_at: user.gdpr_retention_expires_at,
          anonymized_at: user.anonymized_at
        }
        {:ok, status}
    end
  end

  defp validate_consent_params(consent_params) when is_map(consent_params) do
    valid_purposes = ["marketing", "analytics", "essential", "third_party_sharing"]
    valid_statuses = ["granted", "denied", "withdrawn"]

    validated = Enum.reduce(consent_params, [], fn {purpose, status}, acc ->
      if purpose in valid_purposes and status in valid_statuses do
        [{purpose, status} | acc]
      else
        acc
      end
    end)

    if length(validated) == map_size(consent_params) do
      {:ok, validated}
    else
      {:error, "Invalid consent purposes or statuses"}
    end
  end

  defp validate_consent_params(_), do: {:error, "Consent params must be a map"}

  defp update_multiple_consents(user_id, consent_updates, actor_id) do
    results = Enum.map(consent_updates, fn {purpose, status} ->
      Compliance.update_user_consent(user_id, purpose, status, actor_id)
    end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        {:ok, Enum.map(results, fn {:ok, consent} -> consent end)}
      error ->
        error
    end
  end

  defp get_user_data_for_admin(user_id) do
    case Repo.get(UserSchema, user_id) do
      nil ->
        {:error, :user_not_found}
      user ->
        # Return limited user data for admin investigation
        user_data = %{
          id: user.id,
          email: user.email,
          status: user.status,
          inserted_at: user.inserted_at,
          updated_at: user.updated_at,
          deleted_at: user.deleted_at,
          deletion_reason: user.deletion_reason,
          gdpr_retention_expires_at: user.gdpr_retention_expires_at,
          anonymized_at: user.anonymized_at
        }
        {:ok, user_data}
    end
  end

  defp get_overdue_users_for_anonymization do
    Compliance.get_users_overdue_for_anonymization()
  end

  defp anonymize_overdue_users(users, actor_id) do
    Enum.count(users, fn user ->
      case Compliance.anonymize_user_data(user.id, %{actor_id: actor_id}) do
        {:ok, _} ->
          true
        {:error, reason} ->
          Logger.error("Failed to anonymize user #{user.id}: #{inspect(reason)}")
          false
      end
    end)
  end

  # Admin role checking is now handled by the GdprAuthPlug

  # Private helper functions

  defp format_validation_error(:unsupported_format), do: "Unsupported export format. Supported: json, csv, xml"
  defp format_validation_error(:invalid_type), do: "Invalid parameter type"
  defp format_validation_error(:empty_reason), do: "Deletion reason cannot be empty"
  defp format_validation_error(:reason_too_long), do: "Deletion reason is too long (max 1000 characters)"
  defp format_validation_error(:potentially_dangerous_content), do: "Input contains potentially dangerous content"
  defp format_validation_error(:invalid_params), do: "Invalid request parameters"
  defp format_validation_error(:invalid_uuid), do: "Invalid user ID format"
  defp format_validation_error(reason), do: "Validation error: #{inspect(reason)}"
end
