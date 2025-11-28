defmodule McpWeb.Plugs.PutTenantInSession do
  @moduledoc """
  Puts the current tenant ID into the session so it can be accessed by LiveViews.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if tenant = conn.assigns[:current_tenant] do
      put_session(conn, "tenant_id", tenant.id)
    else
      conn
    end
  end
end
