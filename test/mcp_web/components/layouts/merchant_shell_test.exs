defmodule McpWeb.Layouts.MerchantShellTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Layouts.MerchantShell

  describe "merchant_shell/1" do
    test "renders shell with navbar and content" do
      assigns = %{
        merchant_name: "Acme Corp",
        stores: [],
        current_path: "/app",
        user_initials: "JD"
      }

      html =
        rendered_to_string(~H"""
        <MerchantShell.merchant_shell
          merchant_name={@merchant_name}
          stores={@stores}
          current_path={@current_path}
          user_initials={@user_initials}
        >
          <p>Dashboard content</p>
        </MerchantShell.merchant_shell>
        """)

      assert html =~ "navbar"
      assert html =~ "Acme Corp"
      assert html =~ "Dashboard"
      assert html =~ "Dashboard content"
    end

    test "renders nav items with active state" do
      assigns = %{
        merchant_name: "Acme Corp",
        stores: [],
        current_path: "/app/products",
        user_initials: "JD"
      }

      html =
        rendered_to_string(~H"""
        <MerchantShell.merchant_shell
          merchant_name={@merchant_name}
          stores={@stores}
          current_path={@current_path}
          user_initials={@user_initials}
        >
          <p>Content</p>
        </MerchantShell.merchant_shell>
        """)

      assert html =~ "Products"
    end

    test "renders with sidebar for sections that need it" do
      assigns = %{
        merchant_name: "Acme Corp",
        stores: [],
        current_path: "/app/payments",
        user_initials: "JD"
      }

      html =
        rendered_to_string(~H"""
        <MerchantShell.merchant_shell
          merchant_name={@merchant_name}
          stores={@stores}
          current_path={@current_path}
          user_initials={@user_initials}
        >
          <:sidebar>
            <li><a>Transactions</a></li>
          </:sidebar>
          <p>Payments content</p>
        </MerchantShell.merchant_shell>
        """)

      assert html =~ "Transactions"
    end
  end
end
