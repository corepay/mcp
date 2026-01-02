defmodule Mcp.Underwriting.Services.DocumentValidatorTest do
  @moduledoc """
  Tests for DocumentValidator service that validates documents
  before submission using The Eye analysis.
  """
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.DocumentValidator

  describe "validate_extracted_content/2 with government_id" do
    test "returns ok for valid government ID" do
      content = """
      DRIVER LICENSE
      Name: John Doe
      DOB: 01/15/1985
      Address: 123 Main St
      Expires: 12/31/2027
      """

      result = DocumentValidator.validate_extracted_content(content, :government_id)

      assert {:ok, validation} = result
      assert validation.valid? == true
      assert validation.quality_score >= 80
    end

    test "returns error with suggestions for blurry/unreadable ID" do
      content = "DRVR LIC... [unreadable]"

      result = DocumentValidator.validate_extracted_content(content, :government_id)

      assert {:error, validation} = result
      assert validation.valid? == false
      assert "Name not found" in validation.issues
      assert length(validation.suggestions) > 0
    end

    test "partial validation when some fields missing" do
      content = """
      DRIVER LICENSE
      Name: Jane Smith
      Address: 456 Oak Ave
      """

      result = DocumentValidator.validate_extracted_content(content, :government_id)

      assert {:error, validation} = result
      assert validation.valid? == false
      # Missing DOB and expiration
      assert "Date of birth not found" in validation.issues
      assert "Expiration date not found" in validation.issues
      # Quality score reflects partial success
      assert validation.quality_score > 0
      assert validation.quality_score < 100
    end
  end

  describe "validate_extracted_content/2 with bank_statement" do
    test "validates bank statement has required fields" do
      content = """
      ACME BANK
      Account: ****4567
      Statement Period: Nov 1 - Nov 30, 2025
      Beginning Balance: $5,432.10
      Ending Balance: $6,789.00
      """

      result = DocumentValidator.validate_extracted_content(content, :bank_statement)

      assert {:ok, validation} = result
      assert validation.valid? == true
    end

    test "rejects bank statement missing balance" do
      content = """
      ACME BANK
      Account Number: 123456789
      Date: November 2025
      """

      result = DocumentValidator.validate_extracted_content(content, :bank_statement)

      assert {:error, validation} = result
      assert "Balance not found" in validation.issues
    end

    test "rejects unreadable bank statement" do
      content = "ACM..."

      result = DocumentValidator.validate_extracted_content(content, :bank_statement)

      assert {:error, validation} = result
      assert validation.valid? == false
    end
  end

  describe "validate_extracted_content/2 with business_license" do
    test "validates business license has required fields" do
      content = """
      BUSINESS LICENSE
      License Number: BL-123456
      Issued to: ABC Corporation
      Valid Through: 12/31/2026
      """

      result = DocumentValidator.validate_extracted_content(content, :business_license)

      assert {:ok, validation} = result
      assert validation.valid? == true
    end

    test "accepts permit as license type" do
      content = """
      FOOD SERVICE PERMIT
      Permit Number: FSP-789
      Issued to: Joe's Diner
      """

      result = DocumentValidator.validate_extracted_content(content, :business_license)

      assert {:ok, validation} = result
      assert validation.valid? == true
    end
  end

  describe "validate_extracted_content/2 with unknown type" do
    test "returns ok with lower confidence for unknown document type" do
      content = "Some random document content here"

      result = DocumentValidator.validate_extracted_content(content, :unknown_type)

      assert {:ok, validation} = result
      assert validation.valid? == true
      # Lower quality score for unknown types
      assert validation.quality_score <= 70
    end
  end

  describe "check_image_quality/1" do
    test "returns quality metrics map" do
      metrics = DocumentValidator.check_image_quality("fake_image_bytes")

      assert is_map(metrics)
      assert Map.has_key?(metrics, :resolution_ok)
      assert Map.has_key?(metrics, :brightness_ok)
      assert Map.has_key?(metrics, :blur_detected)
    end
  end

  describe "validation struct" do
    test "validation result has all expected fields" do
      content = """
      DRIVER LICENSE
      Name: Test User
      DOB: 01/01/1990
      Expires: 12/31/2030
      """

      {:ok, validation} = DocumentValidator.validate_extracted_content(content, :government_id)

      assert Map.has_key?(validation, :valid?)
      assert Map.has_key?(validation, :quality_score)
      assert Map.has_key?(validation, :issues)
      assert Map.has_key?(validation, :suggestions)
    end
  end
end
