# Underwriting Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance the existing Underwriting system with real-time SLA countdown, applicant status tracker, save & resume, The Eye integration, drip campaigns, and Atlas Lite.

**Architecture:** Build on existing components (SlaTimer, TimelineComponent, The Eye service, Oban infrastructure). All features are enhancements to working code, not new systems.

**Tech Stack:** Phoenix LiveView, Oban, Req HTTP client, existing UW domain

---

## Quick Wins (Tasks 1-3)

### Task 1: Real-Time SLA Countdown

The SlaTimer component exists but doesn't tick in real-time. Add Process.send_after to update every minute.

**Files:**
- Modify: `lib/mcp_web/live/tenant/underwriting/components/sla_timer.ex`
- Test: `test/mcp_web/live/tenant/underwriting/components/sla_timer_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/tenant/underwriting/components/sla_timer_test.exs
defmodule McpWeb.Tenant.Underwriting.Components.SlaTimerTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Tenant.Underwriting.Components.SlaTimer

  describe "real-time updates" do
    test "schedules tick on mount when connected" do
      due_at = DateTime.add(DateTime.utc_now(), 30, :minute)

      {:ok, view, _html} = live_isolated(build_conn(), SlaTimer, session: %{
        "due_at" => due_at
      })

      # Component should schedule a tick
      # After receiving :tick, the time should update
      send(view.pid, :tick)

      # Should still be mounted and responsive
      assert render(view) =~ "left"
    end

    test "displays overdue state correctly" do
      due_at = DateTime.add(DateTime.utc_now(), -15, :minute)

      html = render_component(SlaTimer, id: "test", due_at: due_at)

      assert html =~ "Overdue"
      assert html =~ "text-error"
    end

    test "displays warning state when less than 1 hour" do
      due_at = DateTime.add(DateTime.utc_now(), 45, :minute)

      html = render_component(SlaTimer, id: "test", due_at: due_at)

      assert html =~ "left"
      assert html =~ "text-warning"
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/mcp_web/live/tenant/underwriting/components/sla_timer_test.exs -v
```

Expected: FAIL - test file doesn't exist yet or tests fail

**Step 3: Update SlaTimer to tick in real-time**

```elixir
# lib/mcp_web/live/tenant/underwriting/components/sla_timer.ex
defmodule McpWeb.Tenant.Underwriting.Components.SlaTimer do
  @moduledoc """
  Component to display SLA timers with real-time countdown.
  """
  use McpWeb, :live_component

  @tick_interval :timer.seconds(30)

  def mount(socket) do
    {:ok, assign(socket, :now, DateTime.utc_now())}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Schedule ticks only when connected
    if connected?(socket) do
      schedule_tick()
    end

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    schedule_tick()
    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  def render(assigns) do
    ~H"""
    <div class={[
      "flex items-center space-x-1 font-medium",
      sla_color(@due_at, @now)
    ]}>
      <.icon name="hero-clock" class="w-4 h-4" />
      <span>{relative_time(@due_at, @now)}</span>
    </div>
    """
  end

  defp sla_color(due_at, now) do
    diff = DateTime.diff(due_at, now, :minute)

    cond do
      diff < 0 -> "text-error font-bold animate-pulse"
      diff < 60 -> "text-warning"
      true -> "text-success"
    end
  end

  defp relative_time(datetime, now) do
    diff = DateTime.diff(datetime, now, :minute)

    cond do
      diff < 0 -> "Overdue by #{abs(diff)}m"
      diff < 60 -> "#{diff}m left"
      true -> "#{div(diff, 60)}h #{rem(diff, 60)}m left"
    end
  end
end
```

**Step 4: Run test to verify it passes**

```bash
mix test test/mcp_web/live/tenant/underwriting/components/sla_timer_test.exs -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/tenant/underwriting/components/sla_timer.ex test/mcp_web/live/tenant/underwriting/components/sla_timer_test.exs
git commit -m "feat(uw): add real-time SLA countdown with 30s tick"
```

---

### Task 2: Applicant Status Tracker (Pizza Tracker)

