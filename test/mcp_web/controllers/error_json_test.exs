defmodule McpWeb.ErrorJSONTest do
  use McpWeb.ConnCase, async: true

  test "renders 404" do
    assert McpWeb.ErrorJSON.render("404.json", %{}) == %{
             error: %{code: "error", message: "Not Found", details: nil}
           }
  end

  test "renders 500" do
    assert McpWeb.ErrorJSON.render("500.json", %{}) == %{
             error: %{code: "error", message: "Internal Server Error", details: nil}
           }
  end
end
