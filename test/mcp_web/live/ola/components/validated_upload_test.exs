defmodule McpWeb.Ola.Components.ValidatedUploadTest do
  @moduledoc """
  Tests for ValidatedUpload LiveComponent.
  Tests the validation processing logic that provides real-time feedback.
  """
  use ExUnit.Case, async: true

  alias McpWeb.Ola.Components.ValidatedUpload

  describe "process_validation/3" do
    test "returns valid result for properly formatted government ID content" do
      content = """
      DRIVER LICENSE
      Name: John Doe
      DOB: 01/15/1985
      Expires: 12/31/2027
      """

      result = ValidatedUpload.process_validation(content, "license.jpg", :government_id)

      assert is_map(result)
      assert result.valid? == true
      assert result.quality_score >= 80
      assert result.issues == []
    end

    test "returns invalid result with issues for poor quality content" do
      content = "DRVR LIC... [unreadable]"

      result = ValidatedUpload.process_validation(content, "blurry.jpg", :government_id)

      assert is_map(result)
      assert result.valid? == false
      assert length(result.issues) > 0
      assert length(result.suggestions) > 0
    end

    test "returns valid result for bank statement with required fields" do
      # Note: Bank statement validation requires content > 100 chars
      content = """
      ACME BANK
      Statement Date: January 2026
      Account: ****4567
      Statement Period: Dec 1, 2025 - Dec 31, 2025
      Beginning Balance: $4,532.10
      Ending Balance: $5,000.00
      Available Balance: $4,850.00
      """

      result = ValidatedUpload.process_validation(content, "statement.pdf", :bank_statement)

      assert is_map(result)
      assert result.valid? == true
    end

    test "returns result with extracted_data field" do
      content = """
      DRIVER LICENSE
      Name: Jane Smith
      DOB: 05/20/1990
      Expires: 06/30/2028
      """

      result = ValidatedUpload.process_validation(content, "id.jpg", :government_id)

      assert is_map(result)
      assert Map.has_key?(result, :extracted_data)
    end
  end

  describe "component assigns initialization" do
    test "mount/1 initializes with correct default assigns" do
      {:ok, socket} = ValidatedUpload.mount(%Phoenix.LiveView.Socket{})

      assert socket.assigns.validation_result == nil
      assert socket.assigns.validating == false
    end
  end
end
