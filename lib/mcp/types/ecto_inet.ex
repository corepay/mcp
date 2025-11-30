defmodule Mcp.Types.EctoInet do
  @moduledoc """
  Custom Ecto type for handling INET (IP Address) data types.
  """
  use Ecto.Type

  def type, do: :inet

  def cast(value) do
    case value do
      %Postgrex.INET{} = inet ->
        {:ok, inet}

      binary when is_binary(binary) ->
        case :inet.parse_address(String.to_charlist(binary)) do
          {:ok, tuple} -> {:ok, %Postgrex.INET{address: tuple}}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  def load(value), do: {:ok, value}

  def dump(value), do: {:ok, value}
end
