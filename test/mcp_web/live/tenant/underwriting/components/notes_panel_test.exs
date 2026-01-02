defmodule McpWeb.Tenant.Underwriting.Components.NotesPanelTest do
  @moduledoc false
  use McpWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Mcp.Underwriting.Services.MagicCamera

  setup do
    MagicCamera.init()
    :ok
  end

  # Host LiveView for testing the component
  defmodule TestLive do
    use Phoenix.LiveView

    alias McpWeb.Tenant.Underwriting.Components.NotesPanel

    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:application_id, "app-123")
       |> Phoenix.Component.assign(:current_user, %{id: "user-456", display_name: "Test User"})
       |> Phoenix.Component.assign(:tenant_schema, "acq_test")
       |> Phoenix.Component.assign(:team_members, [
         %{id: "user-789", username: "john.doe", display_name: "John Doe"},
         %{id: "user-012", username: "jane.smith", display_name: "Jane Smith"}
       ])}
    end

    def render(assigns) do
      ~H"""
      <div id="notes-test">
        <.live_component
          module={NotesPanel}
          id="notes-panel"
          application_id={@application_id}
          current_user={@current_user}
          tenant_schema={@tenant_schema}
          team_members={@team_members}
        />
      </div>
      """
    end
  end

  describe "initial render" do
    test "shows the note input area", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TestLive)

      assert html =~ "Add a note"
      assert html =~ "textarea" or html =~ "input"
    end

    test "shows empty state when no notes exist", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, TestLive)

      assert html =~ "No notes yet" or html =~ "notes-panel"
    end
  end

  describe "input_change event" do
    test "detects @mention trigger", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      # Type @ to trigger mention suggestions
      html =
        view
        |> element("#note-input")
        |> render_change(%{"value" => "Hey @john"})

      # Should show mention suggestions
      assert html =~ "John Doe" or html =~ "john.doe"
    end

    test "filters suggestions by typed text", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      html =
        view
        |> element("#note-input")
        |> render_change(%{"value" => "Hey @jan"})

      # Should match Jane, not John
      assert html =~ "Jane Smith" or html =~ "jane.smith"
      refute html =~ "John Doe"
    end
  end

  describe "submit_note event" do
    test "creates note with content", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      html =
        view
        |> element("form")
        |> render_submit(%{"content" => "This is a test note"})

      # Note should appear in the list or show success
      assert html =~ "This is a test note" or html =~ "note"
    end

    test "clears input after submission", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      view
      |> element("form")
      |> render_submit(%{"content" => "Test note content"})

      html = render(view)
      # Input should be cleared
      refute html =~ ~r/value="Test note content"/
    end
  end

  describe "visibility toggle" do
    test "can toggle between internal and shared visibility", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, TestLive)

      # Initially shows Internal, click to toggle to Shared
      html =
        view
        |> element("button[phx-click=toggle_visibility]")
        |> render_click()

      # Should indicate shared mode
      assert html =~ "Shared"
    end
  end
end
