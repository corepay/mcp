defmodule Mcp.Platform.TenantSettingsTest do
  use Mcp.DataCase

  alias Mcp.Platform.{FeatureToggle, TenantBranding, TenantSettings, TenantSettingsManager}

  describe "TenantSettings resource" do
    test "creates a setting with valid attributes" do
      tenant = tenant_fixture()
      user = user_fixture()

      attrs = %{
        tenant_id: tenant.id,
        category: :general,
        key: "timezone",
        value: "America/New_York",
        value_type: :string,
        description: "Default timezone",
        last_updated_by: user.id
      }

      assert {:ok, setting} = TenantSettings.create_setting(attrs)
      assert setting.tenant_id == tenant.id
      assert setting.category == :general
      assert setting.key == "timezone"
      assert setting.value == "America/New_York"
      assert setting.value_type == :string
    end

    test "validates required fields" do
      attrs = %{}
      assert {:error, changeset} = TenantSettings.create_setting(attrs)
      assert %{tenant_id: ["can't be blank"]} = errors_on(changeset)
      assert %{category: ["can't be blank"]} = errors_on(changeset)
      assert %{key: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique tenant setting constraint" do
      tenant = tenant_fixture()
      user = user_fixture()

      attrs = %{
        tenant_id: tenant.id,
        category: :general,
        key: "timezone",
        value: "UTC",
        last_updated_by: user.id
      }

      assert {:ok, _setting1} = TenantSettings.create_setting(attrs)
      assert {:error, changeset} = TenantSettings.create_setting(attrs)
      assert %{tenant_category_key: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates category values" do
      tenant = tenant_fixture()
      user = user_fixture()

      attrs = %{
        tenant_id: tenant.id,
        category: :invalid_category,
        key: "test",
        value: "test",
        last_updated_by: user.id
      }

      assert {:error, changeset} = TenantSettings.create_setting(attrs)
      assert %{category: ["is invalid"]} = errors_on(changeset)
    end

    test "gets setting by tenant and category" do
      tenant = tenant_fixture()
      _user = user_fixture()

      # Create settings in different categories
      _general_setting = setting_fixture(tenant, :general, "timezone", "UTC")
      _billing_setting = setting_fixture(tenant, :billing, "currency", "USD")

      # Test getting all settings for tenant
      {:ok, all_settings} = TenantSettings.by_tenant(tenant.id)
      assert length(all_settings) == 2

      # Test getting settings by category
      {:ok, general_settings} = TenantSettings.by_category(tenant.id, :general)
      assert length(general_settings) == 1
      assert hd(general_settings).key == "timezone"

      {:ok, billing_settings} = TenantSettings.by_category(tenant.id, :billing)
      assert length(billing_settings) == 1
      assert hd(billing_settings).key == "currency"

      # Test getting specific setting
      {:ok, found_setting} = TenantSettings.get_setting(tenant.id, :general, "timezone")
      assert found_setting.value == "UTC"
    end

    test "updates setting value" do
      tenant = tenant_fixture()
      user = user_fixture()
      setting = setting_fixture(tenant, :general, "timezone", "UTC")

      assert {:ok, updated_setting} =
               TenantSettings.update_setting(setting, %{
                 value: "America/New_York",
                 last_updated_by: user.id
               })

      assert updated_setting.value == "America/New_York"
    end

    test "deletes setting" do
      tenant = tenant_fixture()
      _user = user_fixture()
      setting = setting_fixture(tenant, :general, "timezone", "UTC")

      assert {:ok, _deleted_setting} = TenantSettings.destroy_setting(setting)

      assert {:error, :not_found} = TenantSettings.get_setting(tenant.id, :general, "timezone")
    end
  end

  describe "TenantSettingsManager" do
    test "gets all tenant settings organized by category" do
      tenant = tenant_fixture()
      _user = user_fixture()

      # Create settings in multiple categories
      setting_fixture(tenant, :general, "timezone", "UTC")
      setting_fixture(tenant, :general, "language", "en")
      setting_fixture(tenant, :billing, "currency", "USD")
      setting_fixture(tenant, :business_info, "company_name", "Test ISP")

      {:ok, all_settings} = TenantSettingsManager.get_all_tenant_settings(tenant.id)

      assert %{
               "general" => %{"timezone" => "UTC", "language" => "en"},
               "billing" => %{"currency" => "USD"},
               "business_info" => %{"company_name" => "Test ISP"}
             } = all_settings
    end

    test "updates category settings" do
      tenant = tenant_fixture()
      user = user_fixture()

      settings_map = %{
        "timezone" => "America/New_York",
        "language" => "en",
        "date_format" => "%m/%d/%Y"
      }

      assert {:ok, _results} =
               TenantSettingsManager.update_category_settings(
                 tenant.id,
                 :general,
                 settings_map,
                 user.id
               )

      # Verify all settings were created/updated
      {:ok, general_settings} = TenantSettingsManager.get_category_settings(tenant.id, :general)
      assert general_settings["timezone"] == "America/New_York"
      assert general_settings["language"] == "en"
      assert general_settings["date_format"] == "%m/%d/%Y"
    end

    test "initializes default settings for new tenant" do
      tenant = tenant_fixture()
      user = user_fixture()

      assert {:ok, :initialized} =
               TenantSettingsManager.initialize_tenant_settings(tenant.id, user.id)

      # Verify default settings were created
      {:ok, all_settings} = TenantSettingsManager.get_all_tenant_settings(tenant.id)
      assert map_size(all_settings) > 0

      # Check specific default settings exist
      {:ok, general_settings} = TenantSettingsManager.get_category_settings(tenant.id, :general)
      assert general_settings["timezone"] == "UTC"
      assert general_settings["language"] == "en"
    end

    test "exports and imports tenant settings" do
      source_tenant = tenant_fixture()
      target_tenant = tenant_fixture()
      user = user_fixture()

      # Create some settings in source tenant
      setting_fixture(source_tenant, :general, "timezone", "America/New_York")
      setting_fixture(source_tenant, :billing, "currency", "USD")

      # Export settings
      assert {:ok, export_data} = TenantSettingsManager.export_tenant_settings(source_tenant.id)
      assert export_data.tenant_id == source_tenant.id
      assert map_size(export_data.settings) > 0

      # Import to target tenant
      assert {:ok, :imported} =
               TenantSettingsManager.import_tenant_settings(
                 target_tenant.id,
                 export_data,
                 user.id
               )

      # Verify settings were imported
      {:ok, imported_settings} = TenantSettingsManager.get_all_tenant_settings(target_tenant.id)
      assert imported_settings["general"]["timezone"] == "America/New_York"
      assert imported_settings["billing"]["currency"] == "USD"
    end
  end

  describe "FeatureToggle resource" do
    test "creates and manages feature toggles" do
      tenant = tenant_fixture()
      user = user_fixture()

      # Enable a feature
      assert {:ok, feature} =
               FeatureToggle.enable_feature(%{
                 tenant_id: tenant.id,
                 feature: :customer_portal,
                 configuration: %{"max_customers" => 1000},
                 enabled_by: user.id
               })

      assert feature.enabled == true
      assert feature.feature == :customer_portal
      assert feature.configuration["max_customers"] == 1000

      # Check if feature is enabled
      assert {:ok, found_feature} = FeatureToggle.is_enabled(tenant.id, :customer_portal)
      assert found_feature.enabled == true

      # Disable feature
      assert {:ok, disabled_feature} = FeatureToggle.disable_feature(found_feature)
      assert disabled_feature.enabled == false
    end

    test "gets enabled features for tenant" do
      tenant = tenant_fixture()
      user = user_fixture()

      # Enable multiple features
      FeatureToggle.enable_feature(%{
        tenant_id: tenant.id,
        feature: :customer_portal,
        enabled_by: user.id
      })

      FeatureToggle.enable_feature(%{
        tenant_id: tenant.id,
        feature: :billing_management,
        configuration: %{"auto_invoicing" => true},
        enabled_by: user.id
      })

      {:ok, enabled_features} = FeatureToggle.enabled_features(tenant.id)
      assert length(enabled_features) == 2
      assert Enum.any?(enabled_features, &(&1.feature == :customer_portal))
      assert Enum.any?(enabled_features, &(&1.feature == :billing_management))
    end

    test "enforces unique tenant feature constraint" do
      tenant = tenant_fixture()
      user = user_fixture()

      attrs = %{
        tenant_id: tenant.id,
        feature: :customer_portal,
        enabled_by: user.id
      }

      assert {:ok, _feature1} = FeatureToggle.enable_feature(attrs)
      assert {:error, changeset} = FeatureToggle.enable_feature(attrs)
      assert %{tenant_feature: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "TenantSettingsManager features" do
    test "manages feature toggles through manager" do
      tenant = tenant_fixture()
      user = user_fixture()

      # Enable feature through manager
      assert {:ok, _feature} =
               TenantSettingsManager.enable_feature(
                 tenant.id,
                 :customer_portal,
                 %{"max_customers" => 500},
                 user.id
               )

      assert TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal) == true

      # Check feature configuration
      {:ok, enabled_features} = TenantSettingsManager.get_enabled_features(tenant.id)
      customer_portal_feature = Enum.find(enabled_features, &(&1.feature == :customer_portal))
      assert customer_portal_feature.configuration["max_customers"] == 500

      # Disable feature through manager
      assert {:ok, _} =
               TenantSettingsManager.disable_feature(tenant.id, :customer_portal, user.id)

      assert TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal) == false
    end

    test "gets feature definitions" do
      feature_info = FeatureToggle.get_feature_info(:customer_portal)
      assert feature_info.name == "Customer Portal"
      assert feature_info.description == "Allow customers to access their own portal"
      assert is_map(feature_info.default_config)
      assert is_map(feature_info.default_restrictions)
    end
  end

  describe "TenantBranding resource" do
    test "creates and manages branding" do
      tenant = tenant_fixture()
      user = user_fixture()

      attrs = %{
        tenant_id: tenant.id,
        name: "Default Theme",
        primary_color: "#3B82F6",
        secondary_color: "#6B7280",
        theme: :light,
        created_by: user.id
      }

      assert {:ok, branding} = TenantBranding.create_branding(attrs)
      assert branding.name == "Default Theme"
      assert branding.primary_color == "#3B82F6"
      assert branding.theme == :light
      # First branding is auto-activated
      assert branding.is_active == true
    end

    test "manages active branding" do
      tenant = tenant_fixture()
      user = user_fixture()

      # Create first branding (auto-activated)
      first_branding = branding_fixture(tenant, user, "Theme 1")
      assert first_branding.is_active == true

      # Create second branding
      second_branding = branding_fixture(tenant, user, "Theme 2", false)
      assert second_branding.is_active == false

      # Activate second branding
      {:ok, activated_branding} = TenantBranding.activate(second_branding)
      assert activated_branding.is_active == true

      # First branding should be deactivated
      {:ok, first_branding_updated} = TenantBranding.by_id(first_branding.id)
      assert first_branding_updated.is_active == false
    end

    test "generates branding configuration" do
      tenant = tenant_fixture()
      user = user_fixture()

      branding =
        branding_fixture(tenant, user, "Test Branding", true, %{
          primary_color: "#FF6B6B",
          secondary_color: "#4ECDC4",
          logo_url: "https://example.com/logo.png"
        })

      config = TenantBranding.get_branding_config(branding)
      assert config.colors.primary == "#FF6B6B"
      assert config.colors.secondary == "#4ECDC4"
      assert config.assets.logo == "https://example.com/logo.png"
      assert config.theme == :light
    end

    test "generates CSS variables" do
      tenant = tenant_fixture()
      user = user_fixture()

      branding =
        branding_fixture(tenant, user, "CSS Test", true, %{
          primary_color: "#FF6B6B",
          secondary_color: "#4ECDC4",
          background_color: "#FFFFFF",
          text_color: "#333333",
          font_family: "Roboto, sans-serif"
        })

      css_vars = TenantBranding.generate_css_variables(branding)
      assert css_vars =~ "--primary-color: #FF6B6B"
      assert css_vars =~ "--secondary-color: #4ECDC4"
      assert css_vars =~ "--background-color: #FFFFFF"
      assert css_vars =~ "--text-color: #333333"
      assert css_vars =~ "--font-family: Roboto, sans-serif"
    end
  end

  describe "TenantSettingsManager branding" do
    test "manages branding through manager" do
      tenant = tenant_fixture()
      user = user_fixture()

      branding_params = %{
        name: "Manager Theme",
        primary_color: "#10B981",
        theme: :dark,
        font_family: "Inter, sans-serif"
      }

      assert {:ok, _branding} =
               TenantSettingsManager.update_tenant_branding(
                 tenant.id,
                 branding_params,
                 user.id
               )

      {:ok, retrieved_branding} = TenantSettingsManager.get_tenant_branding(tenant.id)
      assert retrieved_branding.colors.primary == "#10B981"
      assert retrieved_branding.theme == :dark
      assert retrieved_branding.fonts.primary == "Inter, sans-serif"
    end

    test "returns default branding for new tenant" do
      tenant = tenant_fixture()

      {:ok, default_branding} = TenantSettingsManager.get_tenant_branding(tenant.id)
      assert default_branding.colors.primary == "#3B82F6"
      assert default_branding.theme == :light
      assert default_branding.fonts.primary == "Inter, sans-serif"
    end

    test "gets tenant configuration summary" do
      tenant = tenant_fixture()
      user = user_fixture()

      # Setup some configuration
      TenantSettingsManager.initialize_tenant_settings(tenant.id, user.id)
      TenantSettingsManager.enable_feature(tenant.id, :customer_portal, %{}, user.id)

      {:ok, summary} = TenantSettingsManager.get_tenant_config_summary(tenant.id)

      assert summary.tenant_info.company_name == tenant.company_name
      assert summary.settings_summary.total_settings > 0
      assert summary.features_summary.total_enabled > 0
      assert is_integer(summary.settings_summary.categories_configured)
    end
  end

  describe "Settings validation and encryption" do
    test "validates setting values based on type" do
      tenant = tenant_fixture()
      user = user_fixture()

      # Test string validation with min/max length
      attrs = %{
        tenant_id: tenant.id,
        category: :general,
        key: "company_name",
        value: "A",
        value_type: :string,
        validation_rules: %{"min_length" => 2, "max_length" => 100},
        last_updated_by: user.id
      }

      assert {:error, changeset} = TenantSettings.create_setting(attrs)
      assert {:value, ["String must be at least 2 characters"]} in errors_on(changeset)

      # Test number validation with min/max value
      attrs = %{
        tenant_id: tenant.id,
        category: :billing,
        key: "max_customers",
        value: 5000,
        value_type: :integer,
        validation_rules: %{"min_value" => 100, "max_value" => 1000},
        last_updated_by: user.id
      }

      assert {:error, changeset} = TenantSettings.create_setting(attrs)
      assert {:value, ["Value must be at most 1000"]} in errors_on(changeset)
    end

    test "handles encrypted settings" do
      tenant = tenant_fixture()
      user = user_fixture()

      attrs = %{
        tenant_id: tenant.id,
        category: :business_info,
        key: "tax_id",
        value: "12-3456789",
        value_type: :string,
        encrypted: true,
        last_updated_by: user.id
      }

      assert {:ok, setting} = TenantSettings.create_setting(attrs)
      assert setting.encrypted == true
      # The value should be encrypted/transformed
      assert is_binary(setting.value)
    end

    test "handles different value types" do
      tenant = tenant_fixture()
      user = user_fixture()

      test_cases = [
        {"string_setting", "test_value", :string},
        {"integer_setting", 42, :integer},
        {"float_setting", 3.14, :float},
        {"boolean_setting", true, :boolean},
        {"map_setting", %{"key" => "value"}, :map},
        {"array_setting", ["item1", "item2"], :array}
      ]

      Enum.each(test_cases, fn {key, value, type} ->
        attrs = %{
          tenant_id: tenant.id,
          category: :general,
          key: key,
          value: value,
          value_type: type,
          last_updated_by: user.id
        }

        assert {:ok, setting} = TenantSettings.create_setting(attrs)
        assert setting.value_type == type
        assert setting.value == value
      end)
    end
  end

  # Helper functions for fixtures

  defp tenant_fixture do
    %Mcp.Platform.Tenant{}
    |> Ecto.Changeset.change(%{
      company_name: "Test ISP",
      company_schema: "test_isp",
      subdomain: "testisp",
      slug: "testisp",
      plan: :starter,
      status: :active
    })
    |> Mcp.Repo.insert!()
  end

  defp user_fixture do
    %Mcp.Accounts.User{}
    |> Ecto.Changeset.change(%{
      email: "test@example.com",
      first_name: "Test",
      last_name: "User",
      status: :active
    })
    |> Mcp.Repo.insert!()
  end

  defp setting_fixture(tenant, category, key, value) do
    %Mcp.Platform.TenantSettings{}
    |> Ecto.Changeset.change(%{
      tenant_id: tenant.id,
      category: category,
      key: key,
      value: value,
      value_type: :string
    })
    |> Mcp.Repo.insert!()
  end

  defp branding_fixture(tenant, user, name, is_active \\ true, additional_attrs \\ %{}) do
    base_attrs = %{
      tenant_id: tenant.id,
      name: name,
      primary_color: "#3B82F6",
      secondary_color: "#6B7280",
      theme: :light,
      created_by: user.id
    }

    attrs = Map.merge(base_attrs, additional_attrs)

    %Mcp.Platform.TenantBranding{}
    |> Ecto.Changeset.change(attrs)
    |> Ecto.Changeset.change(is_active: is_active)
    |> Mcp.Repo.insert!()
  end
end
