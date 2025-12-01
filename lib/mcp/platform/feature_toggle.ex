defmodule Mcp.Platform.FeatureToggle do
  @moduledoc """
  Feature toggle definitions and management.
  """

  alias Mcp.Platform.TenantSettings

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
      },
      "customer_portal" => %{
        name: "Customer Portal",
        description: "Allow customers to access their own portal",
        default_enabled: false,
        configurable: true,
        default_config: %{},
        default_restrictions: %{}
      },
      "billing_management" => %{
        name: "Billing Management",
        description: "Manage billing and invoices",
        default_enabled: false,
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
    case TenantSettings.get_setting(tenant_id, :feature, to_string(feature_name)) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Gets enabled features for a tenant.
  """
  def enabled_features(tenant_id) do
    case TenantSettings.by_category(tenant_id, :feature) do
      {:ok, settings} ->
        features =
          Enum.map(settings, fn setting ->
            %{
              feature: String.to_existing_atom(setting.key),
              enabled: true,
              configuration: setting.value
            }
          end)

        {:ok, features}

      {:error, _} ->
        {:ok, []}
    end
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
  def disable_feature(feature_map) do
    # feature_map can be the map returned by enable_feature or is_enabled
    # It should have tenant_id and feature (atom)
    tenant_id = feature_map.tenant_id || feature_map[:tenant_id]
    feature_name = feature_map.feature || feature_map[:feature]

    case TenantSettings.get_setting(tenant_id, :feature, to_string(feature_name)) do
      {:ok, setting} ->
        case TenantSettings.destroy_setting(setting) do
          :ok -> {:ok, Map.put(feature_map, :enabled, false)}
          {:error, error} -> {:error, error}
        end

      {:error, _} ->
        {:ok, Map.put(feature_map, :enabled, false)}
    end
  end

  @doc """
  Enables a feature.
  """
  def enable_feature(params) do
    tenant_id = params[:tenant_id] || Map.get(params, :tenant_id)
    feature = params[:feature] || Map.get(params, :feature)
    config = params[:configuration] || Map.get(params, :configuration, %{})
    user_id = params[:enabled_by] || Map.get(params, :enabled_by)

    attrs = %{
      tenant_id: tenant_id,
      category: :feature,
      key: to_string(feature),
      value: config,
      value_type: :map,
      last_updated_by: user_id
    }

    # Use create_setting to enforce uniqueness as expected by test
    # Or upsert if we want to allow updating config
    # The test expects failure on duplicate, so use create_setting
    case TenantSettings.create_setting(attrs) do
      {:ok, setting} ->
        {:ok,
         %{
           tenant_id: setting.tenant_id,
           feature: String.to_existing_atom(setting.key),
           enabled: true,
           configuration: setting.value
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Checks if a feature is enabled.
  """
  def is_enabled(tenant_id, feature_name) do
    case TenantSettings.get_setting(tenant_id, :feature, to_string(feature_name)) do
      {:ok, setting} ->
        {:ok,
         %{
           tenant_id: tenant_id,
           feature: feature_name,
           enabled: true,
           configuration: setting.value
         }}

      {:error, _} ->
        {:error, :not_enabled}
    end
  end
end
