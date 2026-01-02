defmodule Mcp.Underwriting.Services.DocumentAutofillTest do
  @moduledoc """
  Tests for DocumentAutofill service that extracts form-fillable data
  from validated documents to enable zero-entry applications.
  """
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.DocumentAutofill

  describe "extract_fields/2 with government_id" do
    test "extracts name and DOB from government ID" do
      structured_data = %{
        "name" => "John Michael Doe",
        "date_of_birth" => "1985-01-15",
        "address" => "123 Main St, Anytown, CA 90210"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :government_id)

      assert fields["owner_name"] == "John Michael Doe"
      assert fields["owner_dob"] == "1985-01-15"
      assert fields["owner_address"] == "123 Main St, Anytown, CA 90210"
    end

    test "handles missing optional fields gracefully" do
      structured_data = %{
        "name" => "Jane Smith"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :government_id)

      assert fields["owner_name"] == "Jane Smith"
      refute Map.has_key?(fields, "owner_dob")
      refute Map.has_key?(fields, "owner_address")
    end
  end

  describe "extract_fields/2 with bank_statement" do
    test "extracts bank info from statement" do
      structured_data = %{
        "bank_name" => "First National Bank",
        "account_number" => "****4567",
        "routing_number" => "021000021",
        "ending_balance" => "$12,345.67"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :bank_statement)

      assert fields["bank_name"] == "First National Bank"
      assert fields["account_last4"] == "4567"
      assert fields["monthly_volume"] == 12_345.67
    end

    test "handles full account number and extracts last 4" do
      structured_data = %{
        "bank_name" => "Test Bank",
        "account_number" => "1234567890"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :bank_statement)

      assert fields["account_last4"] == "7890"
    end

    test "handles currency formats" do
      structured_data = %{
        "ending_balance" => "$1,234,567.89"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :bank_statement)

      assert fields["monthly_volume"] == 1_234_567.89
    end
  end

  describe "extract_fields/2 with business_license" do
    test "extracts business license fields" do
      structured_data = %{
        "business_name" => "Acme Corporation",
        "license_number" => "BL-2024-12345",
        "address" => "456 Business Ave, Commerce City, CA 90001"
      }

      fields = DocumentAutofill.extract_fields(structured_data, :business_license)

      assert fields["business_name"] == "Acme Corporation"
      assert fields["license_number"] == "BL-2024-12345"
      assert fields["business_address"] == "456 Business Ave, Commerce City, CA 90001"
    end
  end

  describe "extract_fields/2 with unknown type" do
    test "returns empty map for unknown document type" do
      structured_data = %{"foo" => "bar"}

      fields = DocumentAutofill.extract_fields(structured_data, :unknown_type)

      assert fields == %{}
    end
  end

  describe "merge_with_form/2" do
    test "only fills empty fields" do
      existing = %{"business_name" => "Existing Corp", "ein" => ""}
      extracted = %{"business_name" => "From Document", "ein" => "12-3456789"}

      merged = DocumentAutofill.merge_with_form(extracted, existing)

      # Kept existing non-empty value
      assert merged["business_name"] == "Existing Corp"
      # Filled empty value
      assert merged["ein"] == "12-3456789"
    end

    test "fills nil fields" do
      existing = %{"name" => nil, "email" => "user@example.com"}
      extracted = %{"name" => "John Doe", "email" => "extracted@example.com"}

      merged = DocumentAutofill.merge_with_form(extracted, existing)

      assert merged["name"] == "John Doe"
      assert merged["email"] == "user@example.com"
    end

    test "adds new fields from extracted data" do
      existing = %{"name" => "Original Name"}
      extracted = %{"ein" => "12-3456789", "phone" => "555-1234"}

      merged = DocumentAutofill.merge_with_form(extracted, existing)

      assert merged["name"] == "Original Name"
      assert merged["ein"] == "12-3456789"
      assert merged["phone"] == "555-1234"
    end
  end
end
