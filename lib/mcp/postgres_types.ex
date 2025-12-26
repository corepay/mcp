Postgrex.Types.define(
  Mcp.PostgresTypes,
  [Geo.PostGIS.Extension, Pgvector.Extensions.Vector] ++
    Ecto.Adapters.Postgres.extensions(),
  []
)