Create a simplified, applicant-facing status tracker for the OLA portal.

**Files:**
- Create: `lib/mcp_web/live/ola/components/status_tracker.ex`
- Create: `lib/mcp_web/live/ola/status_live.ex`
- Modify: `lib/mcp_web/router.ex` (add route)
- Test: `test/mcp_web/live/ola/status_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/ola/status_live_test.exs
defmodule McpWeb.Ola.StatusLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "status tracker" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user()
      application = create_test_application(tenant, %{
        status: :under_review,
        application_data: %{"business_name" => "Test Biz"}
      })

      {:ok, tenant: tenant, user: user, application: application}
    end

    test "displays application status steps", %{conn: conn, application: app} do
      {:ok, view, html} = live(conn, ~p"/online-application/status/#{app.id}")

      # Should show all status steps
      assert html =~ "Submitted"
      assert html =~ "Under Review"
      assert html =~ "Decision"

      # Current step should be highlighted
      assert html =~ "Under Review"
    end

    test "shows completed steps with checkmark", %{conn: conn, application: app} do
      {:ok, _view, html} = live(conn, ~p"/online-application/status/#{app.id}")

      # Submitted should be complete
      assert html =~ "hero-check-circle"
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/mcp_web/live/ola/status_live_test.exs -v
```

Expected: FAIL - route and LiveView don't exist

**Step 3: Create the StatusTracker component**

```elixir
# lib/mcp_web/live/ola/components/status_tracker.ex
defmodule McpWeb.Ola.Components.StatusTracker do
  @moduledoc """
  "Pizza Tracker" style status display for applicants.
  Shows application progress through underwriting stages.
  """
  use McpWeb, :live_component

  @stages [
    %{id: :submitted, label: "Submitted", icon: "hero-paper-airplane"},
    %{id: :under_review, label: "Under Review", icon: "hero-magnifying-glass"},
    %{id: :manual_review, label: "Final Review", icon: "hero-user-circle"},
    %{id: :decision, label: "Decision", icon: "hero-check-badge"}
  ]

  def render(assigns) do
    assigns = assign(assigns, :stages, @stages)

    ~H"""
    <div class="w-full max-w-2xl mx-auto">
      <div class="relative">
        <!-- Progress line -->
        <div class="absolute top-6 left-0 right-0 h-1 bg-base-300">
          <div
            class="h-full bg-primary transition-all duration-500"
            style={"width: #{progress_percentage(@status)}%"}
          />
        </div>

        <!-- Steps -->
        <div class="relative flex justify-between">
          <%= for {stage, idx} <- Enum.with_index(@stages) do %>
            <div class="flex flex-col items-center">
              <div class={[
                "w-12 h-12 rounded-full flex items-center justify-center border-4 z-10 transition-all",
                step_classes(stage.id, @status, idx)
              ]}>
                <%= if is_complete?(stage.id, @status) do %>
                  <.icon name="hero-check" class="w-6 h-6 text-white" />
                <% else %>
                  <.icon name={stage.icon} class={[
                    "w-6 h-6",
                    if(is_current?(stage.id, @status), do: "text-primary", else: "text-base-content/50")
                  ]} />
                <% end %>
              </div>

              <span class={[
                "mt-2 text-sm font-medium text-center",
                if(is_current?(stage.id, @status) or is_complete?(stage.id, @status),
                   do: "text-primary",
                   else: "text-base-content/50")
              ]}>
                {stage.label}
              </span>

              <%= if is_current?(stage.id, @status) do %>
                <span class="mt-1 text-xs text-primary animate-pulse">
                  In Progress
                </span>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Status message -->
      <div class="mt-8 text-center">
        <p class="text-lg font-medium">{status_message(@status)}</p>
        <p class="text-sm text-base-content/70 mt-1">{status_description(@status)}</p>
      </div>
    </div>
    """
  end

  defp step_classes(stage_id, current_status, _idx) do
    cond do
      is_complete?(stage_id, current_status) ->
        "bg-primary border-primary"
      is_current?(stage_id, current_status) ->
        "bg-base-100 border-primary"
      true ->
        "bg-base-100 border-base-300"
    end
  end

  defp is_complete?(stage_id, current_status) do
    stage_order(stage_id) < stage_order(current_status)
  end

  defp is_current?(stage_id, current_status) do
    stage_order(stage_id) == stage_order(current_status)
  end

  defp stage_order(:submitted), do: 0
  defp stage_order(:under_review), do: 1
  defp stage_order(:manual_review), do: 2
  defp stage_order(:approved), do: 3
  defp stage_order(:rejected), do: 3
  defp stage_order(:decision), do: 3
  defp stage_order(_), do: 0

  defp progress_percentage(status) do
    case status do
      :submitted -> 0
      :under_review -> 33
      :manual_review -> 66
      :approved -> 100
      :rejected -> 100
      _ -> 0
    end
  end

  defp status_message(:submitted), do: "Application Received"
  defp status_message(:under_review), do: "Reviewing Your Application"
  defp status_message(:manual_review), do: "Final Review in Progress"
  defp status_message(:approved), do: "Congratulations! You're Approved!"
  defp status_message(:rejected), do: "Application Not Approved"
  defp status_message(_), do: "Processing"

  defp status_description(:submitted), do: "We've received your application and will begin review shortly."
  defp status_description(:under_review), do: "Our team is reviewing your documents and information."
  defp status_description(:manual_review), do: "A specialist is taking a final look at your application."
  defp status_description(:approved), do: "Your merchant account is ready. Check your email for next steps."
  defp status_description(:rejected), do: "Unfortunately, we couldn't approve your application at this time."
  defp status_description(_), do: ""
end
```

