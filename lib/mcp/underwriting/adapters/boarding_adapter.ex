defmodule Mcp.Underwriting.Adapters.BoardingAdapter do
  @moduledoc """
  Defines the behavior for bank boarding adapters.
  """

  @callback board_merchant(
              application :: Mcp.Underwriting.Application.t(),
              profile :: Mcp.Underwriting.BankProfile.t()
            ) ::
              {:ok, %{mid: String.t(), tid: String.t(), status: :active | :pending}}
              | {:error, any()}

  @callback check_status(boarding :: Mcp.Underwriting.Boarding.t()) ::
              {:ok, %{status: :active | :pending}}
              | {:error, any()}
end
