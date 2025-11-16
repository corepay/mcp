defmodule McpWeb.PageController do
  use McpWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