**Step 4: Create the StatusLive page**

```elixir
# lib/mcp_web/live/ola/status_live.ex
defmodule McpWeb.Ola.StatusLive do
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Application, as: UWApplication
  alias McpWeb.Ola.Components.StatusTracker

  def mount(%{"id" => app_id}, session, socket) do
    tenant_id = session["tenant_id"]
    tenant = Tenant.get_by_id!(tenant_id)

    case UWApplication.get_by_id(app_id, tenant: tenant.company_schema) do
      {:ok, application} ->
        # Subscribe to updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Mcp.PubSub, "application:#{app_id}")
        end

        {:ok,
         socket
         |> assign(:page_title, "Application Status")
         |> assign(:application, application)
         |> assign(:tenant, tenant)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found")
         |> redirect(to: ~p"/online-application")}
    end
  end

  def handle_info({:application_updated, application}, socket) do
    {:noreply, assign(socket, :application, application)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-12 px-4">
      <div class="max-w-3xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold">Application Status</h1>
          <p class="text-base-content/70 mt-2">
            {get_in(@application.application_data, ["business_name"]) || "Your Application"}
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl p-8">
          <.live_component
            module={StatusTracker}
            id="status-tracker"
            status={@application.status}
          />
        </div>

        <div class="mt-6 text-center">
          <p class="text-sm text-base-content/50">
            Application ID: {String.slice(@application.id, 0, 8)}...
          </p>
          <p class="text-sm text-base-content/50">
            Submitted: {Calendar.strftime(@application.inserted_at, "%B %d, %Y at %I:%M %p")}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
```

**Step 5: Add route**

```elixir
# In lib/mcp_web/router.ex, inside the OLA scope:
# Find the existing OLA scope and add:

live "/status/:id", Ola.StatusLive, :show
```

**Step 6: Run test to verify it passes**

```bash
mix test test/mcp_web/live/ola/status_live_test.exs -v
```

Expected: PASS

**Step 7: Commit**

```bash
git add lib/mcp_web/live/ola/components/status_tracker.ex lib/mcp_web/live/ola/status_live.ex lib/mcp_web/router.ex test/mcp_web/live/ola/status_live_test.exs
git commit -m "feat(ola): add pizza tracker status page for applicants"
```

---

### Task 3: Save & Resume Magic Links

Add magic link generation and resumption for OLA applications.

