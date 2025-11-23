defmodule Mcp.Platform.TenantUserManagerTest do
  @moduledoc """
  Tests for TenantUserManager functionality.

  This test suite covers user invitations, role management,
  and user lifecycle operations within tenant contexts.
  """

  use ExUnit.Case, async: false
  use Mcp.DataCase

  alias Mcp.Platform.TenantUserManager
  alias Mcp.Platform.TenantPermissions
  alias Mcp.MultiTenant

  @tenant_schema "test_tenant"
  @valid_user_attrs %{
    email: "test@example.com",
    first_name: "John",
    last_name: "Doe",
    role: :viewer,
    department: "Engineering",
    job_title: "Developer"
  }

  describe "create_tenant_owner/2" do
    test "creates tenant owner with admin role" do
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Admin",
        last_name: "User"
      }

      assert {:ok, user_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      assert is_binary(user_id)

      # Verify the user was created correctly
      assert {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)
      assert user.email == owner_attrs.email
      assert user.role == :admin
      assert user.is_tenant_owner == true
      assert user.status == :active
    end

    test "validates required fields for tenant owner" do
      invalid_attrs = %{
        first_name: "Admin"
        # missing email and last_name
      }

      assert {:error, reason} =
               TenantUserManager.create_tenant_owner(@tenant_schema, invalid_attrs)

      assert reason != nil
    end
  end

  describe "invite_user/3" do
    setup do
      # Create a tenant owner for testing
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Owner",
        last_name: "User"
      }

      {:ok, owner_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      {:ok, owner} = TenantUserManager.get_tenant_user(@tenant_schema, owner_id)

      {:ok, owner: owner}
    end

    test "invites a new user successfully", %{owner: owner} do
      user_attrs = %{
        email: "newuser@example.com",
        first_name: "New",
        last_name: "User",
        role: :operator,
        invitation_message: "Welcome to our team!"
      }

      assert {:ok, user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
      assert is_binary(user_id)

      # Verify the user was created with pending status
      assert {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)
      assert user.email == user_attrs.email
      assert user.role == user_attrs.role
      assert user.status == :pending
      assert user.invitation_token != nil
      assert user.invitation_expires_at != nil
    end

    test "validates invitation fields", %{owner: owner} do
      invalid_attrs = %{
        email: "invalid-email",
        first_name: "Test"
        # missing last_name
      }

      assert {:error, reason} =
               TenantUserManager.invite_user(@tenant_schema, invalid_attrs, owner)

      assert reason != nil
    end

    test "prevents duplicate email invitations", %{owner: owner} do
      user_attrs = %{
        email: "duplicate@example.com",
        first_name: "First",
        last_name: "User"
      }

      # First invitation should succeed
      assert {:ok, _user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)

      # Second invitation with same email should fail
      assert {:error, _reason} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
    end
  end

  describe "accept_invitation/2" do
    setup do
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Owner",
        last_name: "User"
      }

      {:ok, owner_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      {:ok, owner} = TenantUserManager.get_tenant_user(@tenant_schema, owner_id)

      user_attrs = %{
        email: "invitee@example.com",
        first_name: "Invitee",
        last_name: "User"
      }

      {:ok, user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
      {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)

      {:ok, owner: owner, user: user, invitation_token: user.invitation_token}
    end

    test "accepts valid invitation", %{invitation_token: token} do
      acceptance_attrs = %{
        phone_number: "+1234567890",
        department: "Engineering",
        job_title: "Senior Developer"
      }

      assert {:ok, :accepted} =
               TenantUserManager.accept_invitation(@tenant_schema, token, acceptance_attrs)

      # Verify user status changed to active
      {:ok, user} = find_user_by_token(token)
      assert user.status == :active
      assert user.invitation_accepted_at != nil
    end

    test "rejects invalid invitation token" do
      assert {:error, :invitation_not_found} =
               TenantUserManager.accept_invitation(@tenant_schema, "invalid-token")
    end

    test "rejects expired invitation", %{user: user, invitation_token: token} do
      # Manually expire the invitation
      expired_time = DateTime.add(DateTime.utc_now(), -1, :day)
      update_user_invitation_expiry(user.id, expired_time)

      assert {:error, :invitation_expired_or_invalid} =
               TenantUserManager.accept_invitation(@tenant_schema, token)
    end
  end

  describe "list_tenant_users/2" do
    setup do
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Owner",
        last_name: "User"
      }

      {:ok, owner_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      {:ok, owner} = TenantUserManager.get_tenant_user(@tenant_schema, owner_id)

      # Create some test users
      users = create_test_users(owner, 5)

      {:ok, owner: owner, users: users}
    end

    test "lists all users without filters", %{users: users} do
      assert {:ok, listed_users} = TenantUserManager.list_tenant_users(@tenant_schema)
      # +1 for owner
      assert length(listed_users) >= length(users) + 1
    end

    test "filters users by role", %{owner: owner} do
      filters = %{role: :admin}
      assert {:ok, admin_users} = TenantUserManager.list_tenant_users(@tenant_schema, filters)
      # Only the owner
      assert length(admin_users) == 1
      assert hd(admin_users).email == owner.email
    end

    test "filters users by status" do
      filters = %{status: :pending}
      assert {:ok, pending_users} = TenantUserManager.list_tenant_users(@tenant_schema, filters)
      assert Enum.all?(pending_users, fn user -> user.status == :pending end)
    end

    test "searches users by name or email" do
      filters = %{search: "User"}
      assert {:ok, found_users} = TenantUserManager.list_tenant_users(@tenant_schema, filters)
      assert length(found_users) > 0

      assert Enum.all?(found_users, fn user ->
               String.contains?(user.first_name, "User") or
                 String.contains?(user.last_name, "User") or
                 String.contains?(user.email, "user")
             end)
    end
  end

  describe "update_tenant_user/4" do
    setup do
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Owner",
        last_name: "User"
      }

      {:ok, owner_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      {:ok, owner} = TenantUserManager.get_tenant_user(@tenant_schema, owner_id)

      user_attrs = %{
        email: "operator@example.com",
        first_name: "Operator",
        last_name: "User",
        role: :operator
      }

      {:ok, user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
      {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)

      {:ok, owner: owner, user: user}
    end

    test "updates user basic information", %{owner: owner, user: user} do
      updates = %{
        first_name: "Updated",
        last_name: "Name",
        phone_number: "+1234567890"
      }

      assert {:ok, :updated} =
               TenantUserManager.update_tenant_user(@tenant_schema, user.id, updates, owner)

      # Verify the updates were applied
      {:ok, updated_user} = TenantUserManager.get_tenant_user(@tenant_schema, user.id)
      assert updated_user.first_name == "Updated"
      assert updated_user.last_name == "Name"
      assert updated_user.phone_number == "+1234567890"
    end

    test "prevents unauthorized role changes", %{user: user} do
      # Create a viewer user who shouldn't be able to change roles
      viewer_attrs = %{
        email: "viewer@example.com",
        first_name: "Viewer",
        last_name: "User",
        role: :viewer
      }

      {:ok, viewer_id} = TenantUserManager.invite_user(@tenant_schema, viewer_attrs, user)
      {:ok, viewer} = TenantUserManager.get_tenant_user(@tenant_schema, viewer_id)

      updates = %{role: :admin}

      assert {:error, :insufficient_permissions} =
               TenantUserManager.update_tenant_user(@tenant_schema, user.id, updates, viewer)
    end

    test "allows admins to change roles", %{owner: owner, user: user} do
      updates = %{role: :billing_admin}

      assert {:ok, :updated} =
               TenantUserManager.update_tenant_user(@tenant_schema, user.id, updates, owner)

      {:ok, updated_user} = TenantUserManager.get_tenant_user(@tenant_schema, user.id)
      assert updated_user.role == :billing_admin
    end
  end

  describe "suspend_tenant_user/3" do
    setup do
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Owner",
        last_name: "User"
      }

      {:ok, owner_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      {:ok, owner} = TenantUserManager.get_tenant_user(@tenant_schema, owner_id)

      user_attrs = %{
        email: "suspended@example.com",
        first_name: "Suspended",
        last_name: "User"
      }

      {:ok, user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
      {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)

      {:ok, owner: owner, user: user}
    end

    test "suspends user successfully", %{owner: owner, user: user} do
      assert {:ok, :updated} =
               TenantUserManager.suspend_tenant_user(@tenant_schema, user.id, owner)

      {:ok, suspended_user} = TenantUserManager.get_tenant_user(@tenant_schema, user.id)
      assert suspended_user.status == :suspended
    end

    test "cannot suspend tenant owner", %{owner: owner} do
      assert {:error, :insufficient_permissions} =
               TenantUserManager.suspend_tenant_user(@tenant_schema, owner.id, owner)
    end
  end

  describe "resend_invitation/3" do
    setup do
      owner_attrs = %{
        email: "owner@example.com",
        first_name: "Owner",
        last_name: "User"
      }

      {:ok, owner_id} = TenantUserManager.create_tenant_owner(@tenant_schema, owner_attrs)
      {:ok, owner} = TenantUserManager.get_tenant_user(@tenant_schema, owner_id)

      user_attrs = %{
        email: "resend@example.com",
        first_name: "Resend",
        last_name: "User"
      }

      {:ok, user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
      {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)

      {:ok, owner: owner, user: user}
    end

    test "resends invitation to pending user", %{owner: owner, user: user} do
      original_token = user.invitation_token

      assert {:ok, new_token} =
               TenantUserManager.resend_invitation(@tenant_schema, user.id, owner)

      assert new_token != original_token
      assert is_binary(new_token)
    end

    test "fails for non-pending users", %{owner: owner, user: user} do
      # Accept the invitation first
      TenantUserManager.accept_invitation(@tenant_schema, user.invitation_token)

      assert {:error, :user_not_pending} =
               TenantUserManager.resend_invitation(@tenant_schema, user.id, owner)
    end
  end

  describe "permission checking" do
    test "tenant owner has all permissions" do
      owner = %{role: :admin, is_tenant_owner: true}
      assert TenantUserManager.user_has_permission?(owner, :user_management)
      assert TenantUserManager.user_has_permission?(owner, :billing_management)
      assert TenantUserManager.user_has_permission?(owner, :any_permission)
    end

    test "viewer has limited permissions" do
      viewer = %{role: :viewer, permissions: []}
      assert TenantUserManager.user_has_permission?(viewer, :view_only)
      refute TenantUserManager.user_has_permission?(viewer, :user_management)
      refute TenantUserManager.user_has_permission?(viewer, :billing_management)
    end

    test "billing admin has billing permissions" do
      billing_admin = %{role: :billing_admin, permissions: []}
      assert TenantUserManager.user_has_permission?(billing_admin, :manage_billing)
      assert TenantUserManager.user_has_permission?(billing_admin, :view_customers)
      refute TenantUserManager.user_has_permission?(billing_admin, :user_management)
    end

    test "can_manage_user? works correctly" do
      admin = %{role: :admin, is_tenant_owner: false}
      viewer = %{role: :viewer, is_tenant_owner: false}
      tenant_owner = %{role: :admin, is_tenant_owner: true}

      target_viewer = %{role: :viewer, is_tenant_owner: false}

      assert TenantUserManager.can_manage_user?(admin, target_viewer)
      refute TenantUserManager.can_manage_user?(viewer, target_viewer)
      assert TenantUserManager.can_manage_user?(tenant_owner, target_viewer)
      refute TenantUserManager.can_manage_user?(admin, tenant_owner)
    end
  end

  # Helper functions

  defp create_test_users(owner, count) do
    Enum.map(1..count, fn i ->
      user_attrs = %{
        email: "user#{i}@example.com",
        first_name: "User#{i}",
        last_name: "Test"
      }

      {:ok, user_id} = TenantUserManager.invite_user(@tenant_schema, user_attrs, owner)
      {:ok, user} = TenantUserManager.get_tenant_user(@tenant_schema, user_id)
      user
    end)
  end

  defp find_user_by_token(token) do
    MultiTenant.with_tenant_context(@tenant_schema, fn ->
      query = "SELECT * FROM tenant_users WHERE invitation_token = $1"

      case Mcp.Repo.query(query, [token]) do
        {:ok, %{rows: [row]}} ->
          user = row_to_tenant_user(row)
          {:ok, user}

        _ ->
          {:error, :not_found}
      end
    end)
  end

  defp update_user_invitation_expiry(user_id, expiry_time) do
    MultiTenant.with_tenant_context(@tenant_schema, fn ->
      query = "UPDATE tenant_users SET invitation_expires_at = $1 WHERE id = $2"
      Mcp.Repo.query(query, [expiry_time, user_id])
    end)
  end

  defp row_to_tenant_user(row) do
    [
      id,
      email,
      first_name,
      last_name,
      role,
      status,
      invitation_token,
      invitation_sent_at,
      invitation_accepted_at,
      invitation_expires_at,
      last_sign_in_at,
      last_sign_in_ip,
      sign_in_count,
      permissions,
      settings,
      is_tenant_owner,
      password_change_required,
      phone_number,
      department,
      job_title,
      notes,
      inserted_at,
      updated_at
    ] = row

    %{
      id: id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      role: String.to_atom(role),
      status: String.to_atom(status),
      invitation_token: invitation_token,
      invitation_sent_at: invitation_sent_at,
      invitation_accepted_at: invitation_accepted_at,
      invitation_expires_at: invitation_expires_at,
      last_sign_in_at: last_sign_in_at,
      last_sign_in_ip: last_sign_in_ip,
      sign_in_count: sign_in_count,
      permissions: permissions,
      settings: settings,
      is_tenant_owner: is_tenant_owner,
      password_change_required: password_change_required,
      phone_number: phone_number,
      department: department,
      job_title: job_title,
      notes: notes,
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end
end
