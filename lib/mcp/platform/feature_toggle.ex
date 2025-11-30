defmodule Mcp.Platform.FeatureToggle do
  @moduledoc """
  Feature toggle definitions and management.
  """

  alias Mcp.Platform.TenantSettingsManager

  @doc """
  Gets all feature definitions.
  """
  def feature_definitions do
    # Common feature definitions
    %{
      "analytics" => %{
        name: "Analytics",
        description: "Enable analytics and reporting",
        default_enabled: false,
        configurable: true
      },
      "oauth" => %{
        name: "OAuth Authentication",
        description: "Enable OAuth login providers",
        default_enabled: true,
        configurable: true
      },
      "totp" => %{
        name: "TOTP 2FA",
        description: "Enable Time-based One-Time Password authentication",
        default_enabled: false,
        configurable: true
      },
      "self_registration" => %{
        name: "Self Registration",
        description: "Allow users to register themselves",
        default_enabled: false,
        configurable: true
      },
      "tenant_branding" => %{
        name: "Tenant Branding",
        description: "Allow tenants to customize branding",
        default_enabled: true,
        configurable: true
      }
    }
  end

  @doc """
  Gets a specific feature definition.
  """
  def get_feature_definition(feature_name) do
    feature_definitions()
    |> Map.get(feature_name)
  end

  @doc """
  Checks if a feature is enabled for a tenant.
  """
  def feature_enabled?(tenant_id, feature_name) do
    # Checks with TenantSettingsManager
    case TenantSettingsManager.get_enabled_features(tenant_id) do
      {:ok, features} -> feature_name in features
      {:error, _} -> false
    end
  end
  @doc """
  Gets enabled features for a tenant.
  """
  def enabled_features(tenant_id) do
    TenantSettingsManager.get_enabled_features(tenant_id)
  end

  @doc """
  Gets info for a feature.
  """
  def get_feature_info(feature_name) do
    get_feature_definition(to_string(feature_name))
  end

  @doc """
  Disables a feature.
  """
  def disable_feature(feature) do
    # Mock disable
    {:ok, %{feature | enabled: false}}
  end

  @doc """
  Enables a feature.
  """
  def enable_feature(feature) do
    # Mock enable
    {:ok, %{feature | enabled: true}}
  end

  @doc """
  Checks if a feature is enabled.
  """
  def is_enabled(tenant_id, feature_name) do
    if feature_enabled?(tenant_id, feature_name) do
      {:ok, %{name: feature_name, enabled: true}}
    else
      {:error, :not_enabled}
    end
  end
end
