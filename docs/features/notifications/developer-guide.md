# Notifications & Communications System - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP notifications and communications system. Includes actual API endpoints, code patterns, integration examples, and multi-tenant communication implementation based on the real codebase.

## System Architecture

The notifications system uses a GenServer-based architecture with multi-channel communication capabilities:

- **NotificationService**: Central GenServer managing notification routing and preferences
- **EmailService**: Email delivery with multiple provider support (mock, SendGrid, SES)
- **SmsService**: SMS message delivery (implementation in progress)
- **PushNotificationService**: Push notification delivery for mobile apps
- **Multi-tenant Support**: Tenant-isolated communication with preferences per tenant

## Core Notification Service API

### NotificationService Functions

The `Mcp.Communication.NotificationService` GenServer provides these actual functions:

```elixir
# Send single notification to a user
NotificationService.send_notification(user_id, notification, opts \\ [])

# Send bulk notifications to multiple users
NotificationService.send_bulk_notifications(user_notifications, opts \\ [])

# Update user notification preferences
NotificationService.update_user_preferences(user_id, preferences, opts \\ [])

# Get user notification preferences
NotificationService.get_user_preferences(user_id, opts \\ [])

# Mark notification as read
NotificationService.mark_notification_read(notification_id, user_id, opts \\ [])

# Get user notifications with pagination
NotificationService.get_user_notifications(user_id, opts \\ [])
```

### Notification Data Structure

```elixir
notification = %{
  title: "Welcome to MCP Platform",
  message: "Your account has been successfully created",
  type: "system",           # system, marketing, security, billing
  priority: :normal,         # urgent, high, normal, low
  html_content: "<h1>Welcome!</h1><p>Your account is ready.</p>", # optional
  metadata: %{              # optional additional data
    action_url: "/dashboard",
    action_text: "Get Started"
  }
}
```

### User Preferences Structure

```elixir
preferences = %{
  email: true,              # Email notifications enabled
  email_enabled: true,      # Email channel operational
  sms: false,               # SMS notifications enabled
  sms_enabled: true,        # SMS channel operational
  push: true,               # Push notifications enabled
  push_enabled: true,       # Push channel operational
  in_app: true,             # In-app notifications enabled
  in_app_enabled: true,     # In-app channel operational
  quiet_hours_start: nil,   # Quiet hours start time (e.g., "22:00")
  quiet_hours_end: nil,     # Quiet hours end time (e.g., "08:00")
  timezone: "UTC"           # User timezone for quiet hours
}
```

## Email Service Implementation

### EmailService Functions

The `Mcp.Communication.EmailService` GenServer provides these actual functions:

```elixir
# Send basic email
EmailService.send_email(to, subject, body, opts \\ [])

# Send templated email with variable substitution
EmailService.send_template_email(to, template_id, template_data, opts \\ [])

# Send bulk emails with batching
EmailService.send_bulk_emails(recipients, subject, body, opts \\ [])

# Register email template for reuse
EmailService.register_template(template_id, subject_template, body_template, opts \\ [])

# Get email delivery status
EmailService.get_email_status(message_id, opts \\ [])
```

### Email Providers and Configuration

The system supports multiple email providers configured via environment variables:

```elixir
# Set email provider in environment
@provider System.get_env("EMAIL_PROVIDER", "mock")

# Configure default from email
System.get_env("DEFAULT_FROM_EMAIL", "noreply@mcp-platform.local")
```

**Supported Providers:**
- **mock**: Mock provider for testing and development
- **sendgrid**: SendGrid integration for production
- **ses**: AWS SES integration for production

### Email Template Usage

```elixir
# Register a template
EmailService.register_template(
  "welcome_email",
  "Welcome to {{company_name}}!",
  "Hello {{user_name}}, welcome to {{company_name}}. Your account is ready to use.",
  tenant_id: "tenant_123"
)

# Send templated email
EmailService.send_template_email(
  ["user@example.com"],
  "welcome_email",
  %{
    user_name: "John Doe",
    company_name: "MCP Platform"
  },
  tenant_id: "tenant_123"
)
```

