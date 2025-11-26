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
  alias McpWeb.Auth.AuthorizationPlug

  # 1 hour window
  @gdpr_rate_limit_window 60 * 60
  # Max 50 GDPR requests per hour per user
  @gdpr_rate_limit_max 50
  # 5MB max request body size for GDPR endpoints
  @max_request_body_size 5 * 1024 * 1024

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
    |> check_request_size_limit()
    |> check_rate_limit(opts)
    |> authenticate_user(opts)
    |> authorize_access(opts)
    |> log_access_attempt(opts)
  end

  defp generate_unique_request_id do
    ("gdpr_" <>
       (:crypto.strong_rand_bytes(16) |> Base.encode64(case: :lower)))
    |> String.replace("/", "_")
    |> String.replace("+", "-")
  end

  @doc """
  Add security headers to all GDPR responses.
  """
  def add_security_headers(conn) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
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
        [ip | _] ->
          String.split(ip, ",") |> hd() |> String.trim()

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
  Check request body size limits for GDPR operations.
  """
  def check_request_size_limit(conn) do
    case get_req_header(conn, "content-length") do
      [content_length_str] ->
        case Integer.parse(content_length_str) do
          {content_length, ""} when content_length > @max_request_body_size ->
            log_audit_event(conn, "REQUEST_SIZE_EXCEEDED", %{
              content_length: content_length,
              max_size: @max_request_body_size
            })

            conn
            |> put_status(:payload_too_large)
            |> json(%{
              error: "Request entity too large",
              message:
                "Request body size (#{content_length} bytes) exceeds maximum allowed size (#{@max_request_body_size} bytes)",
              max_size: @max_request_body_size
            })
            |> halt()

          {_content_length, ""} ->
            # Within limits, continue
            conn

          _ ->
            # Invalid content-length header, continue (will be caught by Plug.Parsers)
            conn
        end

      [] ->
        # No content-length header, continue
        conn
    end
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
      check_admin_authorization(conn)
    else
      conn
    end
  end

  defp check_admin_authorization(conn) do
    case get_current_user(conn) do
      {:ok, user} ->
        authorize_admin_user(conn, user)

      {:error, _reason} ->
        # Already handled in authenticate_user
        conn
    end
  end

  defp authorize_admin_user(conn, user) do
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
        user_id:
          case user do
            {:ok, u} -> u.id
            _ -> nil
          end,
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
    audit_data =
      Map.merge(details, %{
        action: action,
        ip_address: conn.assigns[:gdpr_ip_address],
        user_agent: conn.assigns[:gdpr_user_agent],
        request_id: conn.assigns[:gdpr_request_id],
        timestamp: DateTime.utc_now(),
        endpoint: conn.request_path,
        method: conn.method
      })

    # Add user context if available
    updated_audit_data =
      case get_current_user(conn) do
        {:ok, user} ->
          Map.merge(audit_data, %{
            user_id: user.id,
            user_role: user.role
          })

        _ ->
          audit_data
      end

    # Log to application logger
    Logger.info("GDPR Audit: #{action} - #{inspect(updated_audit_data)}")

    # Store in audit trail (if available)
    case Process.whereis(Mcp.Gdpr.AuditTrail) do
      nil ->
        # Audit trail process not available, just log
        :ok

      _pid ->
        AuditTrail.log_event(
          updated_audit_data.user_id,
          action,
          updated_audit_data.actor_id,
          Map.merge(updated_audit_data, %{
            ip_address: conn.assigns[:gdpr_ip_address],
            user_agent: conn.assigns[:gdpr_user_agent]
          })
        )
    end
  rescue
    _ ->
      # Audit logging failed, but don't crash the request
      Logger.warning("Failed to store GDPR audit event: details omitted for safety")
  end

  # Private helper functions

  defp get_current_user(conn) do
    # Try to get user from session (safe check for API endpoints)
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
  rescue
    # Session not available (API endpoints)
    ArgumentError ->
      # Try to get from assigns (set by other plugs)
      case conn.assigns[:current_user] do
        nil -> {:error, :no_user_in_session}
        user -> {:ok, user}
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
  rescue
    # Session not available (API endpoints)
    ArgumentError ->
      conn.cookies["_mcp_session_id"] ||
        conn.assigns[:gdpr_request_id]
  end

  defp get_current_tenant(conn) do
    conn.assigns[:current_tenant] ||
      try do
        AuthorizationPlug.current_tenant(conn)
      rescue
        # Session not available (API endpoints)
        ArgumentError ->
          nil
      end
  end

  defp admin_user?(user) do
    # GREEN: Support both atom and string roles for admin access
    user.role in ["admin", "super_admin"] or user.role in [:admin, :super_admin]
  end

  defp check_rate_limit_key(key) do
    with {:ok, _table} <- ensure_rate_limit_table(),
         {:ok, recent_requests} <- get_recent_requests(key),
         :ok <- check_rate_limit_available(recent_requests, key) do
      :ok
    else
      {:error, :rate_limit_exceeded} -> {:error, :rate_limit_exceeded}
    end
  end

  defp ensure_rate_limit_table do
    case :ets.whereis(:gdpr_rate_limits) do
      :undefined ->
        :ets.new(:gdpr_rate_limits, [:set, :named_table, :public])
        {:ok, :gdpr_rate_limits}

      table ->
        {:ok, table}
    end
  end

  defp get_recent_requests(key) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    window_start = now - @gdpr_rate_limit_window

    case :ets.lookup(:gdpr_rate_limits, key) do
      [{^key, requests}] ->
        recent_requests = Enum.filter(requests, &(&1 > window_start))
        {:ok, recent_requests}

      [] ->
        {:ok, []}
    end
  end

  defp check_rate_limit_available(recent_requests, key) do
    if length(recent_requests) >= @gdpr_rate_limit_max do
      {:error, :rate_limit_exceeded}
    else
      now = DateTime.utc_now() |> DateTime.to_unix()
      updated_requests = [now | recent_requests]
      :ets.insert(:gdpr_rate_limits, {key, updated_requests})
      :ok
    end
  end

  @doc """
  Clean up old rate limit entries (should be called periodically).
  """
  def cleanup_rate_limits do
    case :ets.whereis(:gdpr_rate_limits) do
      :undefined ->
        :ok

      _table ->
        cleanup_old_rate_limit_entries()
    end
  end

  defp cleanup_old_rate_limit_entries do
    now = DateTime.utc_now() |> DateTime.to_unix()
    window_start = now - @gdpr_rate_limit_window

    :ets.foldl(
      fn {key, requests}, acc ->
        cleanup_rate_limit_entry(key, requests, window_start)
        acc
      end,
      nil,
      :gdpr_rate_limits
    )
  end

  defp cleanup_rate_limit_entry(key, requests, window_start) do
    recent_requests = Enum.filter(requests, &(&1 > window_start))

    if Enum.empty?(recent_requests) do
      :ets.delete(:gdpr_rate_limits, key)
    else
      :ets.insert(:gdpr_rate_limits, {key, recent_requests})
    end
  end
end
