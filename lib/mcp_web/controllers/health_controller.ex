defmodule McpWeb.HealthController do
  use McpWeb, :controller

  @moduledoc """
  Health check controller for production monitoring and alerting.
  Provides endpoints for:
  - Basic health checks
  - System status monitoring
  - Dependency health verification
  - Production readiness validation
  """

  def health(conn, _params) do
    # Basic health check - responds quickly for load balancers
    health_status = %{
      status: "healthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      service: "mcp-gdpr",
      version: version_to_string(Application.spec(:mcp, :vsn)) || "unknown"
    }

    conn
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> json(health_status)
  end

  def ready(conn, _params) do
    # Readiness check - verifies all critical dependencies are ready
    readiness_status = check_readiness()

    status_code = if readiness_status.ready == true, do: 200, else: 503

    conn
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_status(status_code)
    |> json(readiness_status)
  end

  def live(conn, _params) do
    # Liveness check - verifies the application is responsive
    liveness_status = %{
      alive: true,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      uptime: get_uptime(),
      memory: get_memory_stats(),
      processes: get_process_stats()
    }

    conn
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> json(liveness_status)
  end

  def detailed(conn, _params) do
    # Detailed health check - includes all system information for monitoring
    detailed_status = %{
      status: "healthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      service: "mcp-gdpr",
      version: version_to_string(Application.spec(:mcp, :vsn)) || "unknown",
      uptime: get_uptime(),
      environment: config_env(),
      readiness: check_readiness(),
      dependencies: check_dependencies(),
      resources: get_resource_stats(),
      gdpr: check_gdpr_health()
    }

    status_code = if detailed_status.readiness.ready, do: 200, else: 503

    conn
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_status(status_code)
    |> json(detailed_status)
  end

  # Private helper functions

  defp check_readiness do
    %{
      ready: check_database_connection() and check_redis_connection() and check_job_queue(),
      checks: %{
        database: check_database_connection(),
        redis: check_redis_connection(),
        job_queue: check_job_queue(),
        migrations: check_migrations()
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp check_database_connection do
    try do
      Mcp.Repo.query("SELECT 1", [])
      true
    rescue
      _ -> false
    end
  end

  defp check_redis_connection do
    try do
      # Check if Redis is available (basic ping)
      case Redix.command(:redix, ["PING"]) do
        {:ok, "PONG"} -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp check_job_queue do
    try do
      # Check if Oban is running and can queue jobs
      Oban.config()
      true
    rescue
      _ -> false
    end
  end

  defp check_migrations do
    try do
      # Basic check that migrations table exists and has data
      Mcp.Repo.query("SELECT COUNT(*) FROM schema_migrations", [])
      true
    rescue
      _ -> false
    end
  end

  defp check_dependencies do
    %{
      database: get_database_info(),
      redis: get_redis_info(),
      oban: get_oban_info(),
      storage: get_storage_info()
    }
  end

  defp get_database_info do
    try do
      {:ok, result} = Mcp.Repo.query("SELECT version()", [])
      version = result.rows |> List.first() |> List.first()

      %{
        connected: true,
        version: version,
        pool_size: get_db_pool_size()
      }
    rescue
      _ ->
        %{
          connected: false,
          version: nil,
          pool_size: 0
        }
    end
  end

  defp get_redis_info do
    try do
      case Redix.command(:redix, ["INFO", "server"]) do
        {:ok, info} ->
          lines = String.split(info, "\r\n")
          redis_version = Enum.find(lines, &String.starts_with?(&1, "redis_version:"))

          %{
            connected: true,
            version: redis_version && String.replace_prefix(redis_version, "redis_version:", "")
          }
        _ ->
          %{connected: false, version: nil}
      end
    rescue
      _ ->
        %{connected: false, version: nil}
    end
  end

  defp get_oban_info do
    try do
      config = Oban.config()
      %{
        configured: true,
        queues: config.queues,
        crontab: length(config.crontab || [])
      }
    rescue
      _ ->
        %{configured: false, queues: [], crontab: 0}
    end
  end

  defp get_storage_info do
    %{
      minio_configured: Application.get_env(:mcp, :minio) != nil,
      s3_configured: Application.get_env(:mcp, :ex_aws) != nil
    }
  end

  defp check_gdpr_health do
    %{
      audit_trail_enabled: Application.get_env(:mcp, :gdpr)[:audit_trail_enabled] || false,
      rate_limiting_enabled: Application.get_env(:mcp, :gdpr)[:rate_limiting_enabled] || false,
      encryption_enabled: Application.get_env(:mcp, :gdpr)[:encryption_enabled] || false,
      compliance_monitoring: Application.get_env(:mcp, :gdpr)[:compliance_monitoring] || false
    }
  end

  defp get_resource_stats do
    %{
      memory: get_memory_stats(),
      processes: get_process_stats(),
      scheduler: get_scheduler_stats()
    }
  end

  defp get_memory_stats do
    memory = :erlang.memory()
    %{
      total: memory[:total],
      processes: memory[:processes],
      system: memory[:system],
      atom: memory[:atom],
      ets: memory[:ets]
    }
  end

  defp get_process_stats do
    %{
      count: :erlang.system_info(:process_count),
      limit: :erlang.system_info(:process_limit),
      run_queue: :erlang.statistics(:run_queue)
    }
  end

  defp get_scheduler_stats do
    %{
      logical_processors: System.schedulers(),
      online_processors: System.schedulers_online()
    }
  end

  defp get_uptime do
    {time_ms, _} = :erlang.statistics(:wall_clock)
    div(time_ms, 1000)  # Convert to seconds
  end

  defp get_db_pool_size do
    try do
      # Get pool size from repo configuration
      config = Mcp.Repo.config()
      Keyword.get(config, :pool_size, 0)
    rescue
      _ -> 0
    end
  end

  defp config_env do
    Application.get_env(:mcp, :env) || :unknown
  end

  defp version_to_string(version) when is_list(version) do
    to_string(version)
  end

  defp version_to_string(version) when is_binary(version) do
    version
  end

  defp version_to_string(_), do: "unknown"
end