defmodule McpWeb.Auth.GdprAuthPlug do
  @moduledoc """
  Enhanced authentication plug for GDPR endpoints with audit logging and security features.

  This plug provides:
  - Enhanced authentication validation
  - Request ID tracking for audit compliance
  - IP address and user agent capture
  - Rate limiting for GDPR operations
  - Comprehensive audit logging
  - Role-based access control
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  require Logger

  alias Mcp.Gdpr.AuditTrail
  alias McpWeb.Auth.SessionPlug
  alias McpWeb.Auth.AuthorizationPlug

  @gdpr_rate_limit_window 60 * 60  # 1 hour window
  @gdpr_rate_limit_max 50          # Max 50 GDPR requests per hour per user

  @doc """
  Initialize the plug with options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        require_auth: true,
        require_admin: false,
        audit_action: nil,
        rate_limit: true,
        track_ip: true,
        track_user_agent: true
      ],
      opts
    )
  end

  @doc """
  Call the plug to handle GDPR authentication and authorization.
  """
  def call(conn, opts) do
    conn
    |> assign(:gdpr_request_id, generate_unique_request_id())
    |> extract_client_info()
    |> add_security_headers()
    |> validate_request_method()
    |> check_rate_limit(opts)
    |> authenticate_user(opts)
    |> authorize_access(opts)
    |> log_access_attempt(opts)
  end

  @doc """
  Generate unique request ID for audit tracking.
  """
  defp generate_unique_request_id do
    "gdpr_" <>
    (:crypto.strong_rand_bytes(16) |> Base.encode64(case: :lower))
    |> String.replace("/", "_")
    |> String.replace("+", "-")
  end

  @doc """
  Add security headers to all GDPR responses.
  """
  def add_security_headers(conn) do
    conn
    |> put_resp_header("X-Content-Type-Options", "nosniff")
    |> put_resp_header("X-Frame-Options", "DENY")
    |> put_resp_header("X-XSS-Protection", "1; mode=block")
    |> put_resp_header("Referrer-Policy", "strict-origin-when-cross-origin")
    |> put_resp_header("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
    |> put_resp_header("Cache-Control", "no-store, no-cache, must-revalidate")
    |> put_resp_header("Pragma", "no-cache")
  end

  @doc """
  Validate HTTP request methods for GDPR endpoints.
  """
  def validate_request_method(conn) do
    allowed_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    if conn.method in allowed_methods do
      conn
    else
      log_audit_event(conn, "INVALID_HTTP_METHOD", %{
        method: conn.method,
        allowed_methods: allowed_methods
      })

      conn
      |> put_status(:method_not_allowed)
      |> json(%{
        error: "HTTP method not allowed",
        method: conn.method,
        allowed_methods: allowed_methods,
        request_id: conn.assigns[:gdpr_request_id]
      })
      |> halt()
    end
  end

  @doc """
  Extract client IP address and user agent for audit logging.
  """
  def extract_client_info(conn) do
    # Get real IP address considering proxies
    ip_address =
      get_req_header(conn, "x-forwarded-for")
      |> case do
        [ip | _] -> String.split(ip, ",") |> hd() |> String.trim()
        [] ->
          get_req_header(conn, "x-real-ip")
          |> case do
            [ip] -> ip
            [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
          end
      end

    user_agent =
      get_req_header(conn, "user-agent")
      |> case do
        [ua] -> ua
        [] -> "Unknown"
      end

    conn
    |> assign(:gdpr_ip_address, ip_address)
    |> assign(:gdpr_user_agent, user_agent)
  end

  @doc """
  Check rate limiting for GDPR operations.
  """
  def check_rate_limit(conn, opts) do
    if Keyword.get(opts, :rate_limit, true) do
      user_id = get_user_id_from_conn(conn)
      ip_address = conn.assigns[:gdpr_ip_address]

      key = "gdpr_rate_limit:#{user_id || ip_address}"

      case check_rate_limit_key(key) do
        :ok ->
          conn
        {:error, :rate_limit_exceeded} ->
          log_audit_event(conn, "RATE_LIMIT_EXCEEDED", %{
            reason: "Too many GDPR requests",
            limit: @gdpr_rate_limit_max,
            window: @gdpr_rate_limit_window
          })

          conn
          |> put_status(:too_many_requests)
          |> json(%{
            error: "Rate limit exceeded",
            message: "Too many GDPR requests. Please try again later.",
            retry_after: @gdpr_rate_limit_window
          })
          |> halt()
      end
    else
      conn
    end
  end

  @doc """
  Authenticate user for GDPR operations.
  """
  def authenticate_user(conn, opts) do
    if Keyword.get(opts, :require_auth, true) do
      case get_current_user(conn) do
        {:ok, user} ->
          assign(conn, :current_user, user)
        {:error, reason} ->
          log_audit_event(conn, "AUTHENTICATION_FAILED", %{
            reason: reason,
            required_auth: Keyword.get(opts, :require_auth, true)
          })

          conn
          |> put_status(:unauthorized)
          |> json(%{
            error: "Authentication required",
            message: "Please sign in to access GDPR features",
            request_id: conn.assigns[:gdpr_request_id]
          })
          |> halt()
      end
    else
      conn
    end
  end

  @doc """
  Authorize access based on roles and permissions.
  """
  def authorize_access(conn, opts) do
    if Keyword.get(opts, :require_admin, false) do
      case get_current_user(conn) do
        {:ok, user} ->
          if admin_user?(user) do
            conn
          else
            log_audit_event(conn, "AUTHORIZATION_FAILED", %{
              reason: "Admin access required",
              user_role: user.role,
              required_roles: ["admin", "super_admin"]
            })

            conn
            |> put_status(:forbidden)
            |> json(%{
              error: "Admin access required",
              message: "This endpoint requires administrator privileges",
              request_id: conn.assigns[:gdpr_request_id]
            })
            |> halt()
          end
        {:error, _reason} ->
          conn  # Already handled in authenticate_user
      end
    else
      conn
    end
  end

  @doc """
  Log access attempt for audit compliance.
  """
  def log_access_attempt(conn, opts) do
    audit_action = Keyword.get(opts, :audit_action)

    if audit_action do
      user = get_current_user(conn)

      audit_data = %{
        ip_address: conn.assigns[:gdpr_ip_address],
        user_agent: conn.assigns[:gdpr_user_agent],
        request_path: conn.request_path,
        request_method: conn.method,
        user_id: (case user do {:ok, u} -> u.id; _ -> nil end),
        session_id: get_session_id(conn),
        tenant_id: get_current_tenant(conn)
      }

      log_audit_event(conn, audit_action, audit_data)
    end

    conn
  end

  @doc """
  Log GDPR audit events.
  """
  def log_audit_event(conn, action, details \\ %{}) do
    audit_data = Map.merge(details, %{
      action: action,
      ip_address: conn.assigns[:gdpr_ip_address],
      user_agent: conn.assigns[:gdpr_user_agent],
      request_id: conn.assigns[:gdpr_request_id],
      timestamp: DateTime.utc_now(),
      endpoint: conn.request_path,
      method: conn.method
    })

    # Add user context if available
    updated_audit_data = case get_current_user(conn) do
      {:ok, user} ->
        Map.merge(audit_data, %{
          user_id: user.id,
          user_role: user.role
        })
      _ -> audit_data
    end

    # Log to application logger
    Logger.info("GDPR Audit: #{action} - #{inspect(updated_audit_data)}")

    # Store in audit trail (if available)
    case Process.whereis(Mcp.Gdpr.AuditTrail) do
      nil ->
        # Audit trail process not available, just log
        :ok
      _pid ->
        try do
          AuditTrail.log_event(
            updated_audit_data.user_id,
            action,
            updated_audit_data,
            conn.assigns[:gdpr_ip_address],
            conn.assigns[:gdpr_user_agent]
          )
        rescue
          _ ->
            # Audit logging failed, but don't crash the request
            Logger.warning("Failed to store GDPR audit event: #{inspect(updated_audit_data)}")
        end
    end
  end

  # Private helper functions

  defp get_current_user(conn) do
    # Try to get user from session
    case get_session(conn, :current_user) do
      nil ->
        # Try to get from assigns (set by other plugs)
        case conn.assigns[:current_user] do
          nil -> {:error, :no_user_in_session}
          user -> {:ok, user}
        end
      user ->
        {:ok, user}
    end
  end

  defp get_user_id_from_conn(conn) do
    case get_current_user(conn) do
      {:ok, user} -> user.id
      {:error, _reason} -> nil
    end
  end

  defp get_session_id(conn) do
    get_session(conn, :session_id) ||
    conn.cookies["_mcp_session_id"] ||
    conn.assigns[:gdpr_request_id]
  end

  defp get_current_tenant(conn) do
    conn.assigns[:current_tenant] ||
    AuthorizationPlug.current_tenant(conn)
  end

  defp admin_user?(user) do
    user.role in ["admin", "super_admin"]
  end

  defp check_rate_limit_key(key) do
    # Simple in-memory rate limiting
    # In production, use Redis or another distributed cache
    case :ets.whereis(:gdpr_rate_limits) do
      :undefined ->
        :ets.new(:gdpr_rate_limits, [:set, :named_table, :public])
        check_rate_limit_key(key)

      _table ->
        now = DateTime.utc_now() |> DateTime.to_unix()
        window_start = now - @gdpr_rate_limit_window

        case :ets.lookup(:gdpr_rate_limits, key) do
          [{^key, requests}] ->
            # Filter out old requests
            recent_requests = Enum.filter(requests, fn req_time ->
              req_time > window_start
            end)

            if length(recent_requests) >= @gdpr_rate_limit_max do
              {:error, :rate_limit_exceeded}
            else
              updated_requests = [now | recent_requests]
              :ets.insert(:gdpr_rate_limits, {key, updated_requests})
              :ok
            end

          [] ->
            :ets.insert(:gdpr_rate_limits, {key, [now]})
            :ok
        end
    end
  end

  @doc """
  Clean up old rate limit entries (should be called periodically).
  """
  def cleanup_rate_limits do
    case :ets.whereis(:gdpr_rate_limits) do
      :undefined -> :ok
      _table ->
        now = DateTime.utc_now() |> DateTime.to_unix()
        window_start = now - @gdpr_rate_limit_window

        :ets.foldl(fn {key, requests}, acc ->
          recent_requests = Enum.filter(requests, fn req_time ->
            req_time > window_start
          end)

          if Enum.empty?(recent_requests) do
            :ets.delete(:gdpr_rate_limits, key)
          else
            :ets.insert(:gdpr_rate_limits, {key, recent_requests})
          end

          acc
        end, nil, :gdpr_rate_limits)
    end
  end
end