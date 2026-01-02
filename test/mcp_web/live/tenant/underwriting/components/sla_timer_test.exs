defmodule McpWeb.Tenant.Underwriting.Components.SlaTimerTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Tenant.Underwriting.Components.SlaTimer

  describe "render_component/2" do
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

    test "displays success state when more than 1 hour" do
      due_at = DateTime.add(DateTime.utc_now(), 90, :minute)

      html = render_component(SlaTimer, id: "test", due_at: due_at)

      assert html =~ "left"
      assert html =~ "text-success"
    end

    test "shows hours and minutes for long durations" do
      due_at = DateTime.add(DateTime.utc_now(), 150, :minute)

      html = render_component(SlaTimer, id: "test", due_at: due_at)

      assert html =~ "2h"
      assert html =~ "30m"
    end
  end
end
