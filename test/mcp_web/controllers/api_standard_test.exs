defmodule McpWeb.ApiStandardTest do
  use McpWeb.ConnCase

  describe "API Response Standards" do
    test "404 Not Found returns standard error format", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/non_existent_route")
      
      assert %{"error" => %{"code" => "error", "message" => "Not Found", "details" => nil}} = json_response(conn, 404)
    end

    test "Validation error returns standard error format", %{conn: conn} do
      # Trigger a validation error via a dummy changeset in FallbackController
      # Since we can't easily invoke FallbackController directly without a controller action,
      # we'll rely on unit testing the view directly for this part.
      changeset = 
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{}, [:name])
        |> Ecto.Changeset.validate_required([:name])

      json = McpWeb.ChangesetJSON.error(%{changeset: changeset})
      
      assert %{
        error: %{
          code: "validation_error",
          message: "Validation failed",
          details: %{name: ["can't be blank"]}
        }
      } = json
    end
  end
end
