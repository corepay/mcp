defmodule McpWeb.Ola.StatusLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Ola.Components.StatusTracker

  describe "StatusTracker component" do
    test "displays under_review status correctly" do
      html = render_component(StatusTracker, id: "test", status: :under_review)

      assert html =~ "Submitted"
      assert html =~ "Under Review"
      assert html =~ "In Progress"
    end

    test "displays submitted status correctly" do
      html = render_component(StatusTracker, id: "test", status: :submitted)

      assert html =~ "Application Received"
      # HTML entities - apostrophe becomes &#39;
      assert html =~ "received your application"
    end

    test "displays approved status correctly" do
      html = render_component(StatusTracker, id: "test", status: :approved)

      assert html =~ "Congratulations"
      assert html =~ "Approved"
    end

    test "displays rejected status correctly" do
      html = render_component(StatusTracker, id: "test", status: :rejected)

      assert html =~ "Not Approved"
    end

    test "shows completed checkmarks for past steps" do
      html = render_component(StatusTracker, id: "test", status: :manual_review)

      # Submitted and Under Review should be complete (have check icon)
      assert html =~ "hero-check"
      # Manual review should be in progress
      assert html =~ "Final Review"
      assert html =~ "In Progress"
    end
  end
end
