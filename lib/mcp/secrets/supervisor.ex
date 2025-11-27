defmodule Mcp.Secrets.Supervisor do
  @moduledoc """
  Secrets domain supervisor.
  Manages Vault clients, encryption services, and credential managers.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Mcp.Secrets,
      Mcp.Secrets.EncryptionService,
      Mcp.Secrets.CredentialManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
