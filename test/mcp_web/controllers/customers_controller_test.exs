defmodule McpWeb.CustomersControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Customer

  setup %{conn: conn} do
    %{conn: Plug.Conn.put_req_header(conn, "x-forwarded-host", "localhost")}
  end

  describe "POST /api/customers" do
    test "creates a customer successfully", %{conn: conn} do
      params = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "phone" => "+15555555555"
      }

      conn = post(conn, ~p"/api/customers", params)

      assert %{"status" => "success", "data" => data} = json_response(conn, 201)
      assert data["email"] == "test@example.com"
      assert data["name"] == "Test User"
    end
  end

  describe "GET /api/customers/:id" do
    test "retrieves a customer", %{conn: conn} do
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
        |> Ash.create!()

      conn = get(conn, ~p"/api/customers/#{customer.id}")

      assert %{"status" => "success", "data" => data} = json_response(conn, 200)
      assert data["id"] == customer.id
      assert data["email"] == "test@example.com"
    end
  end

  describe "POST /api/customers/:id (Update)" do
    test "updates a customer", %{conn: conn} do
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
        |> Ash.create!()

      params = %{"name" => "Updated Name"}

      conn = post(conn, ~p"/api/customers/#{customer.id}", params)

      assert %{"status" => "success", "data" => data} = json_response(conn, 200)
      assert data["name"] == "Updated Name"
    end
  end

  describe "DELETE /api/customers/:id" do
    test "deletes a customer", %{conn: conn} do
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
        |> Ash.create!()

      conn = delete(conn, ~p"/api/customers/#{customer.id}")

      assert %{"status" => "success", "message" => "Customer deleted"} = json_response(conn, 200)

      assert {:error, _} = Customer.by_id(customer.id)
    end
  end
end
