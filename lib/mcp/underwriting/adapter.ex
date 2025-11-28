defmodule Mcp.Underwriting.Adapter do
  @moduledoc """
  Defines the contract for Underwriting Vendors (e.g., ComplyCube, Veriff).
  """

  @callback verify_identity(applicant_data :: map(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
  @callback screen_business(business_data :: map(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
  @callback check_watchlist(name :: String.t(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
  @callback document_check(document_image :: binary(), type :: atom(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
end
