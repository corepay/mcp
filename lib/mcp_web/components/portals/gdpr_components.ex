defmodule McpWeb.Portals.GdprComponents do
  @moduledoc """
  Reusable GDPR-specific UI components.

  This module provides components for GDPR compliance features including:
  - Data export request forms
  - Account deletion requests
  - Consent management
  - Audit trail displays
  - Status indicators and notifications
  """

  use Phoenix.Component

  # Import the icon function from CoreComponents
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a data export request form.
  """
  attr :current_user, :map, required: true
  attr :loading, :boolean, default: false

  def data_export_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="w-6 h-6" />
        <div>
          <h3 class="font-bold">Your Right to Data Portability</h3>
          <div class="text-sm">
            You can request a copy of all your personal data in a machine-readable format.
          </div>
        </div>
      </div>

      <.form for={:export} phx-submit="request_export" class="space-y-4">
        <div class="form-control">
          <label class="label">
            <span class="label-text font-medium">Export Format</span>
          </label>
          <div class="grid md:grid-cols-3 gap-4">
            <label class="cursor-pointer">
              <input type="radio" name="format" value="json" class="radio radio-primary" checked />
              <span class="ml-2">JSON</span>
            </label>
            <label class="cursor-pointer">
              <input type="radio" name="format" value="csv" class="radio radio-primary" />
              <span class="ml-2">CSV</span>
            </label>
            <label class="cursor-pointer">
              <input type="radio" name="format" value="xml" class="radio radio-primary" />
              <span class="ml-2">XML</span>
            </label>
          </div>
        </div>

        <button type="submit" class="btn btn-primary" disabled={@loading}>
          <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
          {if @loading, do: "Processing...", else: "Request Data Export"}
        </button>
      </.form>
    </div>
    """
  end

  @doc """
  Renders account deletion request interface.
  """
  attr :deletion_status, :map, required: true
  attr :loading, :boolean, default: false

  def account_deletion_component(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @deletion_status.status == "deleted" do %>
        <.deletion_requested_status status={@deletion_status} loading={@loading} />
      <% else %>
        <.deletion_request_form loading={@loading} />
      <% end %>
    </div>
    """
  end

  defp deletion_requested_status(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="alert alert-warning">
        <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
        <div>
          <h3 class="font-bold">Deletion Requested</h3>
          <div class="text-sm">
            Your account is scheduled for deletion on {@status.retention_expires_at}.
            You can cancel this request before this date.
          </div>
        </div>
      </div>

      <div class="text-center space-y-4">
        <.deletion_countdown expires_at={@status.retention_expires_at} />
        <button
          class="btn btn-success"
          phx-click="cancel_deletion"
          disabled={@loading}
        >
          <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
          {if @loading, do: "Cancelling...", else: "Cancel Deletion Request"}
        </button>
      </div>
    </div>
    """
  end

  defp deletion_request_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="alert alert-error">
        <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
        <div>
          <h3 class="font-bold">Important - Permanent Action</h3>
          <div class="text-sm">
            Account deletion is permanent and cannot be undone. Your data will be permanently removed after a 90-day retention period.
          </div>
        </div>
      </div>

      <.deletion_impact_list />

      <div class="text-center">
        <.form for={:deletion} phx-submit="request_deletion" class="space-y-4">
          <div class="form-control max-w-md mx-auto">
            <label class="label">
              <span class="label-text">Reason for deletion (optional)</span>
            </label>
            <textarea
              name="reason"
              class="textarea textarea-bordered h-24"
              placeholder="Please tell us why you're deleting your account (this helps us improve)"
            ></textarea>
          </div>

          <button
            type="submit"
            class="btn btn-error btn-lg"
            disabled={@loading}
            onclick="return confirm('Are you absolutely sure you want to delete your account? This action cannot be undone.')"
          >
            <.icon name="hero-trash" class="w-5 h-5" />
            {if @loading, do: "Processing...", else: "Delete My Account"}
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp deletion_impact_list(assigns) do
    ~H"""
    <div class="bg-base-200 p-6 rounded-lg">
      <h3 class="font-semibold mb-4">What happens when you delete your account:</h3>
      <ul class="space-y-2 text-base-content/80">
        <.impact_item
          icon="hero-check-circle"
          color="success"
          text="Your account will be immediately deactivated"
        />
        <.impact_item
          icon="hero-check-circle"
          color="success"
          text="Your personal data will be retained for 90 days (legal requirement)"
        />
        <.impact_item
          icon="hero-check-circle"
          color="success"
          text="After 90 days, your data will be permanently deleted"
        />
        <.impact_item
          icon="hero-check-circle"
          color="success"
          text="You can cancel the deletion request within the 90-day period"
        />
        <.impact_item
          icon="hero-x-circle"
          color="error"
          text="You will lose access to all services and data"
        />
        <.impact_item
          icon="hero-x-circle"
          color="error"
          text="This action cannot be undone after the retention period"
        />
      </ul>
    </div>
    """
  end

  defp impact_item(assigns) do
    ~H"""
    <li class="flex items-start space-x-2">
      <.icon name={@icon} class={"w-5 h-5 text-#{@color} mt-0.5"} />
      <span>{@text}</span>
    </li>
    """
  end

  defp deletion_countdown(assigns) do
    ~H"""
    <div class="bg-base-200 p-6 rounded-lg">
      <.icon name="hero-clock" class="w-12 h-12 text-warning mx-auto mb-4" />
      <p class="text-lg font-semibold mb-2">Deletion in Progress</p>
      <p class="text-base-content/70">
        Your account will be permanently deleted in
        <span class="font-bold text-warning">{calculate_days_until(@expires_at)}</span>
        days
      </p>
    </div>
    """
  end

  @doc """
  Renders consent management interface.
  """
  attr :consents, :list, required: true
  attr :loading, :boolean, default: false

  def consent_management_component(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="w-6 h-6" />
        <div>
          <h3 class="font-bold">Your Privacy Choices</h3>
          <div class="text-sm">
            Manage how your personal data is used. You can update these preferences at any time.
          </div>
        </div>
      </div>

      <.form for={:consents} phx-submit="update_consents" class="space-y-6">
        <.consent_item :for={consent <- @consents} consent={consent} />
        <div class="text-center">
          <button type="submit" class="btn btn-primary btn-lg" disabled={@loading}>
            <.icon name="hero-check" class="w-5 h-5" />
            {if @loading, do: "Updating...", else: "Update Consent Preferences"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp consent_item(assigns) do
    ~H"""
    <div class="bg-base-200 p-6 rounded-lg">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="font-semibold text-lg">{@consent.display_name}</h3>
          <p class="text-base-content/70 text-sm">{@consent.description}</p>
        </div>

        <div class="form-control">
          <label class="cursor-pointer">
            <input
              type="checkbox"
              name={"consents[#{@consent.purpose}]"}
              value="granted"
              class="toggle toggle-primary"
              checked={@consent.status == "granted"}
            />
          </label>
        </div>
      </div>

      <.consent_status_info consent={@consent} />
    </div>
    """
  end

  defp consent_status_info(assigns) do
    ~H"""
    <%= if @consent.granted_at do %>
      <div class="text-sm text-base-content/60">
        <%= if @consent.status == "granted" do %>
          Granted on {format_date(@consent.granted_at)}
        <% else %>
          Originally granted on {format_date(@consent.granted_at)}
          <%= if @consent.withdrawn_at do %>
            - Withdrawn on {format_date(@consent.withdrawn_at)}
          <% end %>
        <% end %>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders audit trail display.
  """
  attr :audit_trail, :list, required: true

  def audit_trail_component(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="alert alert-info">
        <.icon name="hero-information-circle" class="w-6 h-6" />
        <div>
          <h3 class="font-bold">Your Activity History</h3>
          <div class="text-sm">
            View a log of all privacy-related actions performed on your account.
          </div>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Action</th>
              <th>Date & Time</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            <.audit_trail_row :for={audit <- @audit_trail} audit={audit} />
            <%= if @audit_trail == [] do %>
              <tr>
                <td colspan="3" class="text-center text-base-content/50 py-8">
                  No audit trail entries found
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp audit_trail_row(assigns) do
    ~H"""
    <tr>
      <td>
        <div class="flex items-center space-x-2">
          <.icon name="hero-document-text" class="w-4 h-4 text-base-content/50" />
          <span class="font-medium">{@audit.display_action}</span>
        </div>
      </td>
      <td>
        <div class="text-sm">
          {format_datetime(@audit.created_at)}
        </div>
      </td>
      <td>
        <div class="text-sm text-base-content/70">
          <%= if @audit.details && map_size(@audit.details) > 0 do %>
            <div class="space-y-1">
              <%= for {key, value} <- @audit.details do %>
                <div>
                  <span class="font-medium">{String.capitalize(to_string(key))}:</span>
                  <span class="ml-1">{inspect(value)}</span>
                </div>
              <% end %>
            </div>
          <% else %>
            <span class="text-base-content/50">No additional details</span>
          <% end %>
        </div>
      </td>
    </tr>
    """
  end

  @doc """
  Renders overview status cards.
  """
  attr :deletion_status, :map, required: true
  attr :consents, :list, required: true

  def overview_stats(assigns) do
    ~H"""
    <div class="grid md:grid-cols-2 gap-6">
      <!-- Account Status -->
      <div class="stat bg-base-200 rounded-lg p-6">
        <div class="stat-figure text-primary">
          <.icon name="hero-user-circle" class="w-8 h-8" />
        </div>
        <div class="stat-title">Account Status</div>
        <div class="stat-value text-primary capitalize">
          {@deletion_status.status}
        </div>
        <div class="stat-desc">
          <%= if @deletion_status.status == "deleted" do %>
            Scheduled for deletion on {@deletion_status.retention_expires_at}
          <% else %>
            Active account
          <% end %>
        </div>
      </div>
      
    <!-- Consents Count -->
      <div class="stat bg-base-200 rounded-lg p-6">
        <div class="stat-figure text-secondary">
          <.icon name="hero-shield-check" class="w-8 h-8" />
        </div>
        <div class="stat-title">Active Consents</div>
        <div class="stat-value text-secondary">
          {length(@consents)}
        </div>
        <div class="stat-desc">
          Privacy consents managed
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders quick action buttons.
  """
  attr :loading, :boolean, default: false

  def quick_actions(assigns) do
    ~H"""
    <div class="divider">Quick Actions</div>
    <div class="grid md:grid-cols-3 gap-4">
      <button
        class="btn btn-outline btn-primary"
        phx-click="switch_tab"
        phx-value-tab="data_export"
        disabled={@loading}
      >
        <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Export My Data
      </button>

      <button
        class="btn btn-outline btn-warning"
        phx-click="switch_tab"
        phx-value-tab="account_deletion"
        disabled={@loading}
      >
        <.icon name="hero-trash" class="w-4 h-4" /> Manage Deletion
      </button>

      <button
        class="btn btn-outline btn-info"
        phx-click="switch_tab"
        phx-value-tab="consents"
        disabled={@loading}
      >
        <.icon name="hero-adjustments-horizontal" class="w-4 h-4" /> Update Consents
      </button>
    </div>
    """
  end

  @doc """
  Renders recent activity feed.
  """
  attr :audit_trail, :list, required: true

  def recent_activity(assigns) do
    ~H"""
    <div class="divider">Recent Activity</div>
    <div class="space-y-2">
      <.activity_item :for={audit <- Enum.take(@audit_trail, 5)} audit={audit} />
      <%= if @audit_trail == [] do %>
        <p class="text-center text-base-content/50 py-4">No recent activity</p>
      <% end %>
    </div>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-3 bg-base-200 rounded">
      <div class="flex items-center space-x-3">
        <.icon name="hero-clock" class="w-4 h-4 text-base-content/50" />
        <span class="font-medium">{@audit.display_action}</span>
      </div>
      <span class="text-sm text-base-content/70">
        {format_datetime_relative(@audit.created_at)}
      </span>
    </div>
    """
  end

  # Helper functions
  defp format_date(date) do
    date
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_string()
  end

  defp format_datetime_relative(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :day)

    cond do
      diff == 0 -> "Today"
      diff == 1 -> "Yesterday"
      diff < 7 -> "#{diff} days ago"
      diff < 30 -> "#{div(diff, 7)} weeks ago"
      true -> "#{div(diff, 30)} months ago"
    end
  end

  defp calculate_days_until(future_date) do
    now = DateTime.utc_now()

    DateTime.diff(future_date, now, :day)
    |> max(0)
  end
end
