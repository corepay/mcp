defmodule Mcp.Underwriting.Adapters.StripeBoarding do
  @moduledoc """
  Mock adapter for Stripe boarding.
  """
  @behaviour Mcp.Underwriting.Adapters.BoardingAdapter

  @impl true
  def board_merchant(application, profile) do
    IO.puts("📤 Boarding to Stripe: #{application.id} via #{profile.name}")
    # Simulate API latency
    :timer.sleep(1000)

    {:ok,
     %{
       mid: ("acct_" <> Ecto.UUID.generate()) |> String.slice(0..10),
       tid: ("stripe_tid_" <> Ecto.UUID.generate()) |> String.slice(0, 8),
       status: :active
     }}
  end

  @impl true
  def check_status(_boarding) do
    {:ok, %{status: :active}}
  end
end
