defmodule Mcp.Types.Inet do
  @moduledoc """
  Custom Ash type for handling INET (IP Address) data types.

  This type provides proper casting and dumping for PostgreSQL INET types,
  supporting both IPv4 and IPv6 addresses.
  """

  use Ash.Type

  def storage_type(_), do: :inet

  def cast_input(value, _) do
    case value do
      %Postgrex.INET{} = inet -> {:ok, inet}
      binary when is_binary(binary) ->
        case :inet.parse_address(String.to_charlist(binary)) do
          {:ok, tuple} -> {:ok, %Postgrex.INET{address: tuple}}
          _ -> :error
        end
      _ -> :error
    end
  end

  def cast_stored(value, _), do: {:ok, value}

  def dump_to_native(value, _), do: {:ok, value}
end
