defmodule Mcp.Platform.TenantUserManager do
  @moduledoc """
  Tenant user management for multi-tenant user associations.
  
  Manages:
  - User invitations to tenants
  - User-tenant role assignments
  - Tenant user listing
  - User removal from tenants
  
  Note: User-tenant associations are stored in the tenant's settings
  or can be managed via a separate TenantUser resource when needed.
  """

  alias Mcp.Platform.Tenant
  alias Mcp.Accounts.User
  require Logger

  @valid_roles [:owner, :admin, :member, :viewer]

  @doc """
  Invites a user to a tenant with a specific role.
  
  Creates an invitation token that can be used to accept the invitation.
  """
  def invite_user(tenant_id, user_email, role) when role in @valid_roles do
    with {:ok, tenant} <- Tenant.get(tenant_id),
         :ok <- validate_email(user_email) do
      
      # Generate invitation token
      invitation_token = generate_invitation_token()
      
      # Store invitation in tenant settings
      invitations = get_tenant_invitations(tenant)
      
      new_invitation = %{
        "email" => user_email,
        "role" => to_string(role),
        "token" => invitation_token,
        "invited_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "expires_at" => DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.to_iso8601(),
        "status" => "pending"
      }
      
      updated_invitations = [new_invitation | invitations]
      
      case update_tenant_invitations(tenant, updated_invitations) do
        {:ok, _tenant} ->
          Logger.info("Invited #{user_email} to tenant #{tenant_id} as #{role}")
          {:ok, %{
            tenant_id: tenant_id,
            email: user_email,
            role: role,
            token: invitation_token,
            expires_at: new_invitation["expires_at"]
          }}
          
        error ->
          error
      end
    end
  end

  def invite_user(_tenant_id, _user_email, invalid_role) do
    {:error, {:invalid_role, invalid_role, valid_roles: @valid_roles}}
  end

  @doc """
  Accepts a tenant invitation using the invitation token.
  """
  def accept_invitation(tenant_schema, token) do
    accept_invitation(tenant_schema, token, %{})
  end

  @doc """
  Accepts a tenant invitation with additional user details.
  """
  def accept_invitation(tenant_schema, token, acceptance_attrs) do
    # Extract tenant_id from schema name
    tenant_id = String.replace_prefix(tenant_schema, "acq_", "")
    
    with {:ok, tenant} <- Tenant.get(tenant_id),
         {:ok, invitation} <- find_valid_invitation(tenant, token),
         {:ok, user} <- get_or_create_user(invitation["email"], acceptance_attrs),
         {:ok, _} <- add_user_to_tenant(tenant, user, invitation["role"]),
         {:ok, _} <- mark_invitation_accepted(tenant, token) do
      
      Logger.info("User #{user.email} accepted invitation to tenant #{tenant_id}")
      {:ok, %{user: user, tenant: tenant, role: invitation["role"]}}
    end
  end

  @doc """
  Gets all users associated with a tenant.
  
  Returns list of users with their roles.
  """
  def get_tenant_users(tenant_id) do
    with {:ok, tenant} <- Tenant.get(tenant_id) do
      users = get_users_from_tenant(tenant)
      {:ok, users}
    end
  end

  @doc """
  Updates a user's role within a tenant.
  """
  def update_user_role(tenant_id, user_id, new_role) when new_role in @valid_roles do
    with {:ok, tenant} <- Tenant.get(tenant_id),
         {:ok, user} <- User.get(user_id),
         {:ok, _} <- update_user_role_in_tenant(tenant, user, new_role) do
      
      Logger.info("Updated user #{user_id} role to #{new_role} in tenant #{tenant_id}")
      {:ok, %{tenant_id: tenant_id, user_id: user_id, role: new_role}}
    end
  end

  def update_user_role(_tenant_id, _user_id, invalid_role) do
    {:error, {:invalid_role, invalid_role, valid_roles: @valid_roles}}
  end

  @doc """
  Removes a user from a tenant.
  """
  def remove_user(tenant_id, user_id) do
    with {:ok, tenant} <- Tenant.get(tenant_id),
         {:ok, user} <- User.get(user_id),
         {:ok, _} <- remove_user_from_tenant(tenant, user) do
      
      Logger.info("Removed user #{user_id} from tenant #{tenant_id}")
      :ok
    end
  end

  @doc """
  Lists all pending invitations for a tenant.
  """
  def list_pending_invitations(tenant_id) do
    with {:ok, tenant} <- Tenant.get(tenant_id) do
      invitations = get_tenant_invitations(tenant)
      
      pending = Enum.filter(invitations, fn inv ->
        inv["status"] == "pending" and not invitation_expired?(inv)
      end)
      
      {:ok, pending}
    end
  end

  @doc """
  Revokes a pending invitation.
  """
  def revoke_invitation(tenant_id, token) do
    with {:ok, tenant} <- Tenant.get(tenant_id),
         {:ok, _invitation} <- find_invitation(tenant, token),
         {:ok, _} <- remove_invitation(tenant, token) do
      
      Logger.info("Revoked invitation #{token} for tenant #{tenant_id}")
      :ok
    end
  end

  # Private functions

  defp generate_invitation_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp get_tenant_invitations(tenant) do
    settings = tenant.settings || %{}
    Map.get(settings, "invitations", [])
  end

  defp update_tenant_invitations(tenant, invitations) do
    current_settings = tenant.settings || %{}
    updated_settings = Map.put(current_settings, "invitations", invitations)
    Tenant.update(tenant, %{settings: updated_settings})
  end

  defp get_users_from_tenant(tenant) do
    settings = tenant.settings || %{}
    Map.get(settings, "users", [])
  end

  defp add_user_to_tenant(tenant, user, role) do
    users = get_users_from_tenant(tenant)
    
    new_user_entry = %{
      "user_id" => user.id,
      "email" => user.email,
      "role" => role,
      "joined_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    updated_users = [new_user_entry | users]
    current_settings = tenant.settings || %{}
    updated_settings = Map.put(current_settings, "users", updated_users)
    
    Tenant.update(tenant, %{settings: updated_settings})
  end

  defp update_user_role_in_tenant(tenant, user, new_role) do
    users = get_users_from_tenant(tenant)
    
    updated_users = Enum.map(users, fn u ->
      if u["user_id"] == user.id do
        Map.put(u, "role", to_string(new_role))
      else
        u
      end
    end)
    
    current_settings = tenant.settings || %{}
    updated_settings = Map.put(current_settings, "users", updated_users)
    
    Tenant.update(tenant, %{settings: updated_settings})
  end

  defp remove_user_from_tenant(tenant, user) do
    users = get_users_from_tenant(tenant)
    updated_users = Enum.reject(users, fn u -> u["user_id"] == user.id end)
    
    current_settings = tenant.settings || %{}
    updated_settings = Map.put(current_settings, "users", updated_users)
    
    Tenant.update(tenant, %{settings: updated_settings})
  end

  defp find_valid_invitation(tenant, token) do
    invitations = get_tenant_invitations(tenant)
    
    case Enum.find(invitations, fn inv -> inv["token"] == token end) do
      nil ->
        {:error, :invitation_not_found}
        
      invitation ->
        cond do
          invitation["status"] != "pending" ->
            {:error, :invitation_already_used}
            
          invitation_expired?(invitation) ->
            {:error, :invitation_expired}
            
          true ->
            {:ok, invitation}
        end
    end
  end

  defp find_invitation(tenant, token) do
    invitations = get_tenant_invitations(tenant)
    
    case Enum.find(invitations, fn inv -> inv["token"] == token end) do
      nil -> {:error, :invitation_not_found}
      invitation -> {:ok, invitation}
    end
  end

  defp mark_invitation_accepted(tenant, token) do
    invitations = get_tenant_invitations(tenant)
    
    updated_invitations = Enum.map(invitations, fn inv ->
      if inv["token"] == token do
        Map.merge(inv, %{
          "status" => "accepted",
          "accepted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
      else
        inv
      end
    end)
    
    update_tenant_invitations(tenant, updated_invitations)
  end

  defp remove_invitation(tenant, token) do
    invitations = get_tenant_invitations(tenant)
    updated_invitations = Enum.reject(invitations, fn inv -> inv["token"] == token end)
    update_tenant_invitations(tenant, updated_invitations)
  end

  defp invitation_expired?(invitation) do
    case DateTime.from_iso8601(invitation["expires_at"]) do
      {:ok, expires_at, _} ->
        DateTime.compare(DateTime.utc_now(), expires_at) == :gt
        
      _ ->
        true
    end
  end

  defp get_or_create_user(email, _acceptance_attrs) do
    case User.by_email(email) do
      {:ok, user} ->
        {:ok, user}
        
      {:error, _} ->
        # User doesn't exist - they need to register first
        {:error, :user_not_found}
    end
  end

  defp validate_email(email) do
    if String.contains?(email, "@") do
      :ok
    else
      {:error, :invalid_email}
    end
  end
end