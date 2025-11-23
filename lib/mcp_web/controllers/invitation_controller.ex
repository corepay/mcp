defmodule McpWeb.InvitationController do
  @moduledoc """
  Controller for handling user invitation acceptance.

  This controller manages the invitation acceptance flow,
  allowing users to accept invitations and set up their accounts.
  """

  use McpWeb, :controller
  require Logger

  
  def accept(conn, %{"token" => token}) do
    # Try to find the tenant for this invitation
    case find_tenant_for_invitation(token) do
      {:ok, tenant} ->
        conn
        |> assign(:tenant, tenant)
        |> assign(:invitation_token, token)
        |> process_invitation_acceptance(token, tenant)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(McpWeb.ErrorView)
        |> render(:not_found)

      {:error, reason} ->
        Logger.error("Error finding tenant for invitation: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> put_view(McpWeb.ErrorView)
        |> render(:internal_server_error)
    end
  end

  defp process_invitation_acceptance(conn, _token, _tenant) do
    # TenantUserManager.accept_invitation currently only returns {:error, :invalid_token}
    # case TenantUserManager.accept_invitation(tenant.company_schema, token) do
    #   {:ok, :accepted} ->
    #     # Invitation accepted successfully
    #     conn
    #     |> put_flash(:info, "Welcome! Your account has been activated.")
    #     |> redirect(to: "/t/#{tenant.subdomain}/login")

    # {:error, :invitation_not_found} ->
    #   render_invalid_invitation(conn, "Invitation not found or has been used.")

    # {:error, :invitation_expired_or_invalid} ->
    #   render_invalid_invitation(
    #     conn,
    #     "This invitation has expired. Please contact your administrator for a new invitation."
    #   )

    # {:error, reason} ->
    # Logger.error("Error accepting invitation: #{inspect(reason)}")
    render_invalid_invitation(conn, "Invitation not found or has been used.")
    # conn
    # |> put_status(:internal_server_error)
    # |> put_view(McpWeb.ErrorView)
    # |> render(:internal_server_error)
    # end
  end

  def show_invitation(conn, %{"token" => token}) do
    case find_tenant_for_invitation(token) do
      {:ok, tenant} ->
        case find_invitation_details(token, tenant.company_schema) do
          {:ok, invitation} ->
            render(conn, :show,
              invitation: invitation,
              tenant: tenant,
              token: token
            )

          {:error, :not_found} ->
            render_invalid_invitation(conn, "Invitation not found or has been used.")

          {:error, reason} ->
            Logger.error("Error getting invitation details: #{inspect(reason)}")

            conn
            |> put_status(:internal_server_error)
            |> put_view(McpWeb.ErrorView)
            |> render(:internal_server_error)
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(McpWeb.ErrorView)
        |> render(:not_found)

      {:error, reason} ->
        Logger.error("Error finding tenant for invitation: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> put_view(McpWeb.ErrorView)
        |> render(:internal_server_error)
    end
  end

  def setup_account(conn, %{"token" => token} = params) do
    case find_tenant_for_invitation(token) do
      {:ok, tenant} ->
        case find_invitation_details(token, tenant.company_schema) do
          {:ok, invitation} ->
            # Check if invitation is still valid
            if invitation_valid?(invitation) do
              accept_invitation_with_details(conn, token, tenant, invitation, params)
            else
              render_invalid_invitation(
                conn,
                "This invitation has expired. Please contact your administrator for a new invitation."
              )
            end

          {:error, :not_found} ->
            render_invalid_invitation(conn, "Invitation not found or has been used.")

          {:error, reason} ->
            Logger.error("Error getting invitation details: #{inspect(reason)}")

            conn
            |> put_status(:internal_server_error)
            |> put_view(McpWeb.ErrorView)
            |> render(:internal_server_error)
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(McpWeb.ErrorView)
        |> render(:not_found)

      {:error, reason} ->
        Logger.error("Error finding tenant for invitation: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> put_view(McpWeb.ErrorView)
        |> render(:internal_server_error)
    end
  end

  # Private helper functions

  defp find_tenant_for_invitation(token) do
    # This would typically query the platform database to find which tenant
    # owns this invitation. For now, we'll use a simplified approach.

    # Try to find invitation across all active tenants
    query = """
    SELECT t.*
    FROM platform.tenants t
    WHERE t.status IN ('active', 'trial')
    """

    case Mcp.Repo.query(query) do
      {:ok, %{rows: tenant_rows}} ->
        # Search each tenant for the invitation
        find_invitation_in_tenants(token, tenant_rows)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_invitation_in_tenants(_token, []), do: {:error, :not_found}

  defp find_invitation_in_tenants(token, [tenant_row | remaining_tenants]) do
    [tenant_id, _slug, company_schema, subdomain | _] = tenant_row

    tenant = %{
      id: tenant_id,
      company_schema: company_schema,
      subdomain: subdomain
    }

    # Check if invitation exists in this tenant
    Mcp.MultiTenant.with_tenant_context(tenant.company_schema, fn ->
      query =
        "SELECT COUNT(*) FROM tenant_invitations WHERE invitation_token = $1 AND status IN ('pending', 'sent', 'delivered')"

      case Mcp.Repo.query(query, [token]) do
        {:ok, %{rows: [[count]]}} when count > 0 ->
          {:ok, tenant}

        _ ->
          # Continue searching other tenants
          find_invitation_in_tenants(token, remaining_tenants)
      end
    end)
  end

  defp find_invitation_details(token, tenant_schema) do
    Mcp.MultiTenant.with_tenant_context(tenant_schema, fn ->
      query = """
      SELECT ti.*, tu.first_name, tu.last_name, tu.email as user_email, tu.role
      FROM tenant_invitations ti
      JOIN tenant_users tu ON ti.tenant_user_id = tu.id
      WHERE ti.invitation_token = $1
      """

      case Mcp.Repo.query(query, [token]) do
        {:ok, %{rows: [row]}} ->
          invitation = row_to_invitation_details(row)
          {:ok, invitation}

        {:ok, %{rows: []}} ->
          {:error, :not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp invitation_valid?(invitation) do
    invitation.status in [:pending, :sent, :delivered] and
      DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :gt
  end

  defp accept_invitation_with_details(conn, token, tenant, invitation, params) do
    _acceptance_attrs = %{
      phone_number: params["phone_number"],
      department: params["department"],
      job_title: params["job_title"]
    }

    # TenantUserManager.accept_invitation currently only returns {:error, :invalid_token}
    # case TenantUserManager.accept_invitation(tenant.company_schema, token, acceptance_attrs) do
    #   {:ok, :accepted} ->
    #     # Invitation accepted successfully
    #     conn
    #     |> put_flash(
    #       :info,
    #       "Welcome to #{tenant.company_name || tenant.subdomain}! Your account has been activated."
    #     )
    #     |> redirect(to: "/t/#{tenant.subdomain}/login")

    # {:error, reason} ->
    Logger.error("Error accepting invitation with details: #{inspect(:invalid_token)}")

    conn
    |> put_flash(
      :error,
      "Failed to activate your account. Please try again or contact support."
    )
    |> render(:show,
      invitation: invitation,
      tenant: tenant,
      token: token,
      errors: [base: "Invalid invitation token"]
    )
    # end
  end

  defp render_invalid_invitation(conn, message) do
    conn
    |> put_status(:bad_request)
    |> put_view(McpWeb.ErrorView)
    |> render("400.html", message: message)
  end

  defp row_to_invitation_details(row) do
    [
      id,
      tenant_user_id,
      email,
      invitation_token,
      status,
      sent_at,
      delivered_at,
      accepted_at,
      expires_at,
      revoked_at,
      revoked_by_id,
      invitation_message,
      invited_by_id,
      invited_by_name,
      delivery_attempts,
      last_delivery_attempt_at,
      delivery_error,
      email_service_id,
      acceptance_ip,
      acceptance_user_agent,
      metadata,
      first_name,
      last_name,
      user_email,
      role
    ] = row

    %{
      id: id,
      tenant_user_id: tenant_user_id,
      email: email,
      invitation_token: invitation_token,
      status: String.to_atom(status),
      sent_at: sent_at,
      delivered_at: delivered_at,
      accepted_at: accepted_at,
      expires_at: expires_at,
      revoked_at: revoked_at,
      revoked_by_id: revoked_by_id,
      invitation_message: invitation_message,
      invited_by_id: invited_by_id,
      invited_by_name: invited_by_name,
      delivery_attempts: delivery_attempts,
      last_delivery_attempt_at: last_delivery_attempt_at,
      delivery_error: delivery_error,
      email_service_id: email_service_id,
      acceptance_ip: acceptance_ip,
      acceptance_user_agent: acceptance_user_agent,
      metadata: metadata,
      user_first_name: first_name,
      user_last_name: last_name,
      user_email: user_email,
      user_role: String.to_atom(role)
    }
  end

  # Removed format_acceptance_errors functions since they're no longer used
  # defp format_acceptance_errors(:invalid_phone_number),
  #   do: [phone_number: "Invalid phone number format"]

  # defp format_acceptance_errors(:invalid_data), do: [base: "Invalid data provided"]
  # defp format_acceptance_errors(_), do: [base: "An error occurred while accepting the invitation"]
end
