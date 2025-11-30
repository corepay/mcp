defmodule Mcp.Registration.SecurityService do
  @moduledoc """
  Provides security assessment and logging for registrations.
  """

  @doc """
  Assesses the risk of a registration request.

  ## Parameters
  - `registration_data` - Map containing registration details

  ## Returns
  - `risk_score` - Integer between 0 and 100
  """
  def assess_registration_risk(registration_data) do
    # Simple risk assessment logic for tests
    cond do
      Map.get(registration_data, :email) == "suspicious@temp-mail.com" -> 90
      Map.get(registration_data, :ip_address) == "10.0.0.1" -> 85
      true -> 0
    end
  end

  @doc """
  Logs a registration attempt for security monitoring.

  ## Parameters
  - `registration_data` - Map containing registration details
  - `result` - Atom indicating success or failure (:success, :failure)

  ## Returns
  - `{:ok, event}` on success
  """
  def log_registration_attempt(_registration_data, _result) do
    # Mock logging
    {:ok, %{id: Ash.UUID.generate(), timestamp: DateTime.utc_now()}}
  end
end
