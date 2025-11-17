defmodule Mcp.Communication.Supervisor do
  @moduledoc """
  Communication domain supervisor.
  Manages email services, SMS providers, and notification systems.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Mcp.Communication.EmailService,
      Mcp.Communication.SmsService,
      Mcp.Communication.NotificationService,
      Mcp.Communication.PushNotificationService
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end