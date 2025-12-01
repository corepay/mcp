defmodule Mcp.Types.Any do
  @moduledoc """
  Custom Ash type for handling arbitrary JSON-compatible values.
  Wraps values in a map for storage in a JSONB column to support primitives.
  """

  use Ash.Type

  def storage_type(_), do: :map

  def cast_input(value, _), do: {:ok, value}

  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(%{"_wrapped_value" => value}, _), do: {:ok, value}
  # Fallback
  def cast_stored(value, _), do: {:ok, value}

  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(value, _), do: {:ok, %{"_wrapped_value" => value}}
end