### Bulk Email Implementation

```elixir
# Send bulk emails with automatic batching
recipients = [
  "user1@example.com",
  "user2@example.com",
  "user3@example.com"
  # ... potentially thousands more
]

EmailService.send_bulk_emails(
  recipients,
  "Important Update",
  "This is an important message for all users.",
  [
    batch_size: 100,        # Send in batches of 100
    tenant_id: "tenant_123",
    tracking: true
  ]
)
```

## Multi-Tenant Communication

### Tenant Isolation

All notification services support tenant isolation through the `tenant_id` option:

```elixir
# Send notification with tenant context
NotificationService.send_notification(
  user_id,
  notification,
  tenant_id: "acme_corp"
)

# Send email with tenant-specific templates
EmailService.send_template_email(
  ["user@acme.com"],
  "welcome_email",
  template_data,
  tenant_id: "acme_corp"
)
```

### Tenant-Specific Preferences

User preferences are stored with tenant keys: `"#{tenant_id}:#{user_id}"`

```elixir
# Update preferences for specific tenant
NotificationService.update_user_preferences(
  "user_123",
  %{email: true, sms: false},
  tenant_id: "acme_corp"
)

# Preferences are isolated per tenant
acme_prefs = NotificationService.get_user_preferences("user_123", tenant_id: "acme_corp")
other_prefs = NotificationService.get_user_preferences("user_123", tenant_id: "other_corp")
```

## Channel Routing Logic

### Notification Channel Selection

The system automatically determines which channels to use based on:

1. **Notification Priority**
2. **User Preferences**
3. **Force Channel Options**
4. **Channel Availability**

```elixir
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
    Map.get(preferences, channel, true) and
    Map.get(preferences, "#{channel}_enabled", true)
  end)
end
```

### Quiet Hours Support

The system respects user-defined quiet hours:

```elixir
# User preferences with quiet hours
preferences = %{
  quiet_hours_start: "22:00",
  quiet_hours_end: "08:00",
  timezone: "America/New_York"
}

# During quiet hours, non-urgent notifications are delayed
# Urgent notifications are always delivered
```

## Integration Examples

### User Registration Notification

```elixir
defmodule McpWeb.UserRegistrationController do
  use McpWeb, :controller

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        # Send welcome notification
        welcome_notification = %{
          title: "Welcome to MCP Platform",
          message: "Your account has been successfully created",
          type: "system",
          priority: :normal,
          html_content: generate_welcome_html(user)
        }

        NotificationService.send_notification(
          user.id,
          welcome_notification,
          tenant_id: conn.assigns.current_tenant.id
        )

        # Send welcome email
        EmailService.send_template_email(
          [user.email],
          "welcome_email",
          %{
            user_name: user.name,
            login_url:Routes.session_url(conn, :new)
          },
          tenant_id: conn.assigns.current_tenant.id
        )

        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.user_path(conn, :show, user))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
```

### Security Alert Notification

```elixir
defmodule Mcp.Security.AlertService do
  def send_security_alert(user_id, alert_type, details) do
    notification = %{
      title: "Security Alert",
      message: "Suspicious activity detected on your account",
      type: "security",
      priority: :urgent,
      metadata: %{
        alert_type: alert_type,
        ip_address: details.ip_address,
        timestamp: DateTime.utc_now()
      }
    }

    opts = [
      channels: [:push, :sms, :email], # Force all channels for security
      tenant_id: details.tenant_id
    ]

    NotificationService.send_notification(user_id, notification, opts)
  end
end
```

### Bulk Marketing Campaign

