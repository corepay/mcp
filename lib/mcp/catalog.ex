defmodule Mcp.Catalog do
  @moduledoc """
  Ash Domain for the Catalog context.

  Manages products, categories, and variants for merchants.
  """

  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Catalog.Category
    resource Mcp.Catalog.Product
    resource Mcp.Catalog.ProductVariant
  end
end
