defmodule Mcp.Communication.NotificationService do
  @moduledoc """
  Notification service for managing user notifications.
  Handles in-app, email, SMS, and push notifications with preferences.
  """

  use GenServer
  require Logger

  alias Mcp.Communication.EmailService
  alias Mcp.Communication.SmsService

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication NotificationService")
    {:ok, %{user_preferences: %{}}}
  end

  def send_notification(user_id, notification, opts \\ []) do
    GenServer.call(__MODULE__, {:send_notification, user_id, notification, opts})
  end

  def send_bulk_notifications(user_notifications, opts \\ []) do
    GenServer.call(__MODULE__, {:send_bulk_notifications, user_notifications, opts})
  end

  def update_user_preferences(user_id, preferences, opts \\ []) do
    GenServer.call(__MODULE__, {:update_preferences, user_id, preferences, opts})
  end

  def get_user_preferences(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_preferences, user_id, opts})
  end

  def mark_notification_read(notification_id, user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:mark_read, notification_id, user_id, opts})
  end

  def get_user_notifications(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_user_notifications, user_id, opts})
  end

  @impl true
  def handle_call({:send_notification, user_id, notification, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    preferences_key = "#{tenant_id}:#{user_id}"

    preferences = Map.get(state.user_preferences, preferences_key, get_default_preferences())

    # Determine which channels to use based on preferences and notification priority
    channels = determine_notification_channels(notification, preferences, opts)

    results =
      Enum.map(channels, fn channel ->
        send_via_channel(user_id, notification, channel, Keyword.put(opts, :tenant_id, tenant_id))
      end)

    # Store notification for in-app display
    notification_id = store_notification(user_id, notification, tenant_id)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Notification sent to #{user_id} via #{successful}/#{length(channels)} channels")

    {:reply, {:ok, %{notification_id: notification_id, results: results}}, state}
  end

  @impl true
  def handle_call({:send_bulk_notifications, user_notifications, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")

    results =
      Enum.map(user_notifications, fn {user_id, notification} ->
        case send_notification(user_id, notification, Keyword.put(opts, :tenant_id, tenant_id)) do
          {:ok, result} -> {:ok, {user_id, result}}
          {:error, reason} -> {:error, {user_id, reason}}
        end
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Bulk notifications sent: #{successful}/#{length(results)} users successful")

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:update_preferences, user_id, preferences, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    preferences_key = "#{tenant_id}:#{user_id}"

    # Merge with default preferences
    merged_preferences = Map.merge(get_default_preferences(), preferences)

    new_user_preferences = Map.put(state.user_preferences, preferences_key, merged_preferences)
    new_state = %{state | user_preferences: new_user_preferences}

    Logger.info("Updated notification preferences for user: #{user_id}")
    {:reply, {:ok, merged_preferences}, new_state}
  end

  @impl true
  def handle_call({:get_preferences, user_id, opts}, _from, state) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    preferences_key = "#{tenant_id}:#{user_id}"

    preferences = Map.get(state.user_preferences, preferences_key, get_default_preferences())
    {:reply, {:ok, preferences}, state}
  end

  @impl true
  def handle_call({:mark_read, notification_id, user_id, opts}, _from, state) do
    _tenant_id = Keyword.get(opts, :tenant_id, "global")

    # In a real implementation, would update database
    Logger.info("Marked notification #{notification_id} as read for user #{user_id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_user_notifications, user_id, opts}, _from, state) do
    _tenant_id = Keyword.get(opts, :tenant_id, "global")
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    # In a real implementation, would query database
    notifications = [
      %{
        id: "notif_1",
        user_id: user_id,
        title: "Welcome to MCP Platform",
        message: "Your account has been successfully created",
        type: "system",
        created_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        read: false
      }
    ]

    paginated_notifications = Enum.slice(notifications, offset, limit)
    {:reply, {:ok, paginated_notifications}, state}
  end

  defp determine_notification_channels(notification, preferences, opts) do
    priority = Map.get(notification, :priority, :normal)
    force_channels = Keyword.get(opts, :channels, [])

    channels =
      cond do
        force_channels != [] -> force_channels
        priority == :urgent -> [:push, :sms, :email, :in_app]
        priority == :high -> [:push, :email, :in_app]
        priority == :normal -> [:push, :in_app]
        true -> [:in_app]
      end

    # Filter based on user preferences
    Enum.filter(channels, fn channel ->
      Map.get(preferences, channel, true) and Map.get(preferences, "#{channel}_enabled", true)
    end)
  end

  defp send_via_channel(user_id, notification, :email, opts) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    email = get_user_email(user_id, tenant_id)

    email_data = %{
      to: [email],
      subject: Map.get(notification, :title, "Notification"),
      body: Map.get(notification, :message, ""),
      html: Map.get(notification, :html_content, false)
    }

    case EmailService.send_email(
           email_data.to,
           email_data.subject,
           email_data.body,
           opts
         ) do
      {:ok, result} -> {:ok, {:email, result}}
      error -> error
    end
  end

  defp send_via_channel(user_id, notification, :sms, opts) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    phone = get_user_phone(user_id, tenant_id)

    message = "#{Map.get(notification, :title, "")}: #{Map.get(notification, :message, "")}"

    case SmsService.send_sms(phone, message, opts) do
      {:ok, result} -> {:ok, {:sms, result}}
      error -> error
    end
  end

  defp send_via_channel(user_id, _notification, :push, _opts) do
    # Push notification implementation would go here
    Logger.info("Sending push notification to user #{user_id}")
    {:ok, {:push, %{message_id: "push_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"}}}
  end

  defp send_via_channel(_user_id, _notification, :in_app, _opts) do
    # In-app notifications are stored in the database
    {:ok, {:in_app, %{stored: true}}}
  end

  defp store_notification(user_id, notification, tenant_id) do
    notification_id = "notif_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"

    # In a real implementation, would store in database
    _stored_notification = %{
      id: notification_id,
      user_id: user_id,
      tenant_id: tenant_id,
      title: Map.get(notification, :title),
      message: Map.get(notification, :message),
      type: Map.get(notification, :type, "system"),
      priority: Map.get(notification, :priority, :normal),
      created_at: DateTime.utc_now(),
      read: false
    }

    Logger.debug("Stored notification: #{notification_id}")
    notification_id
  end

  defp get_user_email(_user_id, _tenant_id) do
    # In a real implementation, would query user database
    "user@example.com"
  end

  defp get_user_phone(_user_id, _tenant_id) do
    # In a real implementation, would query user database
    "+15551234567"
  end

  defp get_default_preferences do
    %{
      email: true,
      email_enabled: true,
      sms: false,
      sms_enabled: true,
      push: true,
      push_enabled: true,
      in_app: true,
      in_app_enabled: true,
      quiet_hours_start: nil,
      quiet_hours_end: nil,
      timezone: "UTC"
    }
  end
end
