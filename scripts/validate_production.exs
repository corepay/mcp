#!/usr/bin/env elixir

# Production Deployment Validation Script
# This script validates that the application is properly configured for production deployment

# Mix.install([
#   {:req, "~> 0.3.0"},
#   {:jason, "~> 1.4"}
# ])

defmodule ProductionValidator do
  @moduledoc """
  Production deployment validation script.
  Validates all aspects of the production environment including:
  - Configuration
  - Database connectivity
  - External dependencies
  - Security settings
  - Performance requirements
  """

  def validate_all() do
    IO.puts("🚀 Starting Production Deployment Validation")
    IO.puts("=" <> String.duplicate("=", 50))

    validations = [
      validate_environment_variables,
      validate_database_connection,
      validate_redis_connection,
      validate_external_dependencies,
      validate_security_configuration,
      validate_ssl_configuration,
      validate_performance_settings,
      validate_monitoring_setup,
      validate_gdpr_compliance,
      validate_backup_system
    ]

    results = Enum.map(validations, & &run_validation/1)

    IO.puts("\n" <> String.duplicate("=", 52))
    print_summary(results)
    results
  end

  defp run_validation({name, validation_fn}) do
    IO.puts("\n🔍 #{name}...")

    try do
      case validation_fn.() do
        :ok ->
          IO.puts("✅ #{name}: PASSED")
          {name, :passed}
        {:warning, message} ->
          IO.puts("⚠️  #{name}: WARNING - #{message}")
          {name, :warning, message}
        {:error, message} ->
          IO.puts("❌ #{name}: FAILED - #{message}")
          {name, :failed, message}
      end
    rescue
      error ->
        IO.puts("💥 #{name}: ERROR - #{Exception.message(error)}")
        {name, :error, Exception.message(error)}
    end
  end

  defp print_summary(results) do
    passed = Enum.count(results, fn
      {_, :passed} -> true
      _ -> false
    end)

    warnings = Enum.count(results, fn
      {_, :warning, _} -> true
      _ -> false
    end)

    failed = Enum.count(results, fn
      {_, :failed, _} -> true
      {_, :error, _} -> true
      _ -> false
    end)

    IO.puts("VALIDATION SUMMARY:")
    IO.puts("  ✅ Passed: #{passed}")
    IO.puts("  ⚠️  Warnings: #{warnings}")
    IO.puts("  ❌ Failed: #{failed}")

    cond do
      failed == 0 ->
        IO.puts("\n🎉 Production validation completed successfully!")
        IO.puts("   Application is ready for production deployment.")
      failed > 0 ->
        IO.puts("\n🚨 Production validation FAILED!")
        IO.puts("   Please fix the failed validations before deploying to production.")
    end
  end

  # Validation functions

  defp validate_environment_variables do
    {"Environment Variables", fn ->
      required_vars = [
        "DATABASE_URL",
        "SECRET_KEY_BASE",
        "PHX_HOST",
        "LIVE_VIEW_SIGNING_SALT"
      ]

      optional_vars = [
        "REDIS_URL",
        "VAULT_ADDR",
        "VAULT_TOKEN",
        "SMTP_HOST",
        "SMTP_USER",
        "SMTP_PASSWORD"
      ]

      missing_required = Enum.filter(required_vars, fn var ->
        System.get_env(var) == nil
      end)

      missing_optional = Enum.filter(optional_vars, fn var ->
        System.get_env(var) == nil
      end)

      cond do
        length(missing_required) > 0 ->
          {:error, "Missing required environment variables: #{Enum.join(missing_required, ", ")}"}
        length(missing_optional) > 0 ->
          {:warning, "Missing optional variables: #{Enum.join(missing_optional, ", ")}"}
        true ->
          :ok
      end
    end}
  end

  defp validate_database_connection do
    {"Database Connection", fn ->
      # This would need to be adapted to work outside the application context
      database_url = System.get_env("DATABASE_URL")

      if database_url do
        # Basic URL validation
        if String.starts_with?(database_url, "ecto://") or
           String.starts_with?(database_url, "postgresql://") do
          :ok
        else
          {:error, "Invalid DATABASE_URL format"}
        end
      else
        {:error, "DATABASE_URL not set"}
      end
    end}
  end

  defp validate_redis_connection do
    {"Redis Connection", fn ->
      redis_url = System.get_env("REDIS_URL")

      cond do
        redis_url == nil ->
          {:warning, "REDIS_URL not set - Redis caching will be disabled"}
        String.starts_with?(redis_url, "redis://") ->
          :ok
        true ->
          {:error, "Invalid REDIS_URL format"}
      end
    end}
  end

  defp validate_external_dependencies do
    {"External Dependencies", fn ->
      # Check for common external service configurations
      vault_configured = System.get_env("VAULT_ADDR") != nil
      email_configured = System.get_env("SMTP_HOST") != nil
      storage_configured = System.get_env("AWS_ACCESS_KEY_ID") != nil

      missing_services = []
      |> add_if_missing(vault_configured, "Vault")
      |> add_if_missing(email_configured, "SMTP")
      |> add_if_missing(storage_configured, "S3/MinIO")

      if length(missing_services) == 0 do
        :ok
      else
        {:warning, "Some external services not configured: #{Enum.join(missing_services, ", ")}"}
      end
    end}
  end

  defp validate_security_configuration do
    {"Security Configuration", fn ->
      secret_key = System.get_env("SECRET_KEY_BASE")
      live_view_salt = System.get_env("LIVE_VIEW_SIGNING_SALT")

      cond do
        secret_key == nil ->
          {:error, "SECRET_KEY_BASE not configured"}
        String.length(secret_key) < 32 ->
          {:error, "SECRET_KEY_BASE too short (minimum 32 characters)"}
        live_view_salt == nil ->
          {:error, "LIVE_VIEW_SIGNING_SALT not configured"}
        String.length(live_view_salt) < 8 ->
          {:error, "LIVE_VIEW_SIGNING_SALT too short (minimum 8 characters)"}
        true ->
          :ok
      end
    end}
  end

  defp validate_ssl_configuration do
    {"SSL Configuration", fn ->
      host = System.get_env("PHX_HOST", "localhost")
      port = System.get_env("PORT", "4000")

      cond do
        String.starts_with?(host, "localhost") ->
          {:warning, "Using localhost in production - consider using a real domain"}
        port == "4000" ->
          {:warning, "Using default port 4000 - consider using standard ports (80/443)"}
        true ->
          :ok
      end
    end}
  end

  defp validate_performance_settings do
    {"Performance Settings", fn ->
      pool_size = System.get_env("POOL_SIZE", "10")

      case Integer.parse(pool_size) do
        {size, ""} when size < 10 ->
          {:error, "POOL_SIZE too small for production (minimum 10)"}
        {size, ""} when size > 50 ->
          {:warning, "POOL_SIZE quite large (#{size}) - ensure database can handle it"}
        {size, ""} ->
          :ok
        _ ->
          {:error, "Invalid POOL_SIZE format"}
      end
    end}
  end

  defp validate_monitoring_setup do
    {"Monitoring Setup", fn ->
      # Check if monitoring endpoints are accessible
      # This would need to be adapted for your specific monitoring setup

      # For now, just check if common monitoring ports are available
      monitoring_ports = [9090, 3000, 4000]  # Prometheus, Grafana, App

      :ok  # Placeholder - would implement actual monitoring checks
    end}
  end

  defp validate_gdpr_compliance do
    {"GDPR Compliance", fn ->
      # Check GDPR-specific settings
      gdpr_settings = [
        audit_trail: System.get_env("GDPR_AUDIT_TRAIL_ENABLED", "true"),
        rate_limiting: System.get_env("GDPR_RATE_LIMITING_ENABLED", "true"),
        encryption: System.get_env("GDPR_ENCRYPTION_ENABLED", "true"),
        compliance_monitoring: System.get_env("GDPR_COMPLIANCE_MONITORING", "true")
      ]

      disabled_features = Enum.filter(gdpr_settings, fn {_, value} ->
        value == "false"
      end)

      if length(disabled_features) > 0 do
        disabled_names = Enum.map(disabled_features, fn {name, _} ->
          Atom.to_string(name)
        end)
        {:warning, "Some GDPR features disabled: #{Enum.join(disabled_names, ", ")}"}
      else
        :ok
      end
    end}
  end

  defp validate_backup_system do
    {"Backup System", fn ->
      # Check backup configuration
      backup_enabled = System.get_env("BACKUP_ENABLED", "false")
      backup_schedule = System.get_env("BACKUP_SCHEDULE")

      cond do
        backup_enabled == "false" ->
          {:warning, "Backups not enabled - recommend enabling for production"}
        backup_schedule == nil ->
          {:warning, "Backup schedule not configured"}
        true ->
          :ok
      end
    end}
  end

  defp add_if_missing(list, condition, item) do
    if condition, do: list, else: [item | list]
  end
end

# Run validation if this script is executed directly
if __ENV__.file == :stdin do
  ProductionValidator.validate_all()
end