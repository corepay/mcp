defmodule Mcp.Platform.Geo do
  @moduledoc """
  Geographic operations using PostGIS extension.
  Provides tenant-isolated spatial queries and analysis.
  """

  alias Mcp.Infrastructure.Context
  alias Mcp.Repo

  @tenant_schema_prefix "acq_"

  @doc """
  Adds a geometry column to an existing table.
  """
  def add_geometry_column(
        tenant_schema_name,
        table_name,
        column_name,
        geometry_type,
        srid \\ 4326
      ) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT AddGeometryColumn('#{table_name}', '#{column_name}', #{srid}, '#{geometry_type}', 2)
      """

      Repo.query(query)
    end)
  end

  @doc """
  Finds merchants within a given radius of a point.
  Returns results ordered by distance.
  """
  def find_nearby_merchants(tenant_schema_name, longitude, latitude, radius_km \\ 10) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT *,
        ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)) * 111.32 as distance_km
      FROM merchants
      WHERE ST_DWithin(
        location,
        ST_SetSRID(ST_MakePoint($1, $2), 4326),
        $3 * 1000  -- Convert km to meters
      )
      ORDER BY distance_km
      """

      Repo.query(query, [longitude, latitude, radius_km])
    end)
  end

  @doc """
  Creates a GIST spatial index on a geometry column.
  """
  def create_geographic_index(tenant_schema_name, table_name, column_name, index_name \\ nil) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name
    index_name = index_name || "#{table_name}_#{column_name}_geo_idx"

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CREATE INDEX #{index_name}
      ON #{table_name}
      USING GIST (#{column_name})
      """

      Repo.query(query)
    end)
  end

  @doc """
  Calculates the convex hull coverage area for a merchant's locations.
  """
  def merchant_coverage_area(tenant_schema_name, merchant_id) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        ST_ConvexHull(
          ST_Collect(
            ST_SetSRID(ST_MakePoint(ST_X(location), ST_Y(location)), 4326)
          )
        ) as coverage_area
      FROM merchants
      WHERE id = $1
      """

      Repo.query(query, [merchant_id])
    end)
  end

  @doc """
  Analyzes the geographic distribution of merchants.
  Returns center point, bounding box, and statistical measures.
  """
  def analyze_geographic_distribution(tenant_schema_name) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        ST_Centroid(ST_Collect(location)) as center_point,
        ST_Extent(ST_Collect(location)) as bounding_box,
        COUNT(*) as merchant_count,
        AVG(ST_X(location)) as avg_longitude,
        AVG(ST_Y(location)) as avg_latitude,
        STDDEV(ST_X(location)) as longitude_stddev,
        STDDEV(ST_Y(location)) as latitude_stddev
      FROM merchants
      WHERE location IS NOT NULL
      """

      Repo.query(query)
    end)
  end
end
