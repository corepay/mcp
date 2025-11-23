defmodule Mcp.Gdpr.ConfigTest do
  use ExUnit.Case, async: true

  alias Mcp.Gdpr.Config

  describe "retention_periods/0" do
    test "returns expected retention periods" do
      periods = Config.retention_periods()

      assert Map.has_key?(periods, "core_identity")
      assert Map.has_key?(periods, "authentication_data")
      assert Map.has_key?(periods, "activity_data")
      assert Map.has_key?(periods, "communication_data")
      assert Map.has_key?(periods, "behavioral_data")
      assert Map.has_key?(periods, "derived_data")
      assert Map.has_key?(periods, "financial_data")
      assert Map.has_key?(periods, "tax_records")
      assert Map.has_key?(periods, "security_logs")
      assert Map.has_key?(periods, "audit_trail")
      assert Map.has_key?(periods, "data_exports")
    end

    test "authentication_data has immediate deletion" do
      periods = Config.retention_periods()
      assert periods["authentication_data"] == 0
    end

    test "financial_data has 7 year retention" do
      periods = Config.retention_periods()
      # 7 years
      assert periods["financial_data"] == 2555
    end
  end

  describe "data_categories/0" do
    test "returns expected data categories" do
      categories = Config.data_categories()

      assert Map.has_key?(categories, "core_identity")
      assert Map.has_key?(categories, "authentication_data")
      assert Map.has_key?(categories, "activity_data")
      assert Map.has_key?(categories, "communication_data")
      assert Map.has_key?(categories, "behavioral_data")
      assert Map.has_key?(categories, "derived_data")
    end

    test "core_identity contains email and name fields" do
      categories = Config.data_categories()
      core_fields = categories["core_identity"]

      assert "email" in core_fields
      assert "first_name" in core_fields
      assert "last_name" in core_fields
      assert "phone_number" in core_fields
      assert "address" in core_fields
    end
  end

  describe "legal_bases/0" do
    test "returns all legal bases" do
      bases = Config.legal_bases()

      assert length(bases) == 4

      consent_basis = Enum.find(bases, &(&1.code == "consent"))
      assert consent_basis != nil
      assert consent_basis.name == "Consent"
      assert :marketing in consent_basis.valid_for
      assert :analytics in consent_basis.valid_for

      contract_basis = Enum.find(bases, &(&1.code == "contract"))
      assert contract_basis != nil
      assert :essential in contract_basis.valid_for
    end
  end

  describe "get_retention_period/1" do
    test "returns correct retention period for known category" do
      assert Config.get_retention_period("core_identity") == 90
      assert Config.get_retention_period("authentication_data") == 0
    end

    test "returns default period for unknown category" do
      assert Config.get_retention_period("unknown_category") == 90
    end
  end

  describe "get_data_category/1" do
    test "returns category for known field" do
      assert Config.get_data_category("email") == ["core_identity"]
      assert Config.get_data_category("hashed_password") == ["authentication_data"]
    end

    test "returns empty list for unknown field" do
      assert Config.get_data_category("unknown_field") == []
    end
  end

  describe "valid_legal_basis?/2" do
    test "validates consent for marketing" do
      assert Config.valid_legal_basis?("consent", "marketing") == true
    end

    test "validates contract for essential data" do
      assert Config.valid_legal_basis?("contract", "essential") == true
    end

    test "rejects invalid combinations" do
      assert Config.valid_legal_basis?("consent", "essential") == false
    end

    test "handles unknown categories" do
      assert Config.valid_legal_basis?("consent", "unknown") == false
    end
  end

  describe "export_settings/0" do
    test "returns export configuration" do
      settings = Config.export_settings()

      assert is_map(settings)
      assert Map.has_key?(settings, :max_file_size_mb)
      assert Map.has_key?(settings, :max_download_count)
      assert Map.has_key?(settings, :expiry_hours)
      assert Map.has_key?(settings, :supported_formats)

      assert settings.max_download_count == 5
      assert settings.expiry_hours == 48
      assert "json" in settings.supported_formats
    end
  end

  describe "anonymization_settings/0" do
    test "returns anonymization configuration" do
      settings = Config.anonymization_settings()

      assert is_map(settings)
      assert Map.has_key?(settings, :batch_size)
      assert Map.has_key?(settings, :max_retries)
      assert Map.has_key?(settings, :retry_delay_seconds)
      assert Map.has_key?(settings, :email_domain)
      assert Map.has_key?(settings, :placeholder_name)

      assert settings.email_domain == "deleted.local"
      assert settings.placeholder_name == "Deleted User"
    end
  end

  describe "compliance_settings/0" do
    test "returns compliance monitoring configuration" do
      settings = Config.compliance_settings()

      assert is_map(settings)
      assert Map.has_key?(settings, :retention_check_interval)
      assert Map.has_key?(settings, :compliance_check_interval)
      assert Map.has_key?(settings, :audit_check_interval)
      assert Map.has_key?(settings, :overdue_users_threshold)

      assert settings.overdue_users_threshold == 10
    end
  end

  describe "utility functions" do
    test "gdpr_enabled?/0 returns true by default" do
      assert Config.gdpr_enabled?() == true
    end

    test "deletion_grace_period_days/0 returns default" do
      assert Config.deletion_grace_period_days() == 14
    end

    test "standard_retention_days/0 returns default" do
      assert Config.standard_retention_days() == 90
    end

    test "auto_anonymization_enabled?/0 returns true by default" do
      assert Config.auto_anonymization_enabled?() == true
    end

    test "timezone/0 returns UTC by default" do
      assert Config.timezone() == "UTC"
    end
  end

  describe "get_config/2" do
    test "returns configured value when set" do
      # This would require setting application config
      # For now, test with default fallback
      assert Config.get_config(:unknown_key, "default") == "default"
    end
  end
end
