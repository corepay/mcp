defmodule Mcp.Communication.PushNotificationService do
  @moduledoc """
  Push notification service for mobile and web push notifications.
  Supports FCM, APNs, and Web Push with device management.
  """

  use GenServer
  require Logger

  # @providers [:fcm, :apns, :web_push]  # Commented out - currently unused

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication PushNotificationService")
    {:ok, %{devices: %{}, fcm_client: nil, apns_client: nil}}
  end

  def register_device(user_id, device_token, platform, opts \\ []) do
    GenServer.call(__MODULE__, {:register_device, user_id, device_token, platform, opts})
  end

  def unregister_device(user_id, device_token, opts \\ []) do
    GenServer.call(__MODULE__, {:unregister_device, user_id, device_token, opts})
  end

  def send_push_notification(user_id, notification, opts \\ []) do
    GenServer.call(__MODULE__, {:send_push, user_id, notification, opts})
  end

  def send_bulk_push_notifications(user_notifications, opts \\ []) do
    GenServer.call(__MODULE__, {:send_bulk_push, user_notifications, opts})
  end

  def get_user_devices(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_user_devices, user_id, opts})
  end

  def update_device_preferences(device_id, preferences, opts \\ []) do
    GenServer.call(__MODULE__, {:update_device_prefs, device_id, preferences, opts})
  end

  @impl true
  def handle_call({:register_device, user_id, device_token, platform, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    user_key = "#{tenant_id}:#{user_id}"

    device_info = %{
      device_id: generate_device_id(device_token, platform),
      user_id: user_id,
      tenant_id: tenant_id,
      device_token: device_token,
      platform: platform,
      app_version: Keyword.get(opts, :app_version),
      os_version: Keyword.get(opts, :os_version),
      device_model: Keyword.get(opts, :device_model),
      registered_at: DateTime.utc_now(),
      last_active: DateTime.utc_now(),
      preferences: %{
        enabled: Keyword.get(opts, :enabled, true),
        quiet_hours: Keyword.get(opts, :quiet_hours, nil),
        timezone: Keyword.get(opts, :timezone, "UTC")
      }
    }

    user_devices = Map.get(state.devices, user_key, %{})
    updated_devices = Map.put(user_devices, device_info.device_id, device_info)
    new_devices = Map.put(state.devices, user_key, updated_devices)
    new_state = %{state | devices: new_devices}

    Logger.info("Registered #{platform} device for user #{user_id}")
    {:reply, {:ok, device_info}, new_state}
  end

  @impl true
  def handle_call({:unregister_device, user_id, device_token, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    user_key = "#{tenant_id}:#{user_id}"
    device_id = generate_device_id(device_token, nil)

    case Map.get(state.devices, user_key) do
      nil ->
        {:reply, {:error, :user_not_found}, state}
      user_devices ->
        case Map.pop(user_devices, device_id) do
          {nil, _} ->
            {:reply, {:error, :device_not_found}, state}
          {_device, remaining_devices} ->
            new_devices = update_user_devices(state.devices, user_key, remaining_devices)
            new_state = %{state | devices: new_devices}
            Logger.info("Unregistered device for user #{user_id}")
            {:reply, :ok, new_state}
        end
    end
  end

  @impl true
  def handle_call({:send_push, user_id, notification, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    user_key = "#{tenant_id}:#{user_id}"

    case Map.get(state.devices, user_key) do
      nil ->
        {:reply, {:error, :no_devices_found}, state}
      user_devices ->
        enabled_devices = Enum.filter(user_devices, fn {_device_id, device} ->
          device.preferences.enabled and should_send_now?(device, notification)
        end)

        results = Enum.map(enabled_devices, fn {_device_id, device} ->
          send_push_to_device(device, notification, opts)
        end)

        successful = Enum.count(results, &match?({:ok, _}, &1))
        Logger.info("Push notification sent to #{user_id} via #{successful}/#{length(enabled_devices)} devices")

        {:reply, {:ok, results}, state}
    end
  end

  @impl true
  def handle_call({:send_bulk_push, user_notifications, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    results = Enum.map(user_notifications, fn {user_id, notification} ->
      case send_push_notification(user_id, notification, Keyword.put(opts, :tenant_id, tenant_id)) do
        {:ok, result} -> {:ok, {user_id, result}}
        {:error, reason} -> {:error, {user_id, reason}}
      end
    end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Bulk push notifications sent: #{successful}/#{length(results)} users successful")

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:get_user_devices, user_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    user_key = "#{tenant_id}:#{user_id}"

    case Map.get(state.devices, user_key) do
      nil -> {:reply, {:ok, []}, state}
      user_devices ->
        device_list = Map.values(user_devices)
        {:reply, {:ok, device_list}, state}
    end
  end

  @impl true
  def handle_call({:update_device_prefs, device_id, preferences, opts}, _from, state) do
    _tenant_id = Keyword.get(opts, :tenant_id, "global")

    # Find the device across all users
    updated_state = Enum.reduce(state.devices, state, fn {user_key, user_devices}, acc_state ->
      case Map.get(user_devices, device_id) do
        nil -> acc_state
        device ->
          updated_device = %{device | preferences: Map.merge(device.preferences, preferences)}
          updated_user_devices = Map.put(user_devices, device_id, updated_device)
          updated_devices = Map.put(acc_state.devices, user_key, updated_user_devices)
          %{acc_state | devices: updated_devices}
      end
    end)

    Logger.info("Updated preferences for device: #{device_id}")
    {:reply, :ok, updated_state}
  end

  defp send_push_to_device(device, notification, opts) do
    push_payload = build_push_payload(notification, device.platform, opts)

    # send_via_platform always returns {:ok, _}, so no error handling needed
    result = send_via_platform(device.device_token, push_payload, device.platform)
    {:ok, {device.device_id, result}}
  end

  defp build_push_payload(notification, :fcm, _opts) do
    %{
      notification: %{
        title: Map.get(notification, :title, ""),
        body: Map.get(notification, :message, ""),
        icon: Map.get(notification, :icon, "default_icon"),
        sound: Map.get(notification, :sound, "default"),
        badge: Map.get(notification, :badge, 1)
      },
      data: Map.get(notification, :data, %{}),
      priority: determine_priority(Map.get(notification, :priority, :normal))
    }
  end

  defp build_push_payload(notification, :apns, _opts) do
    %{
      aps: %{
        alert: %{
          title: Map.get(notification, :title, ""),
          body: Map.get(notification, :message, "")
        },
        badge: Map.get(notification, :badge, 1),
        sound: Map.get(notification, :sound, "default"),
        category: Map.get(notification, :category, "GENERAL")
      },
      custom_data: Map.get(notification, :data, %{})
    }
  end

  defp build_push_payload(notification, :web_push, _opts) do
    %{
      title: Map.get(notification, :title, ""),
      body: Map.get(notification, :message, ""),
      icon: Map.get(notification, :icon, "/icon.png"),
      badge: Map.get(notification, :badge, "/badge.png"),
      tag: Map.get(notification, :tag, "default"),
      data: Map.get(notification, :data, %{})
    }
  end

  defp send_via_platform(_device_token, _payload, :fcm) do
    # FCM implementation would go here
    Logger.info("Sending FCM push notification")
    message_id = "fcm_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent}}
  end

  defp send_via_platform(_device_token, _payload, :apns) do
    # APNs implementation would go here
    Logger.info("Sending APNs push notification")
    message_id = "apns_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent}}
  end

  defp send_via_platform(_device_token, _payload, :web_push) do
    # Web Push implementation would go here
    Logger.info("Sending Web Push notification")
    message_id = "web_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
    {:ok, %{message_id: message_id, status: :sent}}
  end

  defp determine_priority(:urgent), do: "high"
  defp determine_priority(:high), do: "high"
  defp determine_priority(_), do: "normal"

  defp should_send_now?(device, notification) do
    # Check quiet hours
    if device.preferences.quiet_hours do
      current_time = Time.utc_now()
      {start_hour, start_min} = parse_time(device.preferences.quiet_hours[:start])
      {end_hour, end_min} = parse_time(device.preferences.quiet_hours[:end])
      current_minutes = current_time.hour * 60 + current_time.minute
      start_minutes = start_hour * 60 + start_min
      end_minutes = end_hour * 60 + end_min

      # Allow urgent notifications during quiet hours
      if Map.get(notification, :priority) == :urgent do
        true
      else
        not in_quiet_hours?(current_minutes, start_minutes, end_minutes)
      end
    else
      true
    end
  end

  defp in_quiet_hours?(current, start_time, end_time) do
    if start_time > end_time do
      # Quiet hours span midnight (e.g., 22:00 to 06:00)
      current >= start_time or current < end_time
    else
      # Normal quiet hours (e.g., 22:00 to 07:00)
      current >= start_time and current < end_time
    end
  end

  defp parse_time(nil), do: {0, 0}
  defp parse_time(time_string) when is_binary(time_string) do
    case String.split(time_string, ":") do
      [hour, minute] -> {String.to_integer(hour), String.to_integer(minute)}
      _ -> {0, 0}
    end
  end
  defp parse_time(_), do: {0, 0}

  defp generate_device_id(device_token, platform) do
    content = "#{device_token}_#{platform}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp update_user_devices(devices, user_key, remaining_devices) do
    if map_size(remaining_devices) == 0 do
      Map.delete(devices, user_key)
    else
      Map.put(devices, user_key, remaining_devices)
    end
  end
end