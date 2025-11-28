defmodule Mcp.Underwriting.Adapters.Mock do
  @moduledoc """
  Mock adapter for development and testing.
  """
  @behaviour Mcp.Underwriting.Adapter

  @impl true
  def verify_identity(_applicant_data, _context) do
    {:ok, %{
      status: :clear,
      score: 95,
      details: %{
        "first_name" => "MATCH",
        "last_name" => "MATCH",
        "dob" => "MATCH"
      }
    }}
  end

  @impl true
  def screen_business(business_data, _context) do
    # Simulate scenarios based on business name
    case business_data["business_name"] do
      "Fraud Corp" ->
        {:ok, %{status: :flagged, reason: "Sanctions Match"}}
      "Risky Business" ->
        {:ok, %{status: :review, reason: "Adverse Media"}}
      _ ->
        {:ok, %{status: :clear, reason: "No flags found"}}
    end
  end

  @impl true
  def check_watchlist(name, _context) do
    if name == "Osama Bin Laden" do
      {:ok, %{status: :hit, source: "OFAC"}}
    else
      {:ok, %{status: :clear}}
    end
  end

  @impl true
  def document_check(_document_image, _type, _context) do
    {:ok, %{
      status: :valid,
      extracted_data: %{
        "name" => "John Doe",
        "dob" => "1980-01-01"
      }
    }}
  end
end