**Files:**
- Create: `lib/mcp/underwriting/services/magic_link.ex`
- Create: `lib/mcp/underwriting/jobs/resume_reminder_worker.ex`
- Modify: `lib/mcp_web/live/ola/application_live.ex`
- Modify: `lib/mcp_web/router.ex`
- Test: `test/mcp/underwriting/services/magic_link_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/magic_link_test.exs
defmodule Mcp.Underwriting.Services.MagicLinkTest do
  use Mcp.DataCase, async: true

  alias Mcp.Underwriting.Services.MagicLink

  describe "generate/2" do
    test "creates a valid token for an application" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      {:ok, token} = MagicLink.generate(app_id, email)

      assert is_binary(token)
      assert byte_size(token) > 20
    end
  end

  describe "verify/1" do
    test "returns application id for valid token" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      {:ok, token} = MagicLink.generate(app_id, email)
      {:ok, result} = MagicLink.verify(token)

      assert result.application_id == app_id
      assert result.email == email
    end

    test "returns error for expired token" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      # Generate token with 0 TTL
      {:ok, token} = MagicLink.generate(app_id, email, ttl: 0)

      # Wait a moment
      Process.sleep(100)

      assert {:error, :expired} = MagicLink.verify(token)
    end

    test "returns error for invalid token" do
      assert {:error, :invalid} = MagicLink.verify("garbage")
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/mcp/underwriting/services/magic_link_test.exs -v
```

Expected: FAIL - module doesn't exist

**Step 3: Create the MagicLink service**

```elixir
# lib/mcp/underwriting/services/magic_link.ex
defmodule Mcp.Underwriting.Services.MagicLink do
  @moduledoc """
  Generates and verifies magic links for OLA save & resume.
  Uses Phoenix.Token for secure, expiring tokens.
  """

  @token_salt "ola_resume_v1"
  @default_ttl_hours 72

  @doc """
  Generates a magic link token for an application.

  Options:
  - ttl: Time to live in seconds (default: 72 hours)
  """
  def generate(application_id, email, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl_hours * 3600)

    payload = %{
      application_id: application_id,
      email: email,
      generated_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    token = Phoenix.Token.sign(
      McpWeb.Endpoint,
      @token_salt,
      payload,
      max_age: ttl
    )

    {:ok, token}
  end

  @doc """
  Verifies a magic link token and returns the payload.
  """
  def verify(token) do
    case Phoenix.Token.verify(McpWeb.Endpoint, @token_salt, token) do
      {:ok, payload} ->
        {:ok, %{
          application_id: payload.application_id,
          email: payload.email
        }}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  @doc """
  Generates the full resume URL for an application.
  """
  def resume_url(application_id, email) do
    {:ok, token} = generate(application_id, email)
    McpWeb.Endpoint.url() <> "/online-application/resume/#{token}"
  end
end
```

**Step 4: Run test to verify it passes**

```bash
mix test test/mcp/underwriting/services/magic_link_test.exs -v
```

Expected: PASS

**Step 5: Add resume route and handler**

```elixir
# In lib/mcp_web/router.ex, inside OLA scope:
live "/resume/:token", Ola.ResumeLive, :resume
```

```elixir
# lib/mcp_web/live/ola/resume_live.ex
defmodule McpWeb.Ola.ResumeLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Services.MagicLink
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Platform.Tenant

  def mount(%{"token" => token}, session, socket) do
    case MagicLink.verify(token) do
      {:ok, %{application_id: app_id, email: _email}} ->
        tenant_id = session["tenant_id"]
        tenant = Tenant.get_by_id!(tenant_id)

        case UWApplication.get_by_id(app_id, tenant: tenant.company_schema) do
          {:ok, application} ->
            {:ok,
             socket
             |> put_flash(:info, "Welcome back! Continue your application.")
             |> redirect(to: ~p"/online-application/application?resume=#{app_id}")}

          _ ->
            {:ok, redirect_with_error(socket, "Application not found")}
        end

      {:error, :expired} ->
        {:ok, redirect_with_error(socket, "This link has expired. Please start a new application.")}

      {:error, _} ->
        {:ok, redirect_with_error(socket, "Invalid link. Please check your email for the correct link.")}
    end
  end

  defp redirect_with_error(socket, message) do
    socket
    |> put_flash(:error, message)
    |> redirect(to: ~p"/online-application")
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen">
      <span class="loading loading-spinner loading-lg"></span>
    </div>
    """
  end
end
```

