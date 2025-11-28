defmodule Mcp.Communication.SmsService do
  @moduledoc """
  SMS service for sending text messages.
  Logs to console in development.
  """

  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication SmsService")
    {:ok, %{rate_limits: %{}}}
  end

  def send_sms(to, message, opts \\ []) do
    GenServer.call(__MODULE__, {:send_sms, to, message, opts})
  end

  def send_bulk_sms(recipients, message, opts \\ []) do
    GenServer.call(__MODULE__, {:send_bulk_sms, recipients, message, opts})
  end

  def get_sms_status(_message_id, _opts \\ []) do
    {:ok, %{status: :delivered, updated_at: DateTime.utc_now()}}
  end

  def verify_phone_number(phone_number, _opts \\ []) do
    Logger.info("Verifying phone number: #{phone_number} (Console Mock)")
    {:ok, %{verification_id: "console_verify_#{Ecto.UUID.generate()}", status: :pending}}
  end

  def check_rate_limit(tenant_id, phone_number, opts \\ []) do
    GenServer.call(__MODULE__, {:check_rate_limit, tenant_id, phone_number, opts})
  end

  @impl true
  def handle_call({:send_sms, to, message, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    case check_rate_limit_internal(state.rate_limits, tenant_id, to, opts) do
      {:ok, new_limits} ->
        Logger.info("""
        [SMS SENT]
        To: #{to}
        Message: #{message}
        Tenant: #{tenant_id}
        """)

        {:reply, {:ok, %{status: :sent, message_id: "console_#{Ecto.UUID.generate()}"}},
         %{state | rate_limits: new_limits}}

      {:error, :rate_limited} ->
        {:reply, {:error, :rate_limited}, state}
    end
  end

  @impl true
  def handle_call({:send_bulk_sms, recipients, message, opts}, _from, state) do
    _tenant_id = Keyword.get(opts, :tenant_id, "global")

    results =
      Enum.with_index(recipients)
      |> Enum.map(fn {recipient, index} ->
        Logger.info("[BULK SMS] To: #{recipient} | Msg: #{message}")
        {:ok, {index, :sent}}
      end)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:check_rate_limit, tenant_id, phone_number, opts}, _from, state) do
    case check_rate_limit_internal(state.rate_limits, tenant_id, phone_number, opts) do
      {:ok, _limits} -> {:reply, {:ok, :allowed}, state}
      {:error, :rate_limited} -> {:reply, {:ok, :rate_limited}, state}
    end
  end

  defp check_rate_limit_internal(rate_limits, tenant_id, phone_number, opts) do
    key = "#{tenant_id}:#{phone_number}"
    max_per_hour = Keyword.get(opts, :max_per_hour, 10)
    max_per_day = Keyword.get(opts, :max_per_day, 100)

    now = DateTime.utc_now()
    current_limits = Map.get(rate_limits, key, %{hourly: [], daily: []})

    hour_ago = DateTime.add(now, -3600, :second)
    day_ago = DateTime.add(now, -86_400, :second)

    hourly_counts = Enum.filter(current_limits.hourly, &(DateTime.compare(&1, hour_ago) != :lt))
    daily_counts = Enum.filter(current_limits.daily, &(DateTime.compare(&1, day_ago) != :lt))

    cond do
      length(hourly_counts) >= max_per_hour ->
        {:error, :rate_limited}

      length(daily_counts) >= max_per_day ->
        {:error, :rate_limited}

      true ->
        new_limits = %{
          hourly: [now | hourly_counts],
          daily: [now | daily_counts]
        }

        updated_rate_limits = Map.put(rate_limits, key, new_limits)
        {:ok, updated_rate_limits}
    end
  end
end
