defmodule McpWeb.Layouts.StoreShellTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Layouts.StoreShell

  describe "store_shell/1" do
    test "renders shell with sidebar and content" do
      assigns = %{
        store_name: "Downtown Store",
        store_slug: "downtown",
        merchant_name: "Acme Corp",
        current_path: "/app/stores/downtown",
        user_initials: "JD",
        vertical: :retail
      }

      html =
        rendered_to_string(~H"""
        <StoreShell.store_shell
          store_name={@store_name}
          store_slug={@store_slug}
          merchant_name={@merchant_name}
          current_path={@current_path}
          user_initials={@user_initials}
          vertical={@vertical}
        >
          <p>Store content</p>
        </StoreShell.store_shell>
        """)

      assert html =~ "Downtown Store"
      assert html =~ "Dashboard"
      assert html =~ "POS"
      assert html =~ "Store content"
    end

    test "renders grouped nav sections" do
      assigns = %{
        store_name: "Downtown Store",
        store_slug: "downtown",
        merchant_name: "Acme Corp",
        current_path: "/app/stores/downtown",
        user_initials: "JD",
        vertical: :retail
      }

      html =
        rendered_to_string(~H"""
        <StoreShell.store_shell
          store_name={@store_name}
          store_slug={@store_slug}
          merchant_name={@merchant_name}
          current_path={@current_path}
          user_initials={@user_initials}
          vertical={@vertical}
        >
          <p>Content</p>
        </StoreShell.store_shell>
        """)

      assert html =~ "SELL"
      assert html =~ "MANAGE"
    end

    test "renders shift info" do
      assigns = %{
        store_name: "Store",
        store_slug: "store",
        merchant_name: "Merchant",
        current_path: "/app/stores/store",
        user_initials: "JD",
        vertical: :retail,
        shift_start: "2:00 PM"
      }

      html =
        rendered_to_string(~H"""
        <StoreShell.store_shell
          store_name={@store_name}
          store_slug={@store_slug}
          merchant_name={@merchant_name}
          current_path={@current_path}
          user_initials={@user_initials}
          vertical={@vertical}
          shift_start={@shift_start}
        >
          <p>Content</p>
        </StoreShell.store_shell>
        """)

      assert html =~ "2:00 PM"
    end
  end
end
