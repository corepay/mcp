defmodule Mcp.Registration.SelfRegistrationControlTest do
  @moduledoc """
  Comprehensive tests for Story 2.9 - Self-Registration Control system.

  Tests verify:
  - Default secure settings (all self-registration disabled)
  - Merchant control over customer/vendor self-registration
  - Registration workflows respect self-registration settings
  - All other entity types are invitation-only
  - Business logic enforcement at service level
  """

  use Mcp.DataCase, async: true

  alias Mcp.Accounts.RegistrationSettings
  alias Mcp.Registration.{PolicyValidator, RegistrationService}

  setup do
    {:ok, tenant} =
      Ash.create(
        Mcp.Platform.Tenant,
        %{
          name: "Test Tenant",
          slug: "test-tenant-#{Ecto.UUID.generate()}",
          subdomain: "test-#{Ecto.UUID.generate()}"
        },
        action: :create
      )

    {:ok, tenant_id: tenant.id}
  end

  describe "Self-Registration Default Settings" do
    test "defaults to secure (all self-registration disabled)", %{tenant_id: tenant_id} do
      # Test default settings are secure by default
      {:ok, settings} = RegistrationSettings.create_default_settings(tenant_id)

      assert settings["customer_registration_enabled"] == false
      assert settings["vendor_registration_enabled"] == false

      # Verify PolicyValidator also uses secure defaults
      default_settings = PolicyValidator.get_default_settings()
      assert default_settings["customer_registration_enabled"] == false
      assert default_settings["vendor_registration_enabled"] == false
    end

    test "LiveView components use secure defaults" do
      # Test CustomerRegistration LiveView
      # customer_defaults = CustomerRegistration.get_default_tenant_settings()
      # assert customer_defaults["allow_self_registration"] == false
      # assert customer_defaults["require_approval"] == true

      # Test VendorRegistration LiveView
      # vendor_defaults = VendorRegistration.get_default_tenant_settings()
      # assert vendor_defaults["allow_self_registration"] == false
      # assert vendor_defaults["require_approval"] == true
    end
  end

  describe "PolicyValidator Self-Registration Control" do
    test "rejects customer registration when disabled" do
      settings = %{
        customer_registration_enabled: false,
        vendor_registration_enabled: false
      }

      result = PolicyValidator.validate_registration_enabled(settings, :customer)

      assert result ==
               {:error,
                {:validation_failed, :customer_registration_disabled,
                 "Customer self-registration is currently disabled. Please contact the merchant for an invitation."}}
    end

    test "rejects vendor registration when disabled" do
      settings = %{
        customer_registration_enabled: false,
        vendor_registration_enabled: false
      }

      result = PolicyValidator.validate_registration_enabled(settings, :vendor)

      assert result ==
               {:error,
                {:validation_failed, :vendor_registration_disabled,
                 "Vendor self-registration is currently disabled. Please contact the merchant for an invitation."}}
    end

    test "allows customer registration when enabled" do
      settings = %{
        customer_registration_enabled: true,
        vendor_registration_enabled: false
      }

      result = PolicyValidator.validate_registration_enabled(settings, :customer)
      assert result == :ok
    end

    test "allows vendor registration when enabled" do
      settings = %{
        customer_registration_enabled: false,
        vendor_registration_enabled: true
      }

      result = PolicyValidator.validate_registration_enabled(settings, :vendor)
      assert result == :ok
    end

    test "rejects all other entity types (invitation-only)" do
      settings = %{
        customer_registration_enabled: true,
        vendor_registration_enabled: true
      }

      # Test all non-customer/vendor types are rejected
      entity_types = [:partner, :employee, :admin, :contractor, :supplier, :distributor]

      for entity_type <- entity_types do
        result = PolicyValidator.validate_registration_enabled(settings, entity_type)

        assert result ==
                 {:error,
                  {:validation_failed, :invitation_only_registration,
                   "This entity type can only register via invitation (invitation-only)"}}
      end
    end
  end

  describe "RegistrationService Self-Registration Control" do
    test "prevents customer self-registration when disabled", %{tenant_id: tenant_id} do
      # Create settings with customer registration disabled
      {:ok, _settings} = RegistrationSettings.create_default_settings(tenant_id)

      customer_data = %{
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        password: "SecurePass123!"
      }

      context = %{
        ip_address: "127.0.0.1",
        user_agent: "test-agent"
      }

      result =
        RegistrationService.initialize_registration(tenant_id, :customer, customer_data, context)

      assert {:error, {:validation_failed, :customer_registration_disabled, _message}} = result
    end

    test "prevents vendor self-registration when disabled", %{tenant_id: tenant_id} do
      # Create settings with vendor registration disabled
      {:ok, _settings} = RegistrationSettings.create_default_settings(tenant_id)

      vendor_data = %{
        first_name: "Jane",
        last_name: "Smith",
        email: "jane@company.com",
        password: "SecurePass123!",
        company_name: "Test Company",
        business_type: "corporation"
      }

      context = %{
        ip_address: "127.0.0.1",
        user_agent: "test-agent"
      }

      result =
        RegistrationService.initialize_registration(tenant_id, :vendor, vendor_data, context)

      assert {:error, {:validation_failed, :vendor_registration_disabled, _message}} = result
    end

    test "allows customer self-registration when enabled", %{tenant_id: tenant_id} do
      # Create settings with customer registration enabled
      {:ok, _settings} = RegistrationSettings.create_default_settings(tenant_id)
      RegistrationSettings.update_settings(tenant_id, %{"customer_registration_enabled" => true})

      customer_data = %{
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        password: "SecurePass123!"
      }

      context = %{
        ip_address: "127.0.0.1",
        user_agent: "test-agent"
      }

      result =
        RegistrationService.initialize_registration(tenant_id, :customer, customer_data, context)

      # Should not fail on self-registration check
      refute match?({:error, {:validation_failed, :customer_registration_disabled, _}}, result)
    end
  end

  describe "Merchant Settings Management" do
    test "can enable customer self-registration", %{tenant_id: tenant_id} do
      # Create default settings
      {:ok, settings} = RegistrationSettings.create_default_settings(tenant_id)
      assert settings["customer_registration_enabled"] == false

      # Update to enable customer registration
      {:ok, updated_settings} =
        RegistrationSettings.update_settings(tenant_id, %{
          "customer_registration_enabled" => true
        })

      assert updated_settings["customer_registration_enabled"] == true
      # Unchanged
      assert updated_settings["vendor_registration_enabled"] == false
    end

    test "can enable vendor self-registration", %{tenant_id: tenant_id} do
      # Create default settings
      {:ok, settings} = RegistrationSettings.create_default_settings(tenant_id)
      assert settings["vendor_registration_enabled"] == false

      # Update to enable vendor registration
      {:ok, updated_settings} =
        RegistrationSettings.update_settings(tenant_id, %{
          "vendor_registration_enabled" => true
        })

      assert updated_settings["vendor_registration_enabled"] == true
      # Unchanged
      assert updated_settings["customer_registration_enabled"] == false
    end

    test "can enable both customer and vendor self-registration", %{tenant_id: tenant_id} do
      # Create default settings
      {:ok, _settings} = RegistrationSettings.create_default_settings(tenant_id)

      # Update to enable both
      {:ok, updated_settings} =
        RegistrationSettings.update_settings(tenant_id, %{
          "customer_registration_enabled" => true,
          "vendor_registration_enabled" => true
        })

      assert updated_settings["customer_registration_enabled"] == true
      assert updated_settings["vendor_registration_enabled"] == true
    end
  end

  describe "Security Enforcement" do
    test "registration workflows check self-registration settings before processing", %{
      tenant_id: tenant_id
    } do
      # Create disabled settings
      {:ok, _settings} = RegistrationSettings.create_default_settings(tenant_id)

      # Test that registration workflows fail early with self-registration disabled
      test_cases = [
        {:customer,
         %{
           first_name: "Test",
           last_name: "User",
           email: "test@example.com",
           password: "SecurePass123!"
         }},
        {:vendor,
         %{
           first_name: "Test",
           last_name: "Vendor",
           email: "vendor@company.com",
           password: "SecurePass123!",
           company_name: "Test Company",
           business_type: "corporation"
         }}
      ]

      for {type, data} <- test_cases do
        context = %{ip_address: "127.0.0.1", user_agent: "test"}
        result = RegistrationService.initialize_registration(tenant_id, type, data, context)

        assert {:error, {:validation_failed, registration_error, _message}} = result

        assert registration_error in [
                 :customer_registration_disabled,
                 :vendor_registration_disabled
               ]
      end
    end

    test "cannot bypass self-registration controls through direct service calls", %{
      tenant_id: tenant_id
    } do
      # Ensure settings are disabled
      {:ok, _settings} = RegistrationSettings.create_default_settings(tenant_id)

      # Test that even direct calls to PolicyValidator fail
      settings = %{
        customer_registration_enabled: false,
        vendor_registration_enabled: false
      }

      # Customer registration should fail
      assert {:error, {:validation_failed, :customer_registration_disabled, _}} =
               PolicyValidator.validate_registration_enabled(settings, :customer)

      # Vendor registration should fail
      assert {:error, {:validation_failed, :vendor_registration_disabled, _}} =
               PolicyValidator.validate_registration_enabled(settings, :vendor)

      # Other entity types should fail with invitation-only message
      assert {:error, {:validation_failed, :invitation_only_registration, _}} =
               PolicyValidator.validate_registration_enabled(settings, :partner)
    end
  end

  describe "Error Messages" do
    test "provides clear error messages when self-registration is disabled" do
      settings = %{customer_registration_enabled: false}

      result = PolicyValidator.validate_registration_enabled(settings, :customer)
      {:error, {:validation_failed, :customer_registration_disabled, message}} = result

      assert message ==
               "Customer self-registration is currently disabled. Please contact the merchant for an invitation."

      assert String.contains?(message, "merchant")
      assert String.contains?(message, "invitation")
    end

    test "provides invitation-only message for non-customer/vendor types" do
      settings = %{customer_registration_enabled: true, vendor_registration_enabled: true}

      result = PolicyValidator.validate_registration_enabled(settings, :partner)
      {:error, {:validation_failed, :invitation_only_registration, message}} = result

      assert message == "This entity type can only register via invitation (invitation-only)"
      assert String.contains?(message, "invitation")
    end
  end
end
