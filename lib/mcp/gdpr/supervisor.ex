defmodule Mcp.Gdpr.Supervisor do
  @moduledoc """
  Main GDPR supervisor managing all compliance-related processes.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      # Core GDPR Services
      Mcp.Gdpr.AuditTrail,
      Mcp.Gdpr.Consent,
      Mcp.Gdpr.DataRetention,
      Mcp.Gdpr.Anonymizer,
      Mcp.Gdpr.Export
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