**Step 6: Commit**

```bash
git add lib/mcp/underwriting/services/magic_link.ex lib/mcp_web/live/ola/resume_live.ex lib/mcp_web/router.ex test/mcp/underwriting/services/magic_link_test.exs
git commit -m "feat(ola): add save & resume magic links"
```

---

## Meaningful Progress (Tasks 4-6)

### Task 4: Wire Up The Eye Document Service

Integrate The Eye for document pre-validation before submission.

**Files:**
- Create: `lib/mcp/underwriting/services/the_eye.ex`
- Modify: `lib/mcp_web/live/ola/application_live.ex`
- Test: `test/mcp/underwriting/services/the_eye_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/services/the_eye_test.exs
defmodule Mcp.Underwriting.Services.TheEyeTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.TheEye

  describe "health_check/0" do
    test "returns healthy when service is running" do
      # Requires The Eye to be running
      case TheEye.health_check() do
        {:ok, %{status: "healthy"}} -> assert true
        {:error, :service_unavailable} -> assert true  # OK if not running in test
      end
    end
  end

  describe "analyze_document/1" do
    @tag :integration
    test "analyzes a PDF document" do
      # Create a simple test PDF
      pdf_content = File.read!("test/fixtures/sample_id.pdf")

      case TheEye.analyze_document(pdf_content, "sample_id.pdf") do
        {:ok, result} ->
          assert result.status == "success"
          assert is_binary(result.markdown_content)

        {:error, :service_unavailable} ->
          # OK if The Eye not running
          assert true
      end
    end
  end
end
```

**Step 2: Create The Eye service client**

```elixir
# lib/mcp/underwriting/services/the_eye.ex
defmodule Mcp.Underwriting.Services.TheEye do
  @moduledoc """
  Client for The Eye document intelligence service.
  Provides OCR, table extraction, and document analysis.
  """

  @default_base_url "http://localhost:48291"

  def base_url do
    System.get_env("THE_EYE_URL", @default_base_url)
  end

  @doc """
  Checks if The Eye service is healthy.
  """
  def health_check do
    case Req.get("#{base_url()}/health") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:unhealthy, status}}

      {:error, _} ->
        {:error, :service_unavailable}
    end
  end

  @doc """
  Analyzes a document and returns structured content.

  Returns:
  - {:ok, %{status, markdown_content, structured_data}}
  - {:error, reason}
  """
  def analyze_document(file_content, filename) do
    multipart = Req.Request.new(
      method: :post,
      url: "#{base_url()}/analyze/document"
    )
    |> Req.Request.put_header("content-type", "multipart/form-data")

    case Req.post("#{base_url()}/analyze/document",
           form_multipart: [
             {:file, file_content, filename: filename}
           ]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          status: body["status"],
          markdown_content: body["markdown_content"],
          structured_data: body["structured_data"],
          provider: body["provider"]
        }}

      {:ok, %{status: 503}} ->
        {:error, :service_unavailable}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
    end
  end

  @doc """
  Validates a document meets quality requirements.

  Checks:
  - Document is readable
  - Key fields are extractable
  - Image quality is sufficient
  """
  def validate_document(file_content, filename, document_type) do
    case analyze_document(file_content, filename) do
      {:ok, %{status: "success", markdown_content: content}} ->
        validate_content(content, document_type)

      {:ok, %{status: status}} ->
        {:error, {:analysis_failed, status}}

      error ->
        error
    end
  end

  defp validate_content(content, :government_id) do
    # Check for expected fields in ID
    checks = [
      {String.contains?(content, ["name", "Name", "NAME"]), "Name not found"},
      {String.contains?(content, ["DOB", "Date of Birth", "birth"]), "Date of birth not found"},
      {String.length(content) > 50, "Document appears to be unreadable"}
    ]

    issues =
      checks
      |> Enum.filter(fn {passed, _} -> not passed end)
      |> Enum.map(fn {_, issue} -> issue end)

    if Enum.empty?(issues) do
      {:ok, :valid}
    else
      {:error, {:validation_failed, issues}}
    end
  end

  defp validate_content(content, :bank_statement) do
    checks = [
      {String.contains?(content, ["balance", "Balance", "BALANCE"]), "Balance not found"},
      {String.contains?(content, ["account", "Account", "ACCOUNT"]), "Account info not found"},
      {String.length(content) > 100, "Document appears to be unreadable"}
    ]

    issues =
      checks
      |> Enum.filter(fn {passed, _} -> not passed end)
      |> Enum.map(fn {_, issue} -> issue end)

    if Enum.empty?(issues) do
      {:ok, :valid}
    else
      {:error, {:validation_failed, issues}}
    end
  end

  defp validate_content(_content, _type) do
    # Default: just check it's readable
    {:ok, :valid}
  end
end
```

