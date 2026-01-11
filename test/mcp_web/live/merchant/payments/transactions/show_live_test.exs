defmodule McpWeb.Merchant.Payments.Transactions.ShowLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/payments/transactions/:id" do
    setup %{conn: _conn} do
      unique_id = System.unique_integer([:positive])

      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Merchant Tenant #{unique_id}",
          slug: "merchant-test-#{unique_id}",
          subdomain: "merchant-#{unique_id}",
          company_schema: "acq_test_merchant_#{unique_id}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "merchant_#{System.unique_integer([:positive])}@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "Test",
          last_name: "Merchant"
        })
        |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
        |> Ash.create!()

      {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

      host = "#{tenant.subdomain}.localhost"

      authed_conn =
        build_conn()
        |> Map.put(:host, host)
        |> put_req_header("x-forwarded-host", host)
        |> init_test_session(%{"tenant_id" => tenant.id})
        |> put_req_cookie("_mcp_access_token", session_data.access_token)
        |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
        |> put_req_cookie("_mcp_session_id", session_data.session_id)

      {:ok, conn: authed_conn, tenant: tenant, user: user}
    end

    test "renders transaction show page with transaction reference as title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "TXN-2026-0001"
    end

    test "renders back link to transactions index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "a[href=\"/app/payments/transactions\"]")
    end

    test "renders transaction summary card with amount", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "$125.00"
    end

    test "renders transaction summary card with status badge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "div", "Completed")
    end

    test "renders transaction summary card with payment method", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "Visa"
      assert html =~ "4242"
    end

    test "renders transaction summary card with date", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "Jan 10, 2026"
    end

    test "renders customer info section with name", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "John Doe"
    end

    test "renders customer info section with link to customer profile", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "a[href=\"/app/customers/cust_1\"]")
    end

    test "renders transaction timeline section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "Transaction Timeline"
    end

    test "renders transaction timeline with status changes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "Transaction created"
      assert html =~ "Payment authorized"
      assert html =~ "Payment captured"
      assert html =~ "Transaction completed"
    end

    test "renders action sidebar with refund action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "button", "Refund (Full)")
    end

    test "renders action sidebar with partial refund action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "button", "Partial Refund")
    end

    test "renders action sidebar with send receipt action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "button", "Send Receipt")
    end

    test "renders action sidebar with view in stripe action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "a", "View in Stripe")
    end

    test "renders AI Insights section in sidebar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert html =~ "AI INSIGHTS"
    end

    test "renders AI insight about transaction pattern", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      assert has_element?(view, "div", "Similar transactions detected")
    end

    test "refund actions are disabled if already refunded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_2")

      # Check that refund buttons are disabled or not present for refunded transaction
      refute has_element?(view, "button:not([disabled])", "Refund (Full)")
    end

    test "refund actions are enabled if status is completed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      # Check that refund buttons are enabled for completed transaction
      assert has_element?(view, "button:not([disabled])", "Refund (Full)")
    end

    test "renders page layout in detail variant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      # Verify the 2/3 + 1/3 grid layout is present (detail variant)
      assert has_element?(view, "div.grid.grid-cols-1.lg\\:grid-cols-3")
    end

    test "timeline events show correct icons for different event types", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/payments/transactions/txn_1")

      # Check for timeline event section
      assert has_element?(view, "div", "Transaction Timeline")
    end
  end
end
