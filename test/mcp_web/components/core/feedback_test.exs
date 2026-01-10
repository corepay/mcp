# test/mcp_web/components/core/feedback_test.exs
defmodule McpWeb.Core.FeedbackTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Core.Feedback

  describe "skeleton/1" do
    test "renders default skeleton" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton />
        """)

      assert html =~ "skeleton"
      assert html =~ "animate-pulse"
    end

    test "renders with variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton variant="text" />
        """)

      assert html =~ "h-4"
    end

    test "renders circle variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton variant="circle" />
        """)

      assert html =~ "rounded-full"
    end

    test "renders with custom dimensions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton width="w-32" height="h-8" />
        """)

      assert html =~ "w-32"
      assert html =~ "h-8"
    end
  end

  describe "skeleton_stat_card/1" do
    test "renders stat card skeleton" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Feedback.skeleton_stat_card />
        """)

      assert html =~ "skeleton"
      assert html =~ "stat"
    end
  end
end
