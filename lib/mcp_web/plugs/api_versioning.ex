defmodule McpWeb.Plugs.ApiVersioning do
  @moduledoc """
  Plug for handling API versioning via the Accept header.
  Expected format: application/vnd.mcp.v1+json
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "accept") do
      [accept_header | _] ->
        if String.contains?(accept_header, "vnd.mcp.v1") do
          assign(conn, :api_version, "v1")
        else
          # Default to v1 for now, or error out if strict
          assign(conn, :api_version, "v1")
        end
      _ ->
        assign(conn, :api_version, "v1")
    end
  end
end
