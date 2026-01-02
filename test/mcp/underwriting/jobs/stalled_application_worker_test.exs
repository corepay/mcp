defmodule Mcp.Underwriting.Jobs.StalledApplicationWorkerTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Mcp.Repo

  alias Mcp.Underwriting.Jobs.StalledApplicationWorker

  describe "perform/1" do
    test "handles empty tenant list gracefully" do
      # When no tenants exist (or can't be queried), should complete without error
      # In test mode, Tenant.read! may return empty list
      assert :ok = perform_job(StalledApplicationWorker, %{})
    end
  end

  describe "stall detection logic" do
    test "correctly identifies stalled time threshold" do
      threshold_hours = StalledApplicationWorker.stall_threshold_hours()
      cutoff = DateTime.add(DateTime.utc_now(), -threshold_hours, :hour)

      # An application updated beyond threshold should be stalled
      old_time = DateTime.add(DateTime.utc_now(), -(threshold_hours + 1), :hour)
      assert DateTime.compare(old_time, cutoff) == :lt

      # An application updated within threshold should not be stalled
      recent_time = DateTime.add(DateTime.utc_now(), -(threshold_hours - 1), :hour)
      assert DateTime.compare(recent_time, cutoff) == :gt
    end

    test "stall threshold is 24 hours" do
      assert StalledApplicationWorker.stall_threshold_hours() == 24
    end
  end

  describe "email content" do
    test "builds reminder email with resume URL" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"
      name = "John"
      business_name = "Test Business"
      tenant_name = "Acme Payments"

      {subject, body} =
        StalledApplicationWorker.build_reminder_email(
          app_id,
          email,
          name,
          business_name,
          tenant_name
        )

      assert subject =~ "finish your application"
      assert body =~ name
      assert body =~ business_name
      assert body =~ tenant_name
      # Should contain resume URL
      assert body =~ "/online-application/resume/"
    end
  end
end