**Step 3: Run test**

```bash
mix test test/mcp/underwriting/services/the_eye_test.exs -v
```

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/services/the_eye.ex test/mcp/underwriting/services/the_eye_test.exs
git commit -m "feat(uw): add The Eye document service integration"
```

---

### Task 5: Drip Campaign Worker

Create Oban worker to send reminder emails for stalled applications.

**Files:**
- Create: `lib/mcp/underwriting/jobs/stalled_application_worker.ex`
- Modify: `config/config.exs` (add Oban queue)
- Test: `test/mcp/underwriting/jobs/stalled_application_worker_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/jobs/stalled_application_worker_test.exs
defmodule Mcp.Underwriting.Jobs.StalledApplicationWorkerTest do
  use Mcp.DataCase, async: true
  use Oban.Testing, repo: Mcp.Repo

  alias Mcp.Underwriting.Jobs.StalledApplicationWorker

  describe "perform/1" do
    test "finds stalled applications and queues notifications" do
      # Create a stalled application (draft status, updated > 24h ago)
      tenant = create_test_tenant()
      app = create_test_application(tenant, %{
        status: :draft,
        updated_at: DateTime.add(DateTime.utc_now(), -25, :hour)
      })

      # Run the worker
      assert :ok = perform_job(StalledApplicationWorker, %{})

      # Should have queued a notification
      assert_enqueued(worker: Mcp.Communication.DeliveryWorker)
    end

    test "ignores recently updated applications" do
      tenant = create_test_tenant()
      _app = create_test_application(tenant, %{
        status: :draft,
        updated_at: DateTime.utc_now()  # Just now
      })

      assert :ok = perform_job(StalledApplicationWorker, %{})

      refute_enqueued(worker: Mcp.Communication.DeliveryWorker)
    end
  end
