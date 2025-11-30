defmodule Mcp.Utils.CircuitBreaker do
  @moduledoc """
  A simple circuit breaker implementation using a GenServer.
  Tracks failures and opens the circuit when a threshold is reached.
  """
  use GenServer
  require Logger

  @name __MODULE__
  @failure_threshold 5
  @reset_timeout 30_000 # 30 seconds

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def execute(service, fun) do
    if open?(service) do
      {:error, :circuit_open}
    else
      try do
        case fun.() do
          {:ok, result} ->
            record_success(service)
            {:ok, result}
          {:error, reason} ->
            record_failure(service)
            {:error, reason}
          result ->
            record_success(service)
            {:ok, result}
        end
      rescue
        e ->
          record_failure(service)
          {:error, e}
      end
    end
  end

  def open?(service) do
    GenServer.call(@name, {:open?, service})
  end

  def record_success(service) do
    GenServer.cast(@name, {:success, service})
  end

  def record_failure(service) do
    GenServer.cast(@name, {:failure, service})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{services: %{}}}
  end

  @impl true
  def handle_call({:open?, service}, _from, state) do
    service_state = Map.get(state.services, service, %{failures: 0, state: :closed})
    
    is_open = case service_state.state do
      :open -> 
        # Check if reset timeout has passed
        if System.monotonic_time(:millisecond) > service_state.reset_at do
          false # Half-open effectively, allow one request
        else
          true
        end
      _ -> false
    end

    {:reply, is_open, state}
  end

  @impl true
  def handle_cast({:success, service}, state) do
    new_services = Map.update(state.services, service, %{failures: 0, state: :closed}, fn _ ->
      %{failures: 0, state: :closed}
    end)
    {:noreply, %{state | services: new_services}}
  end

  @impl true
  def handle_cast({:failure, service}, state) do
    new_services = Map.update(state.services, service, %{failures: 1, state: :closed}, fn current ->
      new_failures = current.failures + 1
      if new_failures >= @failure_threshold do
        Logger.warning("Circuit breaker opening for service: #{service}")
        %{failures: new_failures, state: :open, reset_at: System.monotonic_time(:millisecond) + @reset_timeout}
      else
        %{current | failures: new_failures}
      end
    end)
    {:noreply, %{state | services: new_services}}
  end
end
