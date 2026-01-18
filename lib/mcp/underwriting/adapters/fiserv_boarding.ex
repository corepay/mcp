defmodule Mcp.Underwriting.Adapters.FiservBoarding do
  @moduledoc """
  Mock adapter for Fiserv boarding.
  """
  @behaviour Mcp.Underwriting.Adapters.BoardingAdapter

  @impl true
  def board_merchant(application, profile) do
    IO.puts("📤 Boarding to Fiserv: #{application.id} via #{profile.name}")
    # Simulate API latency
    :timer.sleep(1500)

    {:ok,
     %{
       mid: ("FIS_" <> Ecto.UUID.generate()) |> String.slice(0, 10),
       tid: ("FST_" <> Ecto.UUID.generate()) |> String.slice(0, 8),
       status: :active
     }}
  end

  @impl true
  def check_status(_boarding) do
    {:ok, %{status: :active}}
  end
end