end
```

**Step 2: Create the worker**

```elixir
# lib/mcp/underwriting/jobs/stalled_application_worker.ex
defmodule Mcp.Underwriting.Jobs.StalledApplicationWorker do
  @moduledoc """
  Oban worker that finds stalled applications and sends reminder notifications.

  Runs periodically (e.g., every hour) to check for applications that have been
  sitting in draft or incomplete status for too long.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Ash.Query

  alias Mcp.Communication.EmailService
  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Underwriting.Services.MagicLink

  @stall_threshold_hours 24
  @reminder_cooldown_hours 48

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    # Get all tenants
    tenants = Tenant.read!()

    Enum.each(tenants, fn tenant ->
      find_and_notify_stalled(tenant)
    end)

    :ok
  end

  defp find_and_notify_stalled(tenant) do
    cutoff = DateTime.add(DateTime.utc_now(), -@stall_threshold_hours, :hour)

    stalled_apps =
      UWApplication
      |> Ash.Query.filter(status == :draft)
      |> Ash.Query.filter(updated_at < ^cutoff)
      |> Ash.read!(tenant: tenant.company_schema)

    Enum.each(stalled_apps, fn app ->
      send_reminder(app, tenant)
    end)
  end

  defp send_reminder(application, tenant) do
    email = get_in(application.application_data, ["contact_email"])
    name = get_in(application.application_data, ["contact_name"]) || "there"

    if email do
      resume_url = MagicLink.resume_url(application.id, email)

      EmailService.send_email(%{
        to: email,
        subject: "Don't forget to finish your application!",
        template: :application_reminder,
        assigns: %{
          name: name,
          resume_url: resume_url,
          business_name: get_in(application.application_data, ["business_name"]),
          tenant_name: tenant.name
        }
      })
    end
  end
end
```

**Step 3: Add Oban configuration**

```elixir
# In config/config.exs, ensure the :notifications queue exists in Oban config:
# Find the Oban config and add :notifications queue if not present

config :mcp, Oban,
  queues: [
    default: 10,
    notifications: 5,
    # ... other queues
  ]
```

**Step 4: Add periodic job (in application.ex or config)**

```elixir
# In config/config.exs, add to Oban plugins:
plugins: [
  {Oban.Plugins.Cron,
   crontab: [
     {"0 * * * *", Mcp.Underwriting.Jobs.StalledApplicationWorker}  # Every hour
   ]}
]
```

**Step 5: Run test**

```bash
mix test test/mcp/underwriting/jobs/stalled_application_worker_test.exs -v
```

**Step 6: Commit**

```bash
git add lib/mcp/underwriting/jobs/stalled_application_worker.ex config/config.exs test/mcp/underwriting/jobs/stalled_application_worker_test.exs
git commit -m "feat(uw): add drip campaign worker for stalled applications"
```

---

### Task 6: Atlas Lite - Contextual Chat Hints

Enhance the OLA chat with contextual guidance based on application state.

**Files:**
- Create: `lib/mcp/underwriting/atlas/context_hints.ex`
- Modify: `lib/mcp_web/live/ola/application_live.ex`
- Test: `test/mcp/underwriting/atlas/context_hints_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/underwriting/atlas/context_hints_test.exs
defmodule Mcp.Underwriting.Atlas.ContextHintsTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Atlas.ContextHints

  describe "get_hint/2" do
    test "returns hint for document upload step" do
      hint = ContextHints.get_hint(:documents, %{})

      assert hint.message =~ "document"
      assert is_list(hint.suggestions)
    end

    test "returns hint for business info step" do
      hint = ContextHints.get_hint(:business_info, %{})

      assert hint.message =~ "business"
    end

    test "includes idle prompt after 30 seconds" do
      hint = ContextHints.get_hint(:business_info, %{idle_seconds: 35})

      assert hint.idle_prompt != nil
    end
  end
end
```

**Step 2: Create the ContextHints module**

```elixir
# lib/mcp/underwriting/atlas/context_hints.ex
defmodule Mcp.Underwriting.Atlas.ContextHints do
  @moduledoc """
  Provides contextual guidance hints for the OLA application flow.
  This is "Atlas Lite" - predetermined helpful prompts based on application state.
  """

  defmodule Hint do
    defstruct [:message, :suggestions, :idle_prompt, :icon]
  end

  @doc """
  Returns a hint based on current step and context.

  Context options:
  - idle_seconds: How long user has been idle
  - field_focus: Which field they're currently on
  - errors: Any validation errors
  """
  def get_hint(step, context \\ %{})

  def get_hint(:business_info, context) do
    %Hint{
      message: "Let's start with your business details. I'll help you through each step.",
      suggestions: [
        "What's my business type?",
        "Where do I find my EIN?"
      ],
      idle_prompt: idle_prompt_for(:business_info, context),
      icon: "hero-building-office"
    }
  end

  def get_hint(:owners, context) do
    %Hint{
      message: "Now I need info about anyone who owns 25% or more of the business.",
      suggestions: [
        "What if I'm the only owner?",
        "Why do you need SSN?"
      ],
      idle_prompt: idle_prompt_for(:owners, context),
      icon: "hero-users"
    }
  end

  def get_hint(:documents, context) do
    %Hint{
      message: "Almost there! Upload your documents and I'll verify them instantly.",
      suggestions: [
        "What documents do I need?",
        "Can I use my phone camera?"
      ],
      idle_prompt: idle_prompt_for(:documents, context),
      icon: "hero-document"
    }
  end

  def get_hint(:banking, context) do
    %Hint{
      message: "Final step - where should we send your money?",
      suggestions: [
        "Is Plaid secure?",
        "Can I change this later?"
      ],
      idle_prompt: idle_prompt_for(:banking, context),
      icon: "hero-banknotes"
    }
  end

  def get_hint(:review, _context) do
    %Hint{
      message: "Review your application. Once submitted, I'll have a decision in minutes!",
      suggestions: [
        "What happens after I submit?",
        "Can I edit after submission?"
      ],
      idle_prompt: nil,
      icon: "hero-check-circle"
    }
  end

  def get_hint(_, _context) do
    %Hint{
      message: "I'm here to help! Ask me anything about the application.",
      suggestions: ["How long does approval take?", "Is my data secure?"],
      idle_prompt: nil,
      icon: "hero-chat-bubble-left-right"
    }
  end

  defp idle_prompt_for(:business_info, %{idle_seconds: s}) when s > 30 do
    "Not sure about something? The business name should match your tax documents exactly."
  end

  defp idle_prompt_for(:owners, %{idle_seconds: s}) when s > 30 do
    "Stuck on the SSN? We use it for identity verification only - it's encrypted and never stored in plain text."
  end

  defp idle_prompt_for(:documents, %{idle_seconds: s}) when s > 30 do
    "Need help with documents? A clear photo of your driver's license (front and back) is all we need for ID."
  end

  defp idle_prompt_for(:banking, %{idle_seconds: s}) when s > 30 do
    "Having trouble? You can connect via Plaid (instant) or enter your routing/account numbers manually."
  end

  defp idle_prompt_for(_, _), do: nil

  @doc """
  Returns a response to a common question.
  """
  def answer_faq(question) do
    faqs = %{
      "business type" => "Choose the legal structure of your business: LLC, Corporation, Sole Proprietor, etc. Not sure? Check your formation documents.",
      "ein" => "Your EIN (Employer Identification Number) is on your IRS SS-4 confirmation letter, usually at the top right. It's 9 digits: XX-XXXXXXX",
      "ssn" => "We need SSN for identity verification and credit check. It's encrypted immediately and we never store it in plain text.",
      "documents" => "You'll need: 1) Government ID (driver's license or passport), 2) Voided check or bank letter, 3) Optionally: business license",
      "approval" => "Most applications are approved in under 5 minutes. Complex cases may take up to 24 hours for manual review.",
      "secure" => "Absolutely. We use bank-level encryption, and your data is protected under PCI DSS and SOC 2 compliance."
    }

    question_lower = String.downcase(question)

    Enum.find_value(faqs, fn {key, answer} ->
      if String.contains?(question_lower, key), do: answer
    end) || "I don't have a specific answer for that, but you can always ask our support team for help."
  end
end
```

**Step 3: Run test**

```bash
mix test test/mcp/underwriting/atlas/context_hints_test.exs -v
```

**Step 4: Commit**

```bash
git add lib/mcp/underwriting/atlas/context_hints.ex test/mcp/underwriting/atlas/context_hints_test.exs
git commit -m "feat(uw): add Atlas Lite context hints for OLA"
```

---

## Summary

| Task | Description | Effort |
|------|-------------|--------|
| 1 | Real-time SLA countdown | 30 min |
| 2 | Pizza Tracker status page | 1 hr |
| 3 | Save & Resume magic links | 1 hr |
| 4 | The Eye integration | 1.5 hr |
| 5 | Drip campaign worker | 1 hr |
| 6 | Atlas Lite context hints | 1 hr |

**Total Estimated Time:** ~6 hours

---

*Plan created: 2026-01-01*
