defmodule McpWeb.GdprLive do
  @moduledoc """
  LiveView for GDPR management portal.

  This LiveView provides users with comprehensive GDPR compliance features including:
  - Data export requests (data portability)
  - Account deletion requests (right to be forgotten)
  - Consent management
  - Audit trail viewing
  - Privacy settings management
  """

  use McpWeb, :live_view

  require Logger

  alias Mcp.Accounts.UserSchema
  alias Mcp.Gdpr.Compliance
  alias Mcp.Repo
  alias McpWeb.GdprComponents

  @impl true
  def mount(_params, %{"current_user" => current_user}, socket) do
    if current_user do
      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:page_title, "Privacy & Data Management")
       |> assign(:active_tab, "overview")
       |> assign(:loading, false)
       |> assign(:flash_messages, [])
       |> load_gdpr_data()}
    else
      # No valid session, redirect to sign in
      {:ok, push_navigate(socket, to: ~p"/sign_in")}
    end
  end

  def mount(_params, _session, socket) do
    # No valid session, redirect to sign in
    {:ok, push_navigate(socket, to: ~p"/sign_in")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    active_tab = Map.get(params, "tab", "overview")
    {:noreply, assign(socket, :active_tab, active_tab)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> push_patch(to: ~p"/gdpr?tab=#{tab}")}
  end

  # Data export events
  def handle_event("request_export", %{"format" => format}, socket) do
    user = socket.assigns.current_user

    case Compliance.request_user_data_export(user.id, format, user.id) do
      {:ok, _export} ->
        Logger.info("Data export requested for user #{user.id}, format: #{format}")

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Data export request accepted. You will be notified when it's ready for download."
         )
         |> load_gdpr_data()}

      {:error, reason} ->
        Logger.error("Failed to request data export for user #{user.id}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to request data export. Please try again.")}
    end
  end

  # Deletion request events
  def handle_event("request_deletion", %{"reason" => reason}, socket) do
    user = socket.assigns.current_user

    case Compliance.request_user_deletion(user.id, reason, user.id) do
      {:ok, _updated_user} ->
        Logger.info("User #{user.id} requested account deletion, reason: #{reason}")

        {:noreply,
         socket
         |> put_flash(
           :warning,
           "Account deletion request processed. Your account will be deleted after the retention period. You can cancel this request within 90 days."
         )
         |> load_gdpr_data()}

      {:error, reason} ->
        Logger.error("Failed to process deletion request for user #{user.id}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to process deletion request. Please try again.")}
    end
  end

  def handle_event("cancel_deletion", _params, socket) do
    user = socket.assigns.current_user

    case Compliance.cancel_user_deletion(user.id, user.id) do
      {:ok, _restored_user} ->
        Logger.info("User #{user.id} cancelled account deletion request")

        {:noreply,
         socket
         |> put_flash(:info, "Account deletion request cancelled successfully.")
         |> load_gdpr_data()}

      {:error, reason} ->
        Logger.error("Failed to cancel deletion request for user #{user.id}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel deletion request. Please try again.")}
    end
  end

  # Consent management events
  def handle_event("update_consents", %{"consents" => consent_params}, socket) do
    user = socket.assigns.current_user
    actor_id = user.id

    case validate_and_update_consents(user.id, consent_params, actor_id) do
      {:ok, updated_consents} ->
        Logger.info("User #{user.id} updated consent preferences")

        {:noreply,
         socket
         |> put_flash(:info, "Consent preferences updated successfully.")
         |> assign(:consents, updated_consents)}

      {:error, reason} ->
        Logger.error("Failed to update consents for user #{user.id}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to update consent preferences. Please try again.")}
    end
  end

  # Private functions

  defp load_gdpr_data(socket) do
    user = socket.assigns.current_user

    # Load user deletion status
    deletion_status = get_user_deletion_status_for_display(user.id)

    # Load user consents
    consents =
      case Compliance.get_user_consents(user.id) do
        {:ok, user_consents} -> format_consents_for_display(user_consents)
        {:error, _} -> []
      end

    # Load recent audit trail
    audit_trail =
      case Compliance.get_user_audit_trail(user.id, 10) do
        {:ok, audits} -> format_audit_trail_for_display(audits)
        {:error, _} -> []
      end

    socket
    |> assign(:deletion_status, deletion_status)
    |> assign(:consents, consents)
    |> assign(:audit_trail, audit_trail)
  end

  defp get_user_deletion_status_for_display(user_id) do
    case Repo.get(UserSchema, user_id) do
      nil ->
        %{status: "not_found", deletable: false}

      user ->
        %{
          status: user.status,
          deleted_at: user.deleted_at,
          deletion_reason: user.deletion_reason,
          retention_expires_at: user.gdpr_retention_expires_at,
          anonymized_at: user.anonymized_at,
          deletable: user.status in ["active"]
        }
    end
  end

  defp format_consents_for_display(consents) do
    Enum.map(consents, fn consent ->
      %{
        id: consent.id,
        purpose: consent.purpose,
        status: consent.status,
        granted_at: consent.granted_at,
        withdrawn_at: consent.withdrawn_at,
        legal_basis: consent.legal_basis,
        display_name: get_consent_display_name(consent.purpose),
        description: get_consent_description(consent.purpose)
      }
    end)
  end

  defp format_audit_trail_for_display(audits) do
    Enum.map(audits, fn audit ->
      %{
        id: audit.id,
        action: audit.action,
        details: audit.details,
        created_at: audit.inserted_at,
        display_action: get_audit_action_display(audit.action)
      }
    end)
  end

  defp validate_and_update_consents(user_id, consent_params, actor_id) do
    with {:ok, validated} <- validate_consent_params(consent_params),
         {:ok, results} <- update_consent_records(user_id, validated, actor_id) do
      {:ok, Enum.map(results, fn {:ok, consent} -> consent end)}
    else
      {:error, _reason} = error -> error
    end
  end

  defp validate_consent_params(consent_params) do
    valid_purposes = ["marketing", "analytics", "essential", "third_party_sharing"]
    valid_statuses = ["granted", "denied", "withdrawn"]

    validated =
      Enum.reduce(consent_params, [], fn {purpose, status}, acc ->
        if purpose in valid_purposes and status in valid_statuses do
          [{purpose, status} | acc]
        else
          acc
        end
      end)

    if length(validated) == map_size(consent_params) do
      {:ok, validated}
    else
      {:error, :invalid_consent_params}
    end
  end

  defp update_consent_records(user_id, validated, actor_id) do
    results =
      Enum.map(validated, fn {purpose, status} ->
        Compliance.update_user_consent(user_id, purpose, status, actor_id)
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, results}
      error -> error
    end
  end

  defp get_consent_display_name("marketing"), do: "Marketing Communications"
  defp get_consent_display_name("analytics"), do: "Analytics and Tracking"
  defp get_consent_display_name("essential"), do: "Essential Services"
  defp get_consent_display_name("third_party_sharing"), do: "Third Party Sharing"
  defp get_consent_display_name(_), do: "Unknown"

  defp get_consent_description("marketing"),
    do: "Receive marketing emails and promotional content"

  defp get_consent_description("analytics"),
    do: "Allow analytics tracking for service improvement"

  defp get_consent_description("essential"), do: "Required for essential service functionality"

  defp get_consent_description("third_party_sharing"),
    do: "Share data with trusted third-party partners"

  defp get_consent_description(_), do: "No description available"

  defp get_audit_action_display("delete_request"), do: "Requested Account Deletion"
  defp get_audit_action_display("deletion_cancelled"), do: "Cancelled Account Deletion"
  defp get_audit_action_display("export_request"), do: "Requested Data Export"
  defp get_audit_action_display("consent_updated"), do: "Updated Consent Preferences"
  defp get_audit_action_display("account_created"), do: "Account Created"

  defp get_audit_action_display(action),
    do: String.replace(action, "_", " ") |> String.capitalize()

  # Date formatting helper functions - moved to GdprComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="container mx-auto px-4 py-8">
        <!-- Header -->
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-base-content">Privacy & Data Management</h1>
              <p class="text-base-content/70 mt-2">Manage your privacy settings and data rights</p>
            </div>
            <.link navigate="/dashboard" class="btn btn-outline btn-primary">
              <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Dashboard
            </.link>
          </div>
        </div>
        
    <!-- Flash Messages -->
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />
        
    <!-- Tab Navigation -->
        <div class="tabs tabs-boxed mb-8">
          <a
            class={"tab #{if @active_tab == "overview", do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="overview"
          >
            Overview
          </a>
          <a
            class={"tab #{if @active_tab == "data_export", do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="data_export"
          >
            Data Export
          </a>
          <a
            class={"tab #{if @active_tab == "account_deletion", do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="account_deletion"
          >
            Account Deletion
          </a>
          <a
            class={"tab #{if @active_tab == "consents", do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="consents"
          >
            Consents
          </a>
          <a
            class={"tab #{if @active_tab == "audit_trail", do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="audit_trail"
          >
            Audit Trail
          </a>
        </div>
        
    <!-- Component-based Content -->
        <.gdpr_content
          active_tab={@active_tab}
          current_user={@current_user}
          deletion_status={@deletion_status}
          consents={@consents}
          audit_trail={@audit_trail}
          loading={@loading}
        />
      </div>
    </div>
    """
  end

  # Component-based content renderer
  defp gdpr_content(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <%= case @active_tab do %>
          <% "overview" -> %>
            <.gdpr_overview
              deletion_status={@deletion_status}
              consents={@consents}
              audit_trail={@audit_trail}
              loading={@loading}
            />
          <% "data_export" -> %>
            <.gdpr_data_export current_user={@current_user} loading={@loading} />
          <% "account_deletion" -> %>
            <.gdpr_account_deletion
              deletion_status={@deletion_status}
              loading={@loading}
            />
          <% "consents" -> %>
            <.gdpr_consents
              consents={@consents}
              loading={@loading}
            />
          <% "audit_trail" -> %>
            <.gdpr_audit_trail audit_trail={@audit_trail} />
          <% _ -> %>
            <div class="text-center py-8">
              <p class="text-base-content/70">Invalid tab selected</p>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp gdpr_overview(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="card-title text-2xl">Privacy Overview</h2>

      <GdprComponents.overview_stats deletion_status={@deletion_status} consents={@consents} />
      <GdprComponents.quick_actions loading={@loading} />
      <GdprComponents.recent_activity audit_trail={@audit_trail} />
    </div>
    """
  end

  defp gdpr_data_export(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="card-title text-2xl">Data Export (Data Portability)</h2>

      <GdprComponents.data_export_form current_user={@current_user} loading={@loading} />
      
    <!-- Export Information -->
      <div class="divider">What's Included</div>
      <div class="grid md:grid-cols-2 gap-4">
        <div class="bg-base-200 p-4 rounded-lg">
          <h4 class="font-semibold mb-2">Personal Information</h4>
          <ul class="text-sm space-y-1 text-base-content/70">
            <li>• Name and email address</li>
            <li>• Account creation date</li>
            <li>• Profile information</li>
            <li>• Preferences and settings</li>
          </ul>
        </div>

        <div class="bg-base-200 p-4 rounded-lg">
          <h4 class="font-semibold mb-2">Activity Data</h4>
          <ul class="text-sm space-y-1 text-base-content/70">
            <li>• Login history</li>
            <li>• Actions and interactions</li>
            <li>• Generated content</li>
            <li>• Communication logs</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp gdpr_account_deletion(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="card-title text-2xl">Account Deletion (Right to be Forgotten)</h2>

      <GdprComponents.account_deletion_component
        deletion_status={@deletion_status}
        loading={@loading}
      />
    </div>
    """
  end

  defp gdpr_consents(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="card-title text-2xl">Consent Management</h2>

      <GdprComponents.consent_management_component consents={@consents} loading={@loading} />
    </div>
    """
  end

  defp gdpr_audit_trail(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="card-title text-2xl">Audit Trail</h2>

      <GdprComponents.audit_trail_component audit_trail={@audit_trail} />
    </div>
    """
  end
end
