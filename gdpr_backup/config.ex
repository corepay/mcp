defmodule Mcp.Gdpr.Config do
  @moduledoc """
  GDPR configuration management.

  Provides centralized configuration for all GDPR compliance features
  including retention periods, legal bases, and compliance settings.
  """

  @doc """
  Default retention periods for different data categories (in days).
  """
  def retention_periods do
    %{
      # Core identity data - 90 days then anonymize
      "core_identity" => 90,
      "authentication_data" => 0,  # Immediate deletion
      "activity_data" => 90,
      "communication_data" => 90,
      "behavioral_data" => 90,
      "derived_data" => 90,

      # Financial/legal data - 7 years (legal requirement)
      "financial_data" => 2555,  # 7 years
      "tax_records" => 2555,     # 7 years

      # System data - longer retention for security
      "security_logs" => 365,    # 1 year
      "audit_trail" => 2555,     # 7 years for compliance

      # Export data - short-lived
      "data_exports" => 7       # 7 days
    }
  end

  @doc """
  Data categories classification for GDPR compliance.
  """
  def data_categories do
    %{
      "core_identity" => [
        "email",
        "first_name",
        "last_name",
        "phone_number",
        "address"
      ],
      "authentication_data" => [
        "hashed_password",
        "totp_secret",
        "backup_codes",
        "oauth_tokens"
      ],
      "activity_data" => [
        "sign_ins",
        "api_calls",
        "user_actions",
        "page_views"
      ],
      "communication_data" => [
        "email_history",
        "sms_logs",
        "notifications",
        "support_tickets"
      ],
      "behavioral_data" => [
        "preferences",
        "settings",
        "analytics_events",
        "user_behavior"
      ],
      "derived_data" => [
        "reports",
        "insights",
        "aggregated_data",
        "analytics_data"
      ]
    }
  end

  @doc """
  Legal bases for data processing under GDPR.
  """
  def legal_bases do
    [
      %{
        code: "consent",
        name: "Consent",
        description: "The user has given clear consent for processing",
        valid_for: [:marketing, :analytics, :third_party]
      },
      %{
        code: "contract",
        name: "Contractual Necessity",
        description: "Processing is necessary for the performance of a contract",
        valid_for: [:essential, :core_identity, :authentication_data]
      },
      %{
        code: "legal_obligation",
        name: "Legal Obligation",
        description: "Processing is necessary for compliance with legal obligations",
        valid_for: [:financial_data, :tax_records, :audit_trail]
      },
      %{
        code: "legitimate_interest",
        name: "Legitimate Interest",
        description: "Processing is necessary for legitimate interests pursued by controller",
        valid_for: [:security_logs, :fraud_prevention, :service_improvement]
      }
    ]
  end

  @doc """
  Get retention period for a data category.
  """
  def get_retention_period(category) do
    Map.get(retention_periods(), category, 90)
  end

  @doc """
  Get data categories for a specific field.
  """
  def get_data_category(field) do
    Enum.find_value(data_categories(), [], fn {category, fields} ->
      if field in fields, do: [category], else: nil
    end)
  end

  @doc """
  Check if a legal basis is valid for a data category.
  """
  def valid_legal_basis?(legal_basis, data_category) do
    legal_basis_info = Enum.find(legal_bases(), &(&1.code == legal_basis))

    if legal_basis_info do
      atom_category = String.to_atom(data_category)
      atom_category in legal_basis_info.valid_for
    else
      false
    end
  end

  @doc """
  Default export settings.
  """
  def export_settings do
    %{
      max_file_size_mb: 50,
      max_download_count: 5,
      expiry_hours: 48,
      supported_formats: ["json", "csv", "pdf"]
    }
  end

  @doc """
  Anonymization settings.
  """
  def anonymization_settings do
    %{
      batch_size: 100,
      max_retries: 3,
      retry_delay_seconds: 60,
      email_domain: "deleted.local",
      placeholder_name: "Deleted User"
    }
  end

  @doc """
  Compliance monitoring settings.
  """
  def compliance_settings do
    %{
      # Monitoring intervals (in seconds)
      retention_check_interval: 3600,      # 1 hour
      compliance_check_interval: 86400,    # 24 hours
      audit_check_interval: 604800,        # 1 week

      # Alert thresholds
      overdue_users_threshold: 10,
      failed_jobs_threshold: 5,
      audit_gap_threshold: 100,

      # Retention for compliance data
      audit_retention_years: 7,
      compliance_report_retention_months: 24
    }
  end

  @doc """
  Get configuration value with fallback to default.
  """
  def get_config(key, default \\ nil) do
    Application.get_env(:mcp, Mcp.Gdpr, [])
    |> Keyword.get(key, default)
  end

  @doc """
  Check if GDPR features are enabled.
  """
  def gdpr_enabled? do
    get_config(:enabled, true)
  end

  @doc """
  Get the retention period for deletion requests (grace period).
  """
  def deletion_grace_period_days do
    get_config(:deletion_grace_period_days, 14)
  end

  @doc """
  Get the standard retention period for deleted users.
  """
  def standard_retention_days do
    get_config(:standard_retention_days, 90)
  end

  @doc """
  Check if automatic anonymization is enabled.
  """
  def auto_anonymization_enabled? do
    get_config(:auto_anonymization_enabled, true)
  end

  @doc """
  Get the timezone for GDPR operations.
  """
  def timezone do
    get_config(:timezone, "UTC")
  end
end