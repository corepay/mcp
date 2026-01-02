defmodule McpWeb.Ola.ResumeLive do
  @moduledoc """
  Handles magic link resume flow for OLA applications.
  Verifies the token and redirects to the application form with resume context.
  """
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Underwriting.Services.MagicLink

  @impl true
  def mount(%{"token" => token}, session, socket) do
    case MagicLink.verify(token) do
      {:ok, %{application_id: app_id, email: _email}} ->
        tenant_id = session["tenant_id"]
        tenant = Tenant.get_by_id!(tenant_id)

        case UWApplication.get_by_id(app_id, tenant: tenant.company_schema) do
          {:ok, _application} ->
            {:ok,
             socket
             |> put_flash(:info, "Welcome back! Continue your application.")
             |> redirect(to: ~p"/online-application/application?resume=#{app_id}")}

          _ ->
            {:ok, redirect_with_error(socket, "Application not found")}
        end

      {:error, :expired} ->
        {:ok,
         redirect_with_error(socket, "This link has expired. Please start a new application.")}

      {:error, _} ->
        {:ok,
         redirect_with_error(
           socket,
           "Invalid link. Please check your email for the correct link."
         )}
    end
  end

  defp redirect_with_error(socket, message) do
    socket
    |> put_flash(:error, message)
    |> redirect(to: ~p"/online-application")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen">
      <span class="loading loading-spinner loading-lg"></span>
    </div>
    """
  end
end
