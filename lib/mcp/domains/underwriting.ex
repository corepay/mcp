defmodule Mcp.Underwriting do
  @moduledoc """
  Ash Domain for the Underwriting context.
  """

  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Underwriting.Application
    resource Mcp.Underwriting.Review
    resource Mcp.Underwriting.RiskAssessment

    resource Mcp.Underwriting.Client
    resource Mcp.Underwriting.Address
    resource Mcp.Underwriting.Document
    resource Mcp.Underwriting.Check
    resource Mcp.Underwriting.VendorSettings
    resource Mcp.Underwriting.Activity
    resource Mcp.Underwriting.DocumentAnalysis
  end
end
