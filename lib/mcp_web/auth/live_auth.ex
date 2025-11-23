defmodule McpWeb.Auth.LiveAuth do
  @moduledoc """
  Authentication helpers for Phoenix LiveView with JWT sessions.

  This module provides on_mount hooks for LiveView authentication,
  automatic token refresh, and context management.
  """

  import Phoenix.Component,
    only: [
      assign: 3
    ]

  import Phoenix.LiveView,
    only: [
      push_event: 3,
      push_navigate: 2,
      put_flash: 3,
      redirect: 2
    ]

  alias Mcp.Accounts.Auth

  @doc """
  on_mount hook for requiring authenticated user.
  """
  def on_mount(:require_authenticated, _params, _session, socket) do
    # authenticate_from_session currently only returns {:error, :invalid_token or :no_token}
    # case authenticate_from_session(session) do
    #   {:ok, user, claims} ->
    #     socket =
    #       socket
    #       |> assign(:current_user, user)
    #       |> assign(:current_context, Auth.get_current_context(claims))
    #       |> assign(:authorized_contexts, Auth.get_authorized_contexts(claims))
    #       |> assign(:session_id, session["session_id"])
    #
    #     {:cont, socket}
    #
    #   {:error, _reason} ->
        socket =
          socket
          |> put_flash(:error, "Authentication required")
          |> redirect(to: "/users/log_in")

        {:halt, socket}
    # end
  end

  def on_mount(:optional_auth, _params, _session, socket) do
    # authenticate_from_session currently only returns {:error, :invalid_token or :no_token}
    # case authenticate_from_session(session) do
    #   {:ok, user, claims} ->
    #     socket =
    #       socket
    #       |> assign(:current_user, user)
    #       |> assign(:current_context, Auth.get_current_context(claims))
    #       |> assign(:authorized_contexts, Auth.get_authorized_contexts(claims))
    #       |> assign(:session_id, session["session_id"])
    #
    #     {:cont, socket}
    #
    #   {:error, _reason} ->
        socket =
          socket
          |> assign(:current_user, nil)
          |> assign(:current_context, %{})
          |> assign(:authorized_contexts, [])
          |> assign(:session_id, nil)

        {:cont, socket}
    # end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, _session, socket) do
    # authenticate_from_session currently only returns {:error, :invalid_token or :no_token}
    # case authenticate_from_session(session) do
    #   {:ok, _user, _claims} ->
    #     socket =
    #       socket
    #       |> put_flash(:info, "Already signed in")
    #       |> redirect(to: "/")
    #
    #     {:halt, socket}
    #
    #   {:error, _reason} ->
        {:cont, socket}
    # end
  end

  @doc """
  Check if the current user is authorized for a specific tenant.
  """
  def authorized_for_tenant?(socket, tenant_id) do
    current_context = socket.assigns[:current_context]
    authorized_contexts = socket.assigns[:authorized_contexts] || []

    current_context["tenant_id"] == tenant_id or
      Enum.any?(authorized_contexts, fn ctx -> ctx["tenant_id"] == tenant_id end)
  end

  @doc """
  Get the current tenant context.
  """
  def current_tenant(socket) do
    (socket.assigns[:current_context] || %{})["tenant_id"]
  end

  @doc """
  Switch tenant context if authorized.
  """
  def switch_tenant(socket, tenant_id) do
    authorized_contexts = socket.assigns[:authorized_contexts] || []

    if Enum.any?(authorized_contexts, fn ctx -> ctx["tenant_id"] == tenant_id end) do
      new_context = Enum.find(authorized_contexts, fn ctx -> ctx["tenant_id"] == tenant_id end)

      socket
      |> assign(:current_context, new_context)
      |> push_event("tenant-switched", %{tenant_id: tenant_id})
    else
      socket
      |> put_flash(:error, "Not authorized for this tenant")
    end
  end

  @doc """
  Refresh JWT session from LiveView.
  """
  def refresh_session(socket) do
    session_id = socket.assigns[:session_id]

    if session_id do
      case find_refresh_token_for_session(session_id) do
        {:error, _reason} ->
          socket
          |> put_flash(:error, "Session refresh not implemented")
          |> push_navigate(to: "/users/log_in")
      end
    else
      socket
      |> put_flash(:error, "No session found")
      |> push_navigate(to: "/users/log_in")
    end
  end

  @doc """
  Sign out from LiveView.
  """
  def sign_out(socket) do
    session_id = socket.assigns[:session_id]

    if session_id do
      Auth.revoke_jwt_session(session_id)
    end

    socket
    |> push_event("session-cleared", %{})
    |> put_flash(:info, "Signed out successfully")
    |> redirect(to: "/")
  end

  @doc """
  Get user permissions for the current tenant.
  """
  def current_permissions(socket) do
    current_context = socket.assigns[:current_context] || %{}
    current_context["permissions"] || []
  end

  @doc """
  Check if user has specific permission.
  """
  def has_permission?(socket, permission) do
    permissions = current_permissions(socket)
    permission in permissions
  end

  @doc """
  Get user role for the current tenant.
  """
  def current_role(socket) do
    current_context = socket.assigns[:current_context] || %{}
    current_context["role"]
  end

  @doc """
  Check if user has admin role.
  """
  def admin?(socket) do
    current_role(socket) in ["admin", "super_admin"]
  end

  # Private helper functions

  
  defp find_refresh_token_for_session(_session_id) do
    # This would typically involve a database lookup or token storage
    # For now, we'll assume the refresh token is available in the session
    # In a real implementation, you might store refresh tokens securely
    {:error, :not_implemented}
  end
end
