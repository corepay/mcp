defmodule Mcp.Underwriting.CircuitBreaker do
  @moduledoc """
  A simple Circuit Breaker implementation using GenServer.
  Tracks failures per service (vendor) and manages Open/Closed/Half-Open states.
  """

  use GenServer
  require Logger

  # Configuration
  @threshold 5
  @reset_timeout :timer.seconds(60)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Checks if the circuit is open for a given service.
  Returns :ok if closed (allowed), or {:error, :circuit_open} if open.
  """
  def check_circuit(service) do
    GenServer.call(__MODULE__, {:check, service})
  end

  @doc """
  Reports a success for a service. Resets failure count.
  """
  def report_success(service) do
    GenServer.cast(__MODULE__, {:success, service})
  end

  @doc """
  Reports a failure for a service. Increments failure count and may open the circuit.
  """
  def report_failure(service) do
    GenServer.cast(__MODULE__, {:failure, service})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{services: %{}}}
  end

  @impl true
  def handle_call({:check, service}, _from, state) do
    service_state = get_service_state(state, service)

    case service_state.status do
      :open ->
        if System.monotonic_time(:millisecond) > service_state.reset_at do
          # Timeout expired, try half-open (allow this request)
          # We don't change state to half-open explicitly here, we just allow it.
          # If it succeeds, it will reset. If it fails, it will update reset_at.
          {:reply, :ok, state}
        else
          {:reply, {:error, :circuit_open}, state}
        end

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_cast({:success, service}, state) do
    # Reset failures on success
    new_services = Map.put(state.services, service, %{status: :closed, failures: 0, reset_at: nil})
    {:noreply, %{state | services: new_services}}
  end

  @impl true
  def handle_cast({:failure, service}, state) do
    service_state = get_service_state(state, service)
    new_failures = service_state.failures + 1

    new_service_state =
      if new_failures >= @threshold do
        Logger.warning("Circuit Breaker OPEN for #{service}. Failures: #{new_failures}")
        %{status: :open, failures: new_failures, reset_at: System.monotonic_time(:millisecond) + @reset_timeout}
      else
        %{service_state | failures: new_failures}
      end

    new_services = Map.put(state.services, service, new_service_state)
    {:noreply, %{state | services: new_services}}
  end

  defp get_service_state(state, service) do
    Map.get(state.services, service, %{status: :closed, failures: 0, reset_at: nil})
  end
end
