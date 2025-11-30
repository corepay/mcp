defmodule Mcp.Gdpr.Config do
  @moduledoc """
  GDPR configuration management.
  """

  use GenServer

  @doc """
  Starts the GDPR config GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  @doc """
  Gets configuration value.
  """
  def get(key, default \\ nil) do
    Application.get_env(:mcp, :gdpr, %{}) |> Map.get(key, default)
  end

  @doc """
  Sets configuration value.
  """
  def set(key, value) do
    current_config = Application.get_env(:mcp, :gdpr, %{})
    new_config = Map.put(current_config, key, value)
    Application.put_env(:mcp, :gdpr, new_config)
    :ok
  end
  @doc """
  Gets configuration value (alias for get).
  """
  def get_config(key, default \\ nil) do
    get(key, default)
  end

  def gdpr_enabled? do
    get(:gdpr_enabled, true)
  end

  def deletion_grace_period_days do
    get(:deletion_grace_period_days, 14)
  end

  def standard_retention_days do
    get(:standard_retention_days, 90)
  end

  def auto_anonymization_enabled? do
    get(:auto_anonymization_enabled, true)
  end

  def timezone do
    get(:timezone, "UTC")
  end

  def anonymization_settings do
    get(:anonymization_settings, %{
      method: :mask,
      fields: [:email, :name, :phone],
      batch_size: 100,
      max_retries: 3,
      retry_delay_seconds: 60,
      email_domain: "deleted.local",
      placeholder_name: "Deleted User"
    })
  end

  def compliance_settings do
    get(:compliance_settings, %{
      monitoring_enabled: true,
      audit_log_retention_days: 365,
      retention_check_interval: 24,
      compliance_check_interval: 24,
      audit_check_interval: 24,
      overdue_users_threshold: 10
    })
  end

  def export_settings do
    get(:export_settings, %{
      supported_formats: ["json", "csv", "xml"],
      expiry_hours: 48,
      max_file_size_mb: 100,
      max_download_count: 5
    })
  end

  def get_data_category(field) do
    data_categories()
    |> Enum.filter(fn {_category, fields} -> field in fields end)
    |> Enum.map(fn {category, _fields} -> category end)
  end

  def retention_periods do
    %{
      "authentication_data" => 0, # Immediate
      "financial_data" => 7 * 365,
      "core_identity" => 90,
      "activity_data" => 365,
      "communication_data" => 365,
      "behavioral_data" => 365,
      "derived_data" => 365,
      "tax_records" => 7 * 365,
      "security_logs" => 365,
      "audit_trail" => 365,
      "data_exports" => 7
    }
  end

  def data_categories do
    %{
      "core_identity" => ["email", "first_name", "last_name", "phone_number", "address"],
      "personal_data" => ["date_of_birth", "gender", "nationality"],
      "financial_data" => ["bank_account", "credit_card", "transaction_history"],
      "technical_data" => ["ip_address", "device_id", "browser_fingerprint"],
      "authentication_data" => ["password_hash", "hashed_password", "login_history", "2fa_secret"],
      "activity_data" => ["page_views", "clicks", "search_history"],
      "communication_data" => ["emails", "chat_logs", "support_tickets"],
      "behavioral_data" => ["preferences", "interests", "usage_patterns"],
      "derived_data" => ["risk_score", "customer_segment"]
    }
  end

  def legal_bases do
    [
      %{
        code: "consent",
        name: "Consent",
        description: "User has given clear consent for processing",
        valid_for: [:marketing, :analytics, :communication]
      },
      %{
        code: "contract",
        name: "Contract",
        description: "Processing is necessary for a contract",
        valid_for: [:essential, :billing, :service_delivery]
      },
      %{
        code: "legal_obligation",
        name: "Legal Obligation",
        description: "Processing is necessary for compliance with a legal obligation",
        valid_for: [:tax, :compliance, :audit]
      },
      %{
        code: "legitimate_interest",
        name: "Legitimate Interest",
        description: "Processing is necessary for legitimate interests",
        valid_for: [:security, :fraud_prevention, :improvement]
      }
    ]
  end

  def get_retention_period(category) do
    Map.get(retention_periods(), category, 90) # Default 90 days
  end

  def valid_legal_basis?(basis, category) do
    legal_bases()
    |> Enum.find(fn %{code: code} -> code == basis end)
    |> case do
      nil -> false
      %{valid_for: valid_categories} -> 
        # Convert category to atom if it's a string for comparison
        category_atom = if is_binary(category), do: String.to_atom(category), else: category
        category_atom in valid_categories
    end
  end
end
