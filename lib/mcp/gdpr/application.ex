defmodule Mcp.Gdpr.Application do
  @moduledoc """
  GDPR domain application supervisor.

  Manages all GDPR compliance services including:
  - Data retention and anonymization
  - Consent management
  - Audit trail logging
  - Data export functionality
  - Background job processing
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # GDPR Configuration
      Mcp.Gdpr.Config,

      # GDPR Main Supervisor
      {Mcp.Gdpr.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Mcp.Gdpr.Application.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(_changed, _new, _removed) do
    :ok
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end
end