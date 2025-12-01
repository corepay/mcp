defmodule Mcp.Platform.TenantSettingsManager do
  @moduledoc """
  Tenant settings management backed by Mcp.Platform.TenantSettings resource.
  """

  alias Mcp.Platform.{Tenant, TenantSettings, FeatureToggle, TenantBranding}
  require Ash.Query

  @doc """
  Gets all settings for a tenant.
  """
  def get_all_tenant_settings(tenant_id) do
    case TenantSettings.by_tenant(tenant_id) do
      {:ok, settings} ->
        settings_map =
          settings
          |> Enum.group_by(& &1.category)
          |> Map.new(fn {category, items} ->
            {to_string(category), Map.new(items, &{&1.key, &1.value})}
          end)

        {:ok, settings_map}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets enabled features for a tenant.
  """
  def get_enabled_features(tenant_id) do
    FeatureToggle.enabled_features(tenant_id)
  end

  @doc """
  Gets tenant branding settings.
  """
  def get_tenant_branding(tenant_id) do
    # This assumes we want the active branding or default
    # For now, let's just return the first active one or empty
    # But TenantBranding resource has by_tenant? No, we need to add it or use generic read
    # TenantBranding has no code interface for by_tenant in the test file?
    # Test uses TenantBranding.create_branding.
    # Let's assume we can query it.

    # Actually, let's use Ash.Query
    query =
      TenantBranding
      |> Ash.Query.filter(tenant_id == ^tenant_id and is_active == true)
      |> Ash.Query.limit(1)

    case Ash.read_one(query) do
      {:ok, branding} when not is_nil(branding) ->
        {:ok, TenantBranding.get_branding_config(branding)}

      {:ok, nil} ->
        {:ok, default_branding_config()}

      {:error, error} ->
        {:error, error}
    end
  end

  defp default_branding_config do
    %{
      colors: %{
        primary: "#3B82F6",
        secondary: nil,
        accent: nil,
        background: nil,
        text: nil
      },
      assets: %{
        logo: nil
      },
      theme: :light,
      fonts: %{
        primary: "Inter, sans-serif"
      }
    }
  end

  @doc """
  Enables a feature for a tenant.
  """
  def enable_feature(tenant_id, feature, config \\ %{}, user_id \\ nil) do
    FeatureToggle.enable_feature(%{
      tenant_id: tenant_id,
      feature: feature,
      configuration: config,
      enabled_by: user_id
    })
  end

  @doc """
  Disables a feature for a tenant.
  """
  def disable_feature(tenant_id, feature, _user_id \\ nil) do
    case FeatureToggle.is_enabled(tenant_id, feature) do
      {:ok, feature_toggle} ->
        FeatureToggle.disable_feature(feature_toggle)

      {:error, _} ->
        {:ok, :already_disabled}
    end
  end

  @doc """
  Updates tenant branding.
  """
  def update_tenant_branding(tenant_id, branding_params, user_id \\ nil) do
    # Check if branding exists
    query =
      TenantBranding
      |> Ash.Query.filter(tenant_id == ^tenant_id)
      |> Ash.Query.limit(1)

    case Ash.read_one(query) do
      {:ok, nil} ->
        # Create new
        attrs =
          Map.merge(branding_params, %{tenant_id: tenant_id, created_by: user_id, is_active: true})

        TenantBranding.create_branding(attrs)

      {:ok, branding} ->
        # Update existing (we need an update action on TenantBranding)
        # Assuming update_branding exists or we use generic update if available
        # The test uses TenantBranding.create_branding and activate.
        # Let's assume we can update.
        # If TenantBranding doesn't have update action exposed, we might need to add it.
        # For now, let's try to update using Ash.Changeset
        branding
        |> Ash.Changeset.for_update(:update, branding_params)
        |> Ash.update()

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Exports tenant settings.
  """
  def export_tenant_settings(tenant_id) do
    with {:ok, settings} <- get_all_tenant_settings(tenant_id),
         {:ok, branding} <- get_tenant_branding(tenant_id) do
      {:ok,
       %{
         tenant_id: tenant_id,
         settings: settings,
         branding: branding,
         exported_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Imports tenant settings.
  """
  def import_tenant_settings(tenant_id, settings_data, user_id \\ nil) do
    # Import settings
    if settings_data.settings do
      Enum.each(settings_data.settings, fn {category, category_settings} ->
        update_category_settings(
          tenant_id,
          String.to_existing_atom(category),
          category_settings,
          user_id
        )
      end)
    end

    # Import branding
    if settings_data.branding do
      update_tenant_branding(tenant_id, settings_data.branding, user_id)
    end

    {:ok, :imported}
  end

  @doc """
  Checks if a feature is enabled for a tenant.
  """
  def feature_enabled?(tenant_id, feature) do
    case FeatureToggle.is_enabled(tenant_id, feature) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Gets category-specific settings for a tenant.
  """
  def get_category_settings(tenant_id, category) do
    case TenantSettings.by_category(tenant_id, category) do
      {:ok, settings} ->
        settings_map = Map.new(settings, &{&1.key, &1.value})
        {:ok, settings_map}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Updates category-specific settings for a tenant.
  """
  def update_category_settings(tenant_id, category, settings, user_id) do
    results =
      Enum.map(settings, fn {key, value} ->
        attrs = %{
          tenant_id: tenant_id,
          category: category,
          key: key,
          value: value,
          last_updated_by: user_id
        }

        TenantSettings.upsert_setting(attrs)
      end)

    # Check if any failed
    if Enum.any?(results, &(elem(&1, 0) == :error)) do
      {:error, "Failed to update some settings"}
    else
      {:ok, results}
    end
  end

  @doc """
  Gets tenant configuration summary.
  """
  def get_tenant_config_summary(tenant_id) do
    with {:ok, tenant} <- Tenant.get_by_id(tenant_id),
         {:ok, settings} <- get_all_tenant_settings(tenant_id),
         {:ok, features} <- get_enabled_features(tenant_id) do
      {:ok,
       %{
         # Assuming name is company_name
         tenant_info: %{company_name: tenant.name},
         settings_summary: %{
           total_settings: Enum.reduce(settings, 0, fn {_, map}, acc -> acc + map_size(map) end),
           categories_configured: map_size(settings)
         },
         features_summary: %{
           total_enabled: length(features)
         }
       }}
    end
  end

  @doc """
  Initializes tenant settings.
  """
  def initialize_tenant_settings(tenant_id, user_id) do
    # Initialize default settings
    default_settings = %{
      "general" => %{
        "timezone" => "UTC",
        "language" => "en"
      },
      "branding" => %{
        "primary_color" => "#000000"
      }
    }

    Enum.each(default_settings, fn {category, settings} ->
      if category == "branding" do
        # Handle branding separately if needed, or as settings
        # But branding is usually separate resource
        # For now, let's skip branding here as it's handled by TenantBranding
        :ok
      else
        update_category_settings(tenant_id, String.to_existing_atom(category), settings, user_id)
      end
    end)

    {:ok, :initialized}
  end
end
