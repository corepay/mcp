defmodule Mcp.Platform.TenantTest do
  use ExUnit.Case, async: true

  alias Mcp.Platform.Tenant
  alias Mcp.MultiTenant

  describe "tenant creation" do
    test "creates tenant with valid attributes" do
      attrs = %{
        slug: "test-tenant",
        company_name: "Test Company",
        company_schema: "test_tenant",
        subdomain: "test",
        plan: :starter,
        settings: %{"theme" => "light"},
        branding: %{"logo" => "test.png"}
      }

      assert {:ok, tenant} = Tenant.create(attrs)
      assert tenant.slug == "test-tenant"
      assert tenant.company_name == "Test Company"
      assert tenant.company_schema == "test_tenant"
      assert tenant.subdomain == "test"
      assert tenant.plan == :starter
      assert tenant.status == :active
      assert tenant.settings == %{"theme" => "light"}
      assert tenant.branding == %{"logo" => "test.png"}
    end

    test "sets trial end date for trial plan automatically" do
      attrs = %{
        slug: "trial-tenant",
        company_name: "Trial Company",
        company_schema: "trial_tenant",
        subdomain: "trial",
        plan: :trial
      }

      assert {:ok, tenant} = Tenant.create(attrs)
      assert tenant.plan == :trial
      assert not is_nil(tenant.trial_ends_at)
      assert DateTime.compare(tenant.trial_ends_at, DateTime.utc_now()) == :gt
    end

    test "rejects invalid slug format" do
      attrs = %{
        slug: "Invalid Slug!",
        company_name: "Test Company",
        company_schema: "test_tenant",
        subdomain: "test"
      }

      assert {:error, changeset} = Tenant.create(attrs)
      assert not changeset.valid?
      assert {"does not match", _} = changeset.errors[:slug]
    end

    test "rejects duplicate slug" do
      attrs = %{
        slug: "duplicate",
        company_name: "Test Company 1",
        company_schema: "test_tenant1",
        subdomain: "test1"
      }

      attrs2 = %{
        slug: "duplicate",
        company_name: "Test Company 2",
        company_schema: "test_tenant2",
        subdomain: "test2"
      }

      assert {:ok, _tenant1} = Tenant.create(attrs)
      assert {:error, changeset} = Tenant.create(attrs2)
      assert not changeset.valid?
      assert has_constraint_error?(changeset, :slug)
    end

    test "rejects invalid limits" do
      attrs = %{
        slug: "invalid-limits",
        company_name: "Test Company",
        company_schema: "invalid_limits",
        subdomain: "invalid",
        max_developers: -1,
        max_resellers: 0,
        max_merchants: -5
      }

      assert {:error, changeset} = Tenant.create(attrs)
      assert not changeset.valid?
      assert {"must be greater than", _} = changeset.errors[:max_developers]
      assert {"must be greater than", _} = changeset.errors[:max_resellers]
      assert {"must be greater than", _} = changeset.errors[:max_merchants]
    end
  end

  describe "tenant status management" do
    setup do
      {:ok, tenant} =
        Tenant.create(%{
          slug: "status-test",
          company_name: "Status Test Company",
          company_schema: "status_test",
          subdomain: "status-test"
        })

      {:ok, tenant: tenant}
    end

    test "activates tenant", %{tenant: tenant} do
      # First suspend
      {:ok, suspended} = Tenant.suspend(tenant, %{})
      assert suspended.status == :suspended

      # Then activate
      {:ok, activated} = Tenant.activate(suspended, %{})
      assert activated.status == :active
    end

    test "suspends tenant", %{tenant: tenant} do
      {:ok, suspended} = Tenant.suspend(tenant, %{})
      assert suspended.status == :suspended
    end

    test "cancels tenant", %{tenant: tenant} do
      {:ok, canceled} = Tenant.cancel(tenant, %{})
      assert canceled.status == :canceled
    end

    test "soft deletes tenant", %{tenant: tenant} do
      {:ok, deleted} = Tenant.delete(tenant, %{})
      assert deleted.status == :deleted
    end
  end

  describe "tenant plan management" do
    setup do
      {:ok, tenant} =
        Tenant.create(%{
          slug: "plan-test",
          company_name: "Plan Test Company",
          company_schema: "plan_test",
          subdomain: "plan-test",
          plan: :starter
        })

      {:ok, tenant: tenant}
    end

    test "updates tenant plan", %{tenant: tenant} do
      {:ok, updated} = Tenant.update_plan(tenant, %{plan: :professional})
      assert updated.plan == :professional
    end

    test "updates plan with trial end date", %{tenant: tenant} do
      trial_ends = DateTime.add(DateTime.utc_now(), 30, :day)

      {:ok, updated} =
        Tenant.update_plan(tenant, %{
          plan: :trial,
          trial_ends_at: trial_ends
        })

      assert updated.plan == :trial
      assert DateTime.compare(updated.trial_ends_at, trial_ends) == :eq
    end
  end

  describe "tenant onboarding" do
    setup do
      {:ok, tenant} =
        Tenant.create(%{
          slug: "onboarding-test",
          company_name: "Onboarding Test Company",
          company_schema: "onboarding_test",
          subdomain: "onboarding-test",
          onboarding_step: "setup_payment"
        })

      {:ok, tenant: tenant}
    end

    test "completes onboarding", %{tenant: tenant} do
      assert not is_nil(tenant.onboarding_step)
      assert is_nil(tenant.onboarding_completed_at)

      {:ok, completed} = Tenant.complete_onboarding(tenant, %{})

      assert is_nil(completed.onboarding_step)
      assert not is_nil(completed.onboarding_completed_at)
      assert DateTime.compare(completed.onboarding_completed_at, DateTime.utc_now()) != :lt
    end
  end

  describe "tenant queries" do
    setup do
      # Create multiple tenants for testing
      {:ok, active_tenant} =
        Tenant.create(%{
          slug: "active-tenant",
          company_name: "Active Company",
          company_schema: "active_tenant",
          subdomain: "active",
          status: :active,
          plan: :starter
        })

      {:ok, suspended_tenant} =
        Tenant.create(%{
          slug: "suspended-tenant",
          company_name: "Suspended Company",
          company_schema: "suspended_tenant",
          subdomain: "suspended",
          status: :suspended,
          plan: :professional
        })

      {:ok, trial_tenant} =
        Tenant.create(%{
          slug: "trial-tenant",
          company_name: "Trial Company",
          company_schema: "trial_tenant",
          subdomain: "trial",
          status: :trial,
          plan: :trial
        })

      %{
        active_tenant: active_tenant,
        suspended_tenant: suspended_tenant,
        trial_tenant: trial_tenant
      }
    end

    test "finds tenant by slug" do
      assert {:ok, tenant} = Tenant.by_slug(%{slug: "active-tenant"})
      assert tenant.slug == "active-tenant"
    end

    test "finds tenant by subdomain" do
      assert {:ok, tenant} = Tenant.by_subdomain(%{subdomain: "active"})
      assert tenant.subdomain == "active"
    end

    test "filters tenants by status" do
      assert {:ok, active_tenants} = Tenant.by_status(%{status: :active})
      assert length(active_tenants.results) == 1
      assert hd(active_tenants.results).slug == "active-tenant"
    end

    test "filters tenants by plan" do
      assert {:ok, starter_tenants} = Tenant.by_plan(%{plan: :starter})
      assert length(starter_tenants.results) == 1
      assert hd(starter_tenants.results).slug == "active-tenant"
    end
  end

  describe "tenant configuration management" do
    setup do
      {:ok, tenant} =
        Tenant.create(%{
          slug: "config-test",
          company_name: "Config Test Company",
          company_schema: "config_test",
          subdomain: "config-test",
          settings: %{
            "feature_flags" => %{
              "advanced_analytics" => true,
              "multi_currency" => false
            },
            "notification_preferences" => %{
              "email_alerts" => true,
              "sms_alerts" => false
            }
          },
          branding: %{
            "primary_color" => "#0066cc",
            "logo_url" => "https://example.com/logo.png",
            "theme" => "light"
          }
        })

      {:ok, tenant: tenant}
    end

    test "stores complex settings", %{tenant: tenant} do
      settings = tenant.settings
      assert settings["feature_flags"]["advanced_analytics"] == true
      assert settings["feature_flags"]["multi_currency"] == false
      assert settings["notification_preferences"]["email_alerts"] == true
    end

    test "stores branding configuration", %{tenant: tenant} do
      branding = tenant.branding
      assert branding["primary_color"] == "#0066cc"
      assert branding["logo_url"] == "https://example.com/logo.png"
      assert branding["theme"] == "light"
    end
  end

  # Helper functions

  defp has_constraint_error?(changeset, field) do
    Keyword.has_key?(changeset.errors, field) and
      elem(changeset.errors[field], 0) in ["has already been taken", "duplicate key value"]
  end
end
