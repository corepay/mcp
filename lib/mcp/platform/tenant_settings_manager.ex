defmodule Mcp.Platform.TenantSettingsManager do
  @moduledoc """
  Tenant settings management backed by Mcp.Platform.Tenant resource.
  """

  alias Mcp.Platform.Tenant

  @doc """
  Gets all settings for a tenant.
  """
  def get_all_tenant_settings(tenant_id) do
    case Tenant.get_by_id(tenant_id) do
      {:ok, tenant} ->
        {:ok,
         %{
           tenant_id: tenant.id,
           features: get_features_from_settings(tenant.settings),
           branding: tenant.branding,
           settings: tenant.settings
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets enabled features for a tenant.
  """
  def get_enabled_features(tenant_id) do
    case Tenant.get_by_id(tenant_id) do
      {:ok, tenant} ->
        {:ok, get_features_from_settings(tenant.settings)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets tenant branding settings.
  """
  def get_tenant_branding(tenant_id) do
    case Tenant.get_by_id(tenant_id) do
      {:ok, tenant} ->
        {:ok, tenant.branding || %{}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Enables a feature for a tenant.
  """
  def enable_feature(tenant_id, feature, config \\ %{}, _context \\ nil) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      current_settings = tenant.settings || %{}
      features = Map.get(current_settings, "features", [])

      if feature in features do
        {:ok, %{tenant_id: tenant_id, feature: feature, enabled: true, config: config}}
      else
        new_features = [feature | features]
        new_settings = Map.put(current_settings, "features", new_features)
        # Store config in settings if needed, e.g. under "feature_configs"
        feature_configs = Map.get(current_settings, "feature_configs", %{})
        new_feature_configs = Map.put(feature_configs, feature, config)
        new_settings = Map.put(new_settings, "feature_configs", new_feature_configs)

        case Tenant.update(tenant, %{settings: new_settings}) do
          {:ok, _updated_tenant} ->
            {:ok, %{tenant_id: tenant_id, feature: feature, enabled: true, config: config}}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  @doc """
  Disables a feature for a tenant.
  """
  def disable_feature(tenant_id, feature, _context \\ nil) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      current_settings = tenant.settings || %{}
      features = Map.get(current_settings, "features", [])

      if feature in features do
        new_features = List.delete(features, feature)
        new_settings = Map.put(current_settings, "features", new_features)

        case Tenant.update(tenant, %{settings: new_settings}) do
          {:ok, _updated_tenant} ->
            {:ok, %{tenant_id: tenant_id, feature: feature, enabled: false}}

          {:error, error} ->
            {:error, error}
        end
      else
        {:ok, %{tenant_id: tenant_id, feature: feature, enabled: false}}
      end
    end
  end

  @doc """
  Updates tenant branding.
  """
  def update_tenant_branding(tenant_id, branding_map, _context \\ nil) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      case Tenant.update(tenant, %{branding: branding_map}) do
        {:ok, updated_tenant} ->
          {:ok, %{tenant_id: tenant_id, branding: updated_tenant.branding}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  @doc """
  Exports tenant settings.
  """
  def export_tenant_settings(tenant_id) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      {:ok,
       %{
         tenant_id: tenant.id,
         settings: tenant.settings,
         branding: tenant.branding,
         exported_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Imports tenant settings.
  """
  def import_tenant_settings(tenant_id, settings_data, _context \\ nil) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      updates = %{}

      updates =
        if settings_data["settings"],
          do: Map.put(updates, :settings, settings_data["settings"]),
          else: updates

      updates =
        if settings_data["branding"],
          do: Map.put(updates, :branding, settings_data["branding"]),
          else: updates

      case Tenant.update(tenant, updates) do
        {:ok, _} -> {:ok, %{tenant_id: tenant_id, imported: true}}
        {:error, error} -> {:error, error}
      end
    end
  end

  @doc """
  Checks if a feature is enabled for a tenant.
  """
  def feature_enabled?(tenant_id, feature) do
    case get_enabled_features(tenant_id) do
      {:ok, features} -> feature in features
      _ -> false
    end
  end

  @doc """
  Gets category-specific settings for a tenant.
  """
  def get_category_settings(tenant_id, category) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      settings = tenant.settings || %{}
      category_settings = Map.get(settings, category, %{})
      {:ok, %{tenant_id: tenant_id, category: category, settings: category_settings}}
    end
  end

  @doc """
  Updates category-specific settings for a tenant.
  """
  def update_category_settings(tenant_id, category, settings, user_id) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      current_settings = tenant.settings || %{}
      new_settings = Map.put(current_settings, category, settings)

      case Tenant.update(tenant, %{settings: new_settings}) do
        {:ok, _} ->
          {:ok,
           %{tenant_id: tenant_id, category: category, settings: settings, updated_by: user_id}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  @doc """
  Gets tenant configuration summary.
  """
  def get_tenant_config_summary(tenant_id) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id) do
      {:ok,
       %{
         summary: %{
           plan: tenant.plan,
           status: tenant.status,
           feature_count: length(get_features_from_settings(tenant.settings)),
           has_branding: map_size(tenant.branding || %{}) > 0
         }
       }}
    end
  end

  defp get_features_from_settings(settings) do
    Map.get(settings || %{}, "features", [])
  end
end
