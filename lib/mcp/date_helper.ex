defmodule Mcp.DateHelper do
  @moduledoc """
  Date parsing and formatting helpers.
  """

  @doc """
  Parses a date string using common formats.
  """
  def parse_datetime(string) when is_binary(string) do
    formats = [
      "%Y-%m-%d %H:%M:%S",
      "%Y-%m-%d %H:%M",
      "%Y-%m-%d",
      "%m/%d/%Y %H:%M:%S",
      "%m/%d/%Y %H:%M",
      "%m/%d/%Y",
      "%d/%m/%Y %H:%M:%S",
      "%d/%m/%Y %H:%M",
      "%d/%m/%Y",
      "%B %d, %Y",
      "%b %d, %Y"
    ]

    Enum.reduce_while(formats, {:error, "No matching date format"}, fn format, _acc ->
      case parse_with_format(string, format) do
        {:ok, datetime} -> {:halt, {:ok, datetime}}
        {:error, _reason} -> {:cont, {:error, "No matching date format"}}
      end
    end)
  rescue
    _error -> {:error, "Date parsing failed"}
  end

  defp parse_with_format(string, "%Y-%m-%d %H:%M:%S") do
    case DateTime.from_iso8601("#{string}:00Z") do
      {:ok, datetime, _} -> {:ok, datetime}
      error -> error
    end
  catch
    :exit, _ -> {:error, "parse error"}
  end

  defp parse_with_format(string, "%Y-%m-%d %H:%M") do
    case DateTime.from_iso8601("#{string}:00Z") do
      {:ok, datetime, _} -> {:ok, datetime}
      error -> error
    end
  catch
    :exit, _ -> {:error, "parse error"}
  end

  defp parse_with_format(string, "%Y-%m-%d") do
    case DateTime.from_iso8601("#{string}T00:00:00Z") do
      {:ok, datetime, _} -> {:ok, datetime}
      error -> error
    end
  catch
    :exit, _ -> {:error, "parse error"}
  end

  defp parse_with_format(_string, _format) do
    # For other formats, return error for now
    {:error, "unsupported format"}
  end

  @doc """
  Formats a DateTime to string.
  """
  def format_datetime(datetime) do
    DateTime.to_string(datetime)
  end

  @doc """
  Gets current UTC datetime.
  """
  def utc_now do
    DateTime.utc_now()
  end
end
