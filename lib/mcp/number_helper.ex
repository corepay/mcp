defmodule Mcp.NumberHelper do
  @moduledoc """
  Number formatting helpers.
  """

  @doc """
  Formats a number as currency.
  """
  def number_to_currency(number) do
    # Simple currency formatting - uses basic string formatting
    :erlang.float_to_binary(number / 1, decimals: 2)
  end

  @doc """
  Formats a number with thousands delimiters.
  """
  def number_to_delimited(number, opts \\ []) do
    precision = Keyword.get(opts, :precision, if(is_float(number), do: 2, else: 0))

    number_str =
      if is_float(number) do
        :erlang.float_to_binary(number, decimals: precision)
      else
        Integer.to_string(number)
      end

    # Add thousands separators
    case String.split(number_str, ".") do
      [integer_part, decimal_part] ->
        delimit_integer_part(integer_part) <> "." <> decimal_part
      [integer_part] ->
        delimit_integer_part(integer_part)
    end
  end

  defp delimit_integer_part(str) do
    str
    |> String.reverse()
    |> String.chunk(3)
    |> Enum.intersperse(",")
    |> Enum.join()
    |> String.reverse()
  end
end