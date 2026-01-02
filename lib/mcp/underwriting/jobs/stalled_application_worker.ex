defmodule Mcp.Underwriting.Jobs.StalledApplicationWorker do
  @moduledoc """
  Oban worker that finds stalled applications and sends reminder notifications.

  Runs periodically (every hour) to check for applications that have been
  sitting in draft or incomplete status for too long.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Ash.Query
  require Logger

  alias Mcp.Communication.EmailService
  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Underwriting.Services.MagicLink

  @stall_threshold_hours 24

  @doc """
  Returns the stall threshold in hours.
  """
  def stall_threshold_hours, do: @stall_threshold_hours

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    tenants = list_tenants()

    Enum.each(tenants, fn tenant ->
      find_and_notify_stalled(tenant)
    end)

    :ok
  end

  defp list_tenants do
    case Tenant.read() do
      {:ok, tenants} -> tenants
      _ -> []
    end
  end

  defp find_and_notify_stalled(tenant) do
    cutoff = DateTime.add(DateTime.utc_now(), -@stall_threshold_hours, :hour)

    stalled_apps =
      UWApplication
      |> Ash.Query.filter(status == :draft)
      |> Ash.Query.filter(updated_at < ^cutoff)
      |> Ash.read(tenant: tenant.company_schema)
      |> case do
        {:ok, apps} -> apps
        _ -> []
      end

    Enum.each(stalled_apps, fn app ->
      send_reminder(app, tenant)
    end)
  end

  defp send_reminder(application, tenant) do
    email = get_in(application.application_data, ["contact_email"])
    name = get_in(application.application_data, ["contact_name"]) || "there"
    business_name = get_in(application.application_data, ["business_name"]) || "your business"

    if email do
      {subject, body} =
        build_reminder_email(application.id, email, name, business_name, tenant.name)

      case EmailService.send_email(email, subject, body) do
        {:ok, _} ->
          Logger.info("Sent stalled application reminder to #{email}")

        {:error, reason} ->
          Logger.warning("Failed to send reminder to #{email}: #{inspect(reason)}")
      end
    end
  end

  @doc """
  Builds a reminder email for a stalled application.
  Returns {subject, body}.
  """
  def build_reminder_email(app_id, email, name, business_name, tenant_name) do
    resume_url = MagicLink.resume_url(app_id, email)

    subject = "Don't forget to finish your application!"

    body = """
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h2>Hi #{name},</h2>

      <p>We noticed you started an application for <strong>#{business_name}</strong>
      with #{tenant_name}, but haven't completed it yet.</p>

      <p>Good news - we saved your progress! Click the button below to pick up
      right where you left off:</p>

      <p style="text-align: center; margin: 30px 0;">
        <a href="#{resume_url}"
           style="background-color: #4F46E5; color: white; padding: 12px 24px;
                  text-decoration: none; border-radius: 6px; font-weight: bold;">
          Continue Your Application
        </a>
      </p>

      <p>This link will expire in 72 hours. If you have any questions, just reply
      to this email.</p>

      <p>Best regards,<br/>
      The #{tenant_name} Team</p>

      <hr style="margin-top: 30px; border: none; border-top: 1px solid #eee;" />
      <p style="font-size: 12px; color: #666;">
        If you didn't start this application, you can safely ignore this email.
      </p>
    </body>
    </html>
    """

    {subject, body}
  end
end
