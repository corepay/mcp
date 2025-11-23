defmodule Mcp.Gdpr.Config do
  @moduledoc """
  GDPR configuration management.
  """

  @doc """
  Starts the GDPR config GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  @doc """
  Gets configuration value.
  """
  def get(key, default \\ nil) do
    Application.get_env(:mcp, :gdpr, %{}) |> Map.get(key, default)
  end

  @doc """
  Sets configuration value.
  """
  def set(key, value) do
    current_config = Application.get_env(:mcp, :gdpr, %{})
    new_config = Map.put(current_config, key, value)
    Application.put_env(:mcp, :gdpr, new_config)
    :ok
  end
end