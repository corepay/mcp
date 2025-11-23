defmodule McpWeb.TenantSettingsControllerTest do
  use McpWeb.ConnCase

  import Mcp.AccountsFixtures
  import Mcp.TenantFixtures

  alias Mcp.Platform.{TenantSettingsManager, FeatureToggle}

  @moduletag :capture_log

  describe "index" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "lists all settings categories", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings")
      assert html_response(conn, 200) =~ "Tenant Settings"
    end

    test "redirects non-admin users", %{conn: conn} do
      non_admin_conn = login_user(conn)
      conn = get(non_admin_conn, ~p"/#{conn.assigns.tenant_schema}/settings")
      assert html_response(conn, 403)
    end
  end

  describe "show_category" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "shows specific category settings", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/general")
      assert html_response(conn, 200) =~ "General Settings"
    end

    test "handles invalid category", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/invalid")
      assert redirected_to(conn) == ~p"/#{conn.assigns.tenant_schema}/settings"
      assert get_flash(conn, :error) == "Invalid category"
    end
  end

  describe "edit_category" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "shows edit form for category", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/general/edit")
      assert html_response(conn, 200) =~ "General Settings"
      assert html_response(conn, 200) =~ "form"
    end
  end

  describe "update_category" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "updates category settings with valid data", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      settings_params = %{
        "timezone" => "America/New_York",
        "language" => "en"
      }

      conn =
        put(conn, ~p"/#{tenant.company_schema}/settings/general", %{"settings" => settings_params})

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/general"
      assert get_flash(conn, :info) == "General settings updated successfully"

      # Verify settings were actually updated
      {:ok, updated_settings} = TenantSettingsManager.get_category_settings(tenant.id, :general)
      assert updated_settings["timezone"] == "America/New_York"
      assert updated_settings["language"] == "en"
    end

    test "handles invalid category", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      settings_params = %{"test" => "value"}

      conn =
        put(conn, ~p"/#{tenant.company_schema}/settings/invalid", %{"settings" => settings_params})

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings"
      assert get_flash(conn, :error) == "Invalid category"
    end
  end

  describe "features" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "lists enabled features", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/features")
      assert html_response(conn, 200) =~ "Features"
      assert html_response(conn, 200) =~ "Feature Toggles"
    end

    test "shows feature definitions", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/features")
      # Should show core features like customer portal
      assert html_response(conn, 200) =~ "Customer Portal"
    end
  end

  describe "toggle_feature" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "enables a feature", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      feature = "customer_portal"

      # Ensure feature is initially disabled
      refute TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)

      conn = post(conn, ~p"/#{tenant.company_schema}/settings/features/#{feature}?action=enable")

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/features"
      assert get_flash(conn, :info) =~ "enabled successfully"

      # Verify feature was enabled
      assert TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)
    end

    test "disables a feature", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      feature = "customer_portal"

      # First enable the feature
      TenantSettingsManager.enable_feature(tenant.id, :customer_portal, %{}, nil)
      assert TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)

      # Now disable it
      conn = post(conn, ~p"/#{tenant.company_schema}/settings/features/#{feature}?action=disable")

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/features"
      assert get_flash(conn, :info) =~ "disabled successfully"

      # Verify feature was disabled
      refute TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)
    end

    test "toggles a feature", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      feature = "customer_portal"

      # Initially disabled
      refute TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)

      # Toggle to enable
      conn = post(conn, ~p"/#{tenant.company_schema}/settings/features/#{feature}?action=toggle")

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/features"
      assert TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)

      # Toggle to disable
      conn = post(conn, ~p"/#{tenant.company_schema}/settings/features/#{feature}?action=toggle")

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/features"
      refute TenantSettingsManager.feature_enabled?(tenant.id, :customer_portal)
    end

    test "handles invalid feature", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      conn = post(conn, ~p"/#{tenant.company_schema}/settings/features/invalid_feature")

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/features"
      assert get_flash(conn, :error) =~ "Failed to toggle invalid_feature"
    end
  end

  describe "branding" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "shows current branding", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/branding")
      assert html_response(conn, 200) =~ "Branding"
      assert html_response(conn, 200) =~ "Brand Configuration"
    end

    test "updates branding with valid data", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      branding_params = %{
        "name" => "Test Theme",
        "primary_color" => "#FF6B6B",
        "secondary_color" => "#4ECDC4",
        "theme" => "dark",
        "font_family" => "Inter, sans-serif"
      }

      conn =
        put(conn, ~p"/#{tenant.company_schema}/settings/branding", %{
          "branding" => branding_params
        })

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/branding"
      assert get_flash(conn, :info) == "Branding updated successfully"

      # Verify branding was updated
      {:ok, updated_branding} = TenantSettingsManager.get_tenant_branding(tenant.id)
      assert updated_branding.colors.primary == "#FF6B6B"
      assert updated_branding.colors.secondary == "#4ECDC4"
      assert updated_branding.theme == :dark
    end

    test "handles invalid color format", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      branding_params = %{
        "name" => "Test Theme",
        "primary_color" => "invalid_color"
      }

      conn =
        put(conn, ~p"/#{tenant.company_schema}/settings/branding", %{
          "branding" => branding_params
        })

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/branding"
      assert get_flash(conn, :error) =~ "Failed to update branding"
    end
  end

  describe "import_export" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "shows import/export page", %{conn: conn} do
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings/import-export")
      assert html_response(conn, 200) =~ "Import"
      assert html_response(conn, 200) =~ "Export"
    end
  end

  describe "export_settings" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "exports settings as JSON", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      user = conn.assigns.current_user

      # Create some settings to export
      TenantSettingsManager.update_category_settings(
        tenant.id,
        :general,
        %{"timezone" => "UTC", "language" => "en"},
        user.id
      )

      conn = get(conn, ~p"/#{tenant.company_schema}/settings/export")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment"

      # Verify the exported JSON contains our settings
      response_body = response(conn, 200)
      assert response_body =~ "UTC"
      assert response_body =~ "en"
    end
  end

  describe "import_settings" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "imports settings from valid JSON file", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      user = conn.assigns.current_user

      # Create test JSON content
      import_data = %{
        tenant_id: Ecto.UUID.generate(),
        exported_at: DateTime.utc_now(),
        settings: %{
          "general" => %{"timezone" => "America/New_York", "language" => "fr"}
        },
        features: [],
        branding: %{},
        version: "1.0"
      }

      json_content = Jason.encode!(import_data)

      # Create temporary file
      tmp_path = System.tmp_dir!() <> "/test_import.json"
      File.write!(tmp_path, json_content)

      upload = %Plug.Upload{
        path: tmp_path,
        filename: "test_import.json",
        content_type: "application/json"
      }

      conn = post(conn, ~p"/#{tenant.company_schema}/settings/import", %{"file" => upload})

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings"
      assert get_flash(conn, :info) == "Settings imported successfully"

      # Verify settings were imported
      {:ok, imported_settings} = TenantSettingsManager.get_category_settings(tenant.id, :general)
      assert imported_settings["timezone"] == "America/New_York"
      assert imported_settings["language"] == "fr"

      # Clean up
      File.rm!(tmp_path)
    end

    test "handles invalid JSON file", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      # Create invalid JSON
      tmp_path = System.tmp_dir!() <> "/invalid.json"
      File.write!(tmp_path, "invalid json content")

      upload = %Plug.Upload{
        path: tmp_path,
        filename: "invalid.json",
        content_type: "application/json"
      }

      conn = post(conn, ~p"/#{tenant.company_schema}/settings/import", %{"file" => upload})

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/import-export"
      assert get_flash(conn, :error) == "Invalid JSON file format"

      # Clean up
      File.rm!(tmp_path)
    end

    test "handles missing file", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      conn = post(conn, ~p"/#{tenant.company_schema}/settings/import", %{})

      assert redirected_to(conn) == ~p"/#{tenant.company_schema}/settings/import-export"
      assert get_flash(conn, :error) == "Please select a file to import"
    end
  end

  describe "dashboard" do
    setup %{conn: conn} do
      %{conn: login_tenant_admin(conn)}
    end

    test "shows configuration summary", %{conn: conn} do
      tenant = conn.assigns.current_tenant
      user = conn.assigns.current_user

      # Initialize some settings
      TenantSettingsManager.initialize_tenant_settings(tenant.id, user.id)

      conn = get(conn, ~p"/#{tenant.company_schema}/settings/dashboard")

      assert html_response(conn, 200) =~ "Configuration Summary"
      assert html_response(conn, 200) =~ "Total Settings"
      assert html_response(conn, 200) =~ "Enabled Features"
    end

    test "shows tenant information", %{conn: conn} do
      tenant = conn.assigns.current_tenant

      conn = get(conn, ~p"/#{tenant.company_schema}/settings/dashboard")

      assert html_response(conn, 200) =~ tenant.company_name
      assert html_response(conn, 200) =~ to_string(tenant.plan)
    end
  end

  describe "authentication and authorization" do
    test "redirects unauthenticated users", %{conn: conn} do
      conn = get(conn, ~p"/test_tenant/settings")
      assert redirected_to(conn) == ~p"/users/log_in"
    end

    test "redirects non-admin authenticated users", %{conn: conn} do
      conn = login_regular_user(conn)
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings")
      assert html_response(conn, 403)
    end

    test "allows tenant admin access", %{conn: conn} do
      conn = login_tenant_admin(conn)
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings")
      assert html_response(conn, 200)
    end

    test "allows platform admin access", %{conn: conn} do
      conn = login_platform_admin(conn)
      conn = get(conn, ~p"/#{conn.assigns.tenant_schema}/settings")
      assert html_response(conn, 200)
    end
  end

  # Helper functions for authentication

  defp login_user(conn) do
    user = user_fixture()
    tenant = tenant_fixture()

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> assign(:current_user, user)
    |> assign(:current_tenant, tenant)
    |> assign(:tenant_schema, tenant.company_schema)
  end

  defp login_regular_user(conn) do
    user = user_fixture(%{role: :member})
    tenant = tenant_fixture()

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> assign(:current_user, user)
    |> assign(:current_tenant, tenant)
    |> assign(:tenant_schema, tenant.company_schema)
  end

  defp login_tenant_admin(conn) do
    user = user_fixture(%{role: :admin})
    tenant = tenant_fixture()

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> assign(:current_user, user)
    |> assign(:current_tenant, tenant)
    |> assign(:tenant_schema, tenant.company_schema)
  end

  defp login_platform_admin(conn) do
    user = user_fixture(%{role: :platform_admin})
    tenant = tenant_fixture()

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> assign(:current_user, user)
    |> assign(:current_tenant, tenant)
    |> assign(:tenant_schema, tenant.company_schema)
  end

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
end
