defmodule McpWeb.PageControllerTest do
  use McpWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET /", %{conn: conn} do
    # Set host to localhost to get platform context
    # The root path now routes to LandingLive, not PageController
    {:ok, _view, html} =
      %{conn | host: "localhost"}
      |> live(~p"/")

    assert html =~ "Welcome to your"
  end
end
