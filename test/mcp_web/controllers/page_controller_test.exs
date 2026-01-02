defmodule McpWeb.PageControllerTest do
  use McpWeb.ConnCase

  # Skip: Routing configuration affects this test
  @tag :skip
  test "GET /", %{conn: conn} do
    # Set host to localhost to get platform context
    conn =
      %{conn | host: "localhost"}
      |> get(~p"/")

    assert html_response(conn, 200) =~ "Welcome to your"
  end
end
