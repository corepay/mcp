defmodule Mcp.Underwriting.CircuitBreaker do
  @moduledoc """
  Simple circuit breaker implementation using GenServer.
  Tracks failures per service and opens the circuit when threshold is reached.
  """

  use GenServer
  require Logger

  # Configuration
  @failure_threshold 5
  @reset_timeout_ms 60_000 # 1 minute

  # Client API

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def check_circuit(service_name) do
    GenServer.call(__MODULE__, {:check_circuit, service_name})
  end

  def report_failure(service_name) do
    GenServer.cast(__MODULE__, {:report_failure, service_name})
  end

  def report_success(service_name) do
    GenServer.cast(__MODULE__, {:report_success, service_name})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:check_circuit, service_name}, _from, state) do
    case Map.get(state, service_name) do
      %{status: :open, open_until: open_until} ->
        if DateTime.compare(DateTime.utc_now(), open_until) == :gt do
          # Half-open state (allow one request to check)
          # For simplicity, we'll just close it on check if timeout expired
          # In a real implementation, we'd go to half-open
          new_state = Map.put(state, service_name, %{status: :closed, failures: 0})
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :circuit_open}, state}
        end

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_cast({:report_failure, service_name}, state) do
    current_service_state = Map.get(state, service_name, %{status: :closed, failures: 0})
    
    new_failures = current_service_state.failures + 1
    
    new_service_state = 
      if new_failures >= @failure_threshold do
        Logger.warning("Circuit breaker opening for service: #{service_name}")
        %{
          status: :open, 
          failures: new_failures,
          open_until: DateTime.add(DateTime.utc_now(), @reset_timeout_ms, :millisecond)
        }
      else
        %{current_service_state | failures: new_failures}
      end

    {:noreply, Map.put(state, service_name, new_service_state)}
  end

  @impl true
  def handle_cast({:report_success, service_name}, state) do
    # Reset failures on success
    new_state = Map.put(state, service_name, %{status: :closed, failures: 0})
    {:noreply, new_state}
  end
end
