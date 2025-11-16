defmodule Mcp.Repo do
  use Ecto.Repo,
    otp_app: :mcp,
    adapter: Ecto.Adapters.Postgres
end
