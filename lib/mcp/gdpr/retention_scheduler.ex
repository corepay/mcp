defmodule Mcp.Gdpr.RetentionScheduler do
  @moduledoc """
  Scheduler for GDPR data retention cleanup processes.

  This scheduler handles:
  - Enqueuing periodic retention cleanup jobs
  - Managing retention policy execution schedules
  - Coordinating with Oban for background job processing
  - Providing manual trigger capabilities for testing and admin operations
  """

  use GenServer
  require Logger

  alias Mcp.Jobs.Gdpr.RetentionCleanupWorker
  alias Mcp.Repo
  import Ecto.Query

  @renewal_interval :timer.hours(24)  # Check every 24 hours

  # Client API

  @doc """
  Starts the retention scheduler.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Manually triggers retention policy processing.
  """
  def run_now do
    GenServer.call(__MODULE__, :run_now)
  end

  @doc """
  Triggers retention processing for a specific policy.
  """
  def run_policy(policy_id) when is_binary(policy_id) do
    GenServer.call(__MODULE__, {:run_policy, policy_id})
  end

  @doc """
  Gets the current scheduler status and statistics.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer callbacks

  @impl true
  def init(_init_arg) do
    Logger.info("GDPR RetentionScheduler starting")

    # Schedule the first check
    schedule_next_check()

    state = %{
      started_at: DateTime.utc_now(),
      last_run: nil,
      next_run: DateTime.add(DateTime.utc_now(), @renewal_interval, :second),
      run_count: 0,
      error_count: 0,
      last_error: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:run_now, _from, state) do
    Logger.info("Manual retention cleanup triggered")

    case perform_retention_cleanup() do
      {:ok, result} ->
        new_state = update_state_after_run(state, :success)
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_state = update_state_after_run(state, {:error, reason})
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:run_policy, policy_id}, _from, state) do
    Logger.info("Manual retention cleanup triggered for policy: #{policy_id}")

    case enqueue_policy_cleanup(policy_id) do
      {:ok, job} ->
        new_state = %{state | run_count: state.run_count + 1}
        {:reply, {:ok, %{job_id: job.id, policy_id: policy_id}}, new_state}

      {:error, reason} ->
        new_state = update_state_after_run(state, {:error, reason})
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      last_run: state.last_run,
      next_run: state.next_run,
      run_count: state.run_count,
      error_count: state.error_count,
      last_error: state.last_error,
      uptime: DateTime.diff(DateTime.utc_now(), state.started_at || DateTime.utc_now(), :second)
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_info(:run_scheduled_cleanup, state) do
    Logger.info("Scheduled retention cleanup triggered")

    case perform_retention_cleanup() do
      {:ok, _result} ->
        new_state = update_state_after_run(state, :success)
        schedule_next_check()
        {:noreply, new_state}

      {:error, reason} ->
        new_state = update_state_after_run(state, {:error, reason})
        schedule_next_check()
        {:noreply, new_state}
    end
  end

  # Private functions

  defp schedule_next_check do
    Process.send_after(self(), :run_scheduled_cleanup, @renewal_interval)
  end

  defp perform_retention_cleanup do
    try do
      # Enqueue the retention cleanup job
      job_args = %{"action" => "process_retention_policies"}

      job = RetentionCleanupWorker.new(job_args)
      case Oban.insert(job) do
        {:ok, inserted_job} ->
          Logger.info("Retention cleanup job enqueued: #{inserted_job.id}")
          {:ok, %{job_id: inserted_job.id, status: :enqueued}}

        {:error, reason} ->
          Logger.error("Failed to enqueue retention cleanup job: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Error performing retention cleanup: #{inspect(error)}")
        {:error, {:exception, error}}
    end
  end

  defp enqueue_policy_cleanup(policy_id) do
    try do
      job_args = %{"action" => "process_policy", "policy_id" => policy_id}

      job = RetentionCleanupWorker.new(job_args)
      Oban.insert(job)
    rescue
      error ->
        Logger.error("Error creating policy cleanup job for #{policy_id}: #{inspect(error)}")
        {:error, {:exception, error}}
    end
  end

  defp update_state_after_run(state, result) do
    current_time = DateTime.utc_now()

    case result do
      :success ->
        %{state |
          last_run: current_time,
          next_run: DateTime.add(current_time, @renewal_interval, :second),
          run_count: state.run_count + 1,
          last_error: nil
        }

      {:error, reason} ->
        %{state |
          last_run: current_time,
          next_run: DateTime.add(current_time, @renewal_interval, :second),
          run_count: state.run_count + 1,
          error_count: state.error_count + 1,
          last_error: reason
        }
    end
  end
end