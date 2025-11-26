defmodule McpWeb.BodyReader do
  @moduledoc """
  Plug to read the raw request body and store it in the connection assign.
  This is useful for verifying webhooks signatures.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.assign(conn, :raw_body, body)
    {:ok, body, conn}
  end
end