```elixir
defmodule Mcp.Marketing.CampaignService do
  def send_promotional_email(tenant_id, campaign) do
    # Get all opted-in users for the tenant
    users = get_marketing_users(tenant_id)

    recipients = Enum.map(users, & &1.email)

    EmailService.send_bulk_emails(
      recipients,
      campaign.subject,
      campaign.body,
      [
        tenant_id: tenant_id,
        batch_size: 50,
        html: campaign.html_content,
        tracking: true,
        reply_to: campaign.reply_to
      ]
    )
  end

  def send_promotional_notification(tenant_id, notification) do
    users = get_marketing_users(tenant_id)

    user_notifications = Enum.map(users, fn user ->
      {user.id, notification}
    end)

    NotificationService.send_bulk_notifications(
      user_notifications,
      tenant_id: tenant_id
    )
  end
end
```

## Testing Notification System

### Unit Tests

```elixir
defmodule Mcp.Communication.NotificationServiceTest do
  use ExUnit.Case
  alias Mcp.Communication.NotificationService

  describe "send_notification/3" do
    test "sends notification via appropriate channels" do
      user_id = "test_user"
      notification = %{
        title: "Test Notification",
        message: "This is a test",
        priority: :normal
      }

      assert {:ok, %{notification_id: _id, results: results}} =
        NotificationService.send_notification(user_id, notification)

      # Should send via push and in-app for normal priority
      assert length(results) == 2
      assert {:ok, {:push, _}} = Enum.find(results, &match?({:ok, {:push, _}}, &1))
      assert {:ok, {:in_app, _}} = Enum.find(results, &match?({:ok, {:in_app, _}}, &1))
    end

    test "respects user preferences" do
      user_id = "test_user"

      # Disable email for user
      NotificationService.update_user_preferences(
        user_id,
        %{email: false, sms: false},
        tenant_id: "test_tenant"
      )

      notification = %{
        title: "Urgent Notification",
        message: "This is urgent",
        priority: :urgent
      }

      assert {:ok, %{results: results}} =
        NotificationService.send_notification(
          user_id,
          notification,
          tenant_id: "test_tenant"
        )

      # Should not include email or SMS channels
      channels = Enum.map(results, fn {:ok, {channel, _}} -> channel end)
      refute :email in channels
      refute :sms in channels
    end
  end
end
```

### Email Service Tests

```elixir
defmodule Mcp.Communication.EmailServiceTest do
  use ExUnit.Case
  alias Mcp.Communication.EmailService

  describe "send_template_email/4" do
    test "renders template with data" do
      # Register template
      {:ok, template} = EmailService.register_template(
        "test_template",
        "Hello {{name}}!",
        "Welcome {{name}}, your account is ready.",
        tenant_id: "test_tenant"
      )

      # Send templated email
      result = EmailService.send_template_email(
        ["test@example.com"],
        "test_template",
        %{name: "John"},
        tenant_id: "test_tenant"
      )

      assert {:ok, _} = result
    end

    test "handles missing template" do
      result = EmailService.send_template_email(
        ["test@example.com"],
        "nonexistent_template",
        %{name: "John"},
        tenant_id: "test_tenant"
      )

      assert {:error, :template_not_found} = result
    end
  end
end
```

## Performance Considerations

### Bulk Operations

- **Batch Processing**: Large email sends are processed in configurable batches
- **Memory Management**: Bulk notifications don't load all data into memory
- **Rate Limiting**: Built-in rate limiting prevents overwhelming external services

### Multi-Tenant Isolation

- **Preference Storage**: Tenant-scoped preferences prevent cross-tenant data leakage
- **Template Isolation**: Templates are isolated per tenant
- **Provider Configuration**: Tenant-specific provider configurations

### Monitoring and Observability

```elixir
# Enable notification metrics
:telemetry.execute([:mcp, :notification, :sent], %{count: 1}, %{
  channels: [:email, :push],
  tenant_id: "acme_corp"
})

:telemetry.execute([:mcp, :email, :sent], %{count: 100}, %{
  provider: "sendgrid",
  tenant_id: "acme_corp"
})
```

This developer guide reflects the actual implementation of the MCP notifications and communications system, providing accurate code examples and API usage patterns based on the real codebase structure.