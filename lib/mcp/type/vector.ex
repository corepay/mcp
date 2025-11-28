defmodule Mcp.Type.Vector do
  @moduledoc """
  Custom Ash Type for Vector to handle compatibility between Ash.Vector and Pgvector.
  """
  use Ash.Type

  def storage_type, do: :vector

  def constraints do
    [
      dimensions: [
        type: :pos_integer,
        doc: "The number of dimensions in the vector"
      ]
    ]
  end

  def cast_input(value, constraints), do: Ash.Type.Vector.cast_input(value, constraints)

  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(%Pgvector{} = value, _constraints) do
    list = Pgvector.to_list(value)
    {:ok, Ash.Vector.new(list)}
  end

  def cast_stored(value, constraints), do: Ash.Type.Vector.cast_stored(value, constraints)

  def dump_to_native(nil, _), do: {:ok, nil}

  def dump_to_native(%Ash.Vector{} = value, _constraints) do
    {:ok, Ash.Vector.to_list(value)}
  end

  def dump_to_native(value, constraints), do: Ash.Type.Vector.dump_to_native(value, constraints)
end
