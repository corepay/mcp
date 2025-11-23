defmodule Mcp.Gdpr.Supervisor do
  @moduledoc """
  Main GDPR domain supervisor.

  Coordinates all GDPR compliance services and manages their lifecycle.
  """

  use Supervisor

  @impl true
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # GDPR Core Services
      Mcp.Gdpr.ConsentManager,
      Mcp.Gdpr.AuditTrail,
      Mcp.Gdpr.DataRetention,
      Mcp.Gdpr.Anonymizer,
      Mcp.Gdpr.ExportGenerator,
      Mcp.Gdpr.ComplianceMonitor,

      # Background Job Processors
      {Oban, Application.get_env(:mcp, Oban)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end