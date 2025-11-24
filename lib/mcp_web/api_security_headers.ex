defmodule McpWeb.ApiSecurityHeaders do
  @moduledoc """
  Plug for adding security headers to API responses.
  """

  import Plug.Conn

  @doc """
  Initialize the plug with options.
  """
  def init(opts \\ []), do: opts

  @doc """
  Call the plug to add security headers.
  """
  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=(), payment=()")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("content-security-policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'")
    |> put_resp_header("access-control-allow-origin", get_allowed_origin(conn))
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-Requested-With, X-CSRF-Token")
    |> put_resp_header("access-control-max-age", "86400")
    |> put_resp_header("access-control-allow-credentials", "true")
  end

  defp get_allowed_origin(conn) do
    # Get the origin from the request
    origin = get_req_header(conn, "origin")

    case origin do
      [origin] ->
        # In production, you might want to validate against a whitelist
        # For now, allow same-origin and configured origins
        if String.contains?(origin, get_host(conn)) do
          origin
        else
          "null"  # Reject cross-origin requests
        end
      [] ->
        "null"
      _ ->
        "null"
    end
  end

  defp get_host(conn) do
    case get_req_header(conn, "host") do
      [host] -> host
      [] -> conn.host
    end
  end
end