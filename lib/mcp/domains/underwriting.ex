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

    # Agentic UaaS Resources
    resource Mcp.Underwriting.AgentBlueprint
    resource Mcp.Underwriting.InstructionSet
    resource Mcp.Underwriting.Playbook
    resource Mcp.Underwriting.PlaybookConcierge
    resource Mcp.Underwriting.Pipeline
    resource Mcp.Underwriting.Execution
    resource Mcp.Underwriting.ExecutiveAssistant

    # Deal Room Resources
    resource Mcp.Underwriting.Note

    # Sprint 5: Yield & Boarding
    resource Mcp.Underwriting.Processor
    resource Mcp.Underwriting.BankProfile
    resource Mcp.Underwriting.Boarding
  end
end
