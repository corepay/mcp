defmodule Mcp.Underwriting.VendorRouter do
  @moduledoc """
  Decides which Underwriting Vendor to use for a given request.
  """

  alias Mcp.Underwriting.Adapters.ComplyCube
  alias Mcp.Underwriting.Adapters.Idenfy
  alias Mcp.Underwriting.Adapters.Mock

  def select_adapter(_context \\ %{}) do
    # 1. Check if we are in test mode or forced mock
    if Application.get_env(:mcp, :underwriting_adapter) == Mock do
      Mock
    else
      # 2. Check for configured preferred vendor
      case Application.get_env(:mcp, :preferred_vendor) do
        :idenfy -> Idenfy
        :comply_cube -> ComplyCube
        _ -> 
          # 3. Default logic (e.g., fallback to ComplyCube)
          ComplyCube
      end
    end
  end
end
