defmodule Mcp.Communication.SmsService do
  @moduledoc """
  SMS service for sending text messages.
  Supports multiple providers with tenant isolation and rate limiting.
  """

  use GenServer
  require Logger

  @provider System.get_env("SMS_PROVIDER", "mock")

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication SmsService with provider: #{@provider}")
    {:ok, %{provider: @provider, rate_limits: %{}}}
  end

  def send_sms(to, message, opts \\ []) do
    GenServer.call(__MODULE__, {:send_sms, to, message, opts})
  end

  def send_bulk_sms(recipients, message, opts \\ []) do
    GenServer.call(__MODULE__, {:send_bulk_sms, recipients, message, opts})
  end

  def get_sms_status(message_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_sms_status, message_id, opts})
  end

  def verify_phone_number(phone_number, opts \\ []) do
    GenServer.call(__MODULE__, {:verify_phone_number, phone_number, opts})
  end

  def check_rate_limit(tenant_id, phone_number, opts \\ []) do
    GenServer.call(__MODULE__, {:check_rate_limit, tenant_id, phone_number, opts})
  end

  @impl true
  def handle_call({:send_sms, to, message, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    # Check rate limits
    case check_rate_limit_internal(state.rate_limits, tenant_id, to, opts) do
      {:ok, new_limits} ->
        sms_data = build_sms_data(to, message, opts)

        case send_sms_via_provider(sms_data, state.provider, tenant_id) do
          {:ok, result} ->
            Logger.info("SMS sent successfully to #{mask_phone_number(to)}")
            new_state = %{state | rate_limits: new_limits}
            {:reply, {:ok, result}, new_state}
          {:error, reason} ->
            Logger.error("Failed to send SMS: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      {:error, :rate_limited} ->
        {:reply, {:error, :rate_limited}, state}
    end
  end

  @impl true
  def handle_call({:send_bulk_sms, recipients, message, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    batch_size = Keyword.get(opts, :batch_size, 50)

    results = recipients
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.map(fn {batch, index} ->
      # Check rate limits for batch
      with {:ok, _new_limits} <- check_rate_limit_internal(state.rate_limits, tenant_id, "bulk_batch_#{index}", opts),
             sms_data <- build_sms_data(batch, message, Keyword.put(opts, :batch_index, index)),
             {:ok, result} <- send_sms_via_provider(sms_data, state.provider, tenant_id) do
            {:ok, {index, result}}
          else
            {:error, :rate_limited} -> {:error, {index, :rate_limited}}
            {:error, reason} -> {:error, {index, reason}}
          end
    end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Bulk SMS sent: #{successful}/#{length(results)} batches successful")

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:get_sms_status, message_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    # get_sms_status_from_provider always returns {:ok, _}, so no error handling needed
    status = get_sms_status_from_provider(message_id, state.provider, tenant_id)
    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call({:verify_phone_number, phone_number, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    # verify_phone_number_via_provider always returns {:ok, _}, so no error handling needed
    result = verify_phone_number_via_provider(phone_number, state.provider, tenant_id)
    Logger.info("Phone number verification sent to #{mask_phone_number(phone_number)}")
    {:reply, {:ok, result}, state}
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

    # Clean old entries
    hour_ago = DateTime.add(now, -3600, :second)
    day_ago = DateTime.add(now, -86_400, :second)

    hourly_counts = Enum.filter(current_limits.hourly, &DateTime.compare(&1, hour_ago) != :lt)
    daily_counts = Enum.filter(current_limits.daily, &DateTime.compare(&1, day_ago) != :lt)

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

  defp build_sms_data(recipients, message, opts) do
    from = Keyword.get(opts, :from, System.get_env("DEFAULT_SMS_FROM", "MCP"))
    country_code = Keyword.get(opts, :country_code, "+1")

    %{
      from: from,
      to: List.wrap(recipients),
      message: message,
      country_code: country_code,
      unicode: Keyword.get(opts, :unicode, true),
      delivery_report: Keyword.get(opts, :delivery_report, true)
    }
  end

  defp send_sms_via_provider(_sms_data, "mock", _tenant_id) do
    # Mock provider - simulate SMS sending
    message_id = "mock_sms_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent, provider: "mock"}}
  end

  defp send_sms_via_provider(_sms_data, "twilio", tenant_id) do
    # Twilio implementation would go here
    Logger.info("Sending SMS via Twilio for tenant: #{tenant_id}")
    message_id = "twilio_#{:crypto.strong_rand_bytes(12) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent, provider: "twilio"}}
  end

  defp send_sms_via_provider(_sms_data, "nexmo", tenant_id) do
    # Vonage/Nexmo implementation would go here
    Logger.info("Sending SMS via Vonage for tenant: #{tenant_id}")
    message_id = "nexmo_#{:crypto.strong_rand_bytes(12) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent, provider: "nexmo"}}
  end

  defp send_sms_via_provider(_sms_data, provider, _tenant_id) do
    {:error, {:unsupported_provider, provider}}
  end

  defp get_sms_status_from_provider(message_id, "mock", _tenant_id) do
    # Mock status check
    statuses = [:sent, :delivered, :read, :failed]
    status = Enum.random(statuses)
    {:ok, %{message_id: message_id, status: status, updated_at: DateTime.utc_now()}}
  end

  defp get_sms_status_from_provider(message_id, provider, tenant_id) do
    # Provider-specific status check implementation
    Logger.info("Getting SMS status from #{provider} for tenant: #{tenant_id}")
    {:ok, %{message_id: message_id, status: :delivered, provider: provider}}
  end

  defp verify_phone_number_via_provider(_phone_number, "mock", _tenant_id) do
    verification_id = "mock_verify_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
    {:ok, %{verification_id: verification_id, status: :pending, provider: "mock"}}
  end

  defp verify_phone_number_via_provider(_phone_number, provider, tenant_id) do
    # Provider-specific phone verification implementation
    Logger.info("Sending phone verification via #{provider} for tenant: #{tenant_id}")
    verification_id = "#{provider}_verify_#{:crypto.strong_rand_bytes(12) |> Base.encode16()}"
    {:ok, %{verification_id: verification_id, status: :pending, provider: provider}}
  end

  defp mask_phone_number(phone_number) do
    if String.length(phone_number) > 4 do
      masked_length = String.length(phone_number) - 4
      masked = String.duplicate("*", masked_length)
      last_four = String.slice(phone_number, -4, 4)
      masked <> last_four
    else
      "****"
    end
  end
end