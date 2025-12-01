defmodule McpWeb.TenantSessionController do
  use McpWeb, :controller

  def create(conn, %{"tenant_id" => tenant_id}) do
    conn
    |> put_session("tenant_id", tenant_id)
    |> put_flash(:info, "Switched tenant context.")
    |> redirect(to: ~p"/tenant/dashboard")
  end
end
