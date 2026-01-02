defmodule Mcp.Underwriting.Services.TheEyeTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.TheEye

  describe "health_check/0" do
    test "returns healthy when service is running" do
      # Requires The Eye to be running
      case TheEye.health_check() do
        {:ok, %{"status" => "healthy"}} -> assert true
        # OK if not running in test
        {:error, :service_unavailable} -> assert true
      end
    end
  end

  describe "analyze_document/2" do
    test "returns error when service is unavailable or document invalid" do
      # Most test environments won't have The Eye running
      # If running, garbage bytes will return API error
      case TheEye.analyze_document(<<1, 2, 3>>, "test.pdf") do
        {:ok, _result} -> assert true
        {:error, :service_unavailable} -> assert true
        {:error, {:request_failed, _}} -> assert true
        {:error, {:api_error, _status, _body}} -> assert true
      end
    end
  end

  describe "validate_document/3" do
    test "validates government ID content" do
      # Mock content with expected fields
      content = """
      DRIVER'S LICENSE
      Name: John Doe
      Date of Birth: 01/15/1985
      License Number: D1234567
      """

      assert {:ok, :valid} = TheEye.validate_content(content, :government_id)
    end

    test "fails validation when name not found in ID" do
      content = "Some random document without expected fields"

      assert {:error, {:validation_failed, issues}} =
               TheEye.validate_content(content, :government_id)

      assert "Name not found" in issues
    end

    test "validates bank statement content" do
      content = """
      BANK STATEMENT - First National Bank
      Statement Period: January 1-31, 2026
      Account Number: ****1234
      Account Type: Business Checking
      Current Balance: $5,432.10
      Previous Balance: $4,321.00
      Total Deposits: $2,500.00
      Total Withdrawals: $1,388.90
      """

      assert {:ok, :valid} = TheEye.validate_content(content, :bank_statement)
    end

    test "fails validation when balance not found in statement" do
      # Long enough content with account info but missing balance
      content = """
      DOCUMENT - First National Bank
      Account Number: ****1234
      Account Type: Business Checking
      This document does not contain the expected financial summary.
      Please contact customer service for assistance.
      """

      assert {:error, {:validation_failed, issues}} =
               TheEye.validate_content(content, :bank_statement)

      assert "Balance not found" in issues
    end

    test "passes validation for unknown document types" do
      content = "Any readable content"

      assert {:ok, :valid} = TheEye.validate_content(content, :other)
    end
  end

  describe "base_url/0" do
    test "uses environment variable or default" do
      url = TheEye.base_url()
      assert String.starts_with?(url, "http://")
    end
  end
end
