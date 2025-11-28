defmodule Mcp.Platform do
  @moduledoc """
  Ash Domain for the Platform context.
  """

  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Platform.Tenant
    resource Mcp.Platform.TenantSettings
    resource Mcp.Platform.TenantBranding
    resource Mcp.Platform.Developer
    resource Mcp.Platform.Reseller
    resource Mcp.Platform.DeveloperTenant
    resource Mcp.Platform.ResellerTenant
    resource Mcp.Platform.Merchant
    resource Mcp.Platform.Store
    resource Mcp.Platform.MID
    resource Mcp.Platform.Customer
    resource Mcp.Platform.Vendor
    resource Mcp.Platform.CustomerStore
    resource Mcp.Platform.VendorStore
    resource Mcp.Platform.Address
    resource Mcp.Platform.Email
    resource Mcp.Platform.Phone
    resource Mcp.Platform.PayfacConfiguration
  end
end
