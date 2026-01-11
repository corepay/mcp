defmodule McpWeb.Portals.Merchant.ComponentsTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portals.Merchant.Components

  describe "context_switcher/1" do
    test "renders current context with merchant name" do
      assigns = %{
        current_name: "Acme Corp",
        current_type: :merchant,
        stores: [
          %{name: "Downtown Store", slug: "downtown"},
          %{name: "Online Shop", slug: "online"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <Components.context_switcher
          current_name={@current_name}
          current_type={@current_type}
          stores={@stores}
        />
        """)

      assert html =~ "Acme Corp"
      assert html =~ "Downtown Store"
      assert html =~ "Online Shop"
      assert html =~ "dropdown"
    end

    test "renders with store context" do
      assigns = %{
        current_name: "Downtown Store",
        current_type: :store,
        merchant_name: "Acme Corp",
        stores: []
      }

      html =
        rendered_to_string(~H"""
        <Components.context_switcher
          current_name={@current_name}
          current_type={@current_type}
          merchant_name={@merchant_name}
          stores={@stores}
        />
        """)

      assert html =~ "Downtown Store"
      assert html =~ "Acme Corp"
    end

    test "shows new store link" do
      assigns = %{
        current_name: "Acme Corp",
        current_type: :merchant,
        stores: []
      }

      html =
        rendered_to_string(~H"""
        <Components.context_switcher
          current_name={@current_name}
          current_type={@current_type}
          stores={@stores}
        />
        """)

      assert html =~ "New Store"
    end
  end
end
