defmodule Mcp.Billing do
  @moduledoc """
  Billing domain for API usage tracking and invoicing.
  """
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  resources do
    # No resources yet, but serves as a placeholder for Billing domain logic
    # and potentially future resources like `Invoice` or `Subscription`.
  end
end
