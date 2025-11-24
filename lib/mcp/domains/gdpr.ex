defmodule Mcp.Domains.Gdpr do
  @moduledoc """
  GDPR domain for managing user data privacy and compliance.

  This domain handles all GDPR-related operations including:
  - User data export requests
  - Account deletion and anonymization
  - Consent management
  - Data retention policies
  - Audit trail management
  """

  use Ash.Domain

  resources do
    resource Mcp.Gdpr.Resources.User
    resource Mcp.Gdpr.Resources.DataExport
    resource Mcp.Gdpr.Resources.AuditTrail
    resource Mcp.Gdpr.Resources.RetentionPolicy
  end
end