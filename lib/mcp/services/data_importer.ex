defmodule Mcp.Services.DataImporter do
  @moduledoc """
  Service for importing data.
  """



  def read_data(:json, %{"file_path" => path}) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> parse_json(content)
        {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
      end
    else
      {:error, "File not found: #{path}"}
    end
  end

  def read_data(:json, %{"content" => content}) do
    parse_json(content)
  end

  def read_data(:csv, %{"file_path" => path} = config) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> parse_csv(content, config)
        {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
      end
    else
      {:error, "File not found: #{path}"}
    end
  end

  def read_data(:csv, %{"content" => content} = config) do
    parse_csv(content, config)
  end

  def read_data(_format, _config), do: {:error, "Unsupported import format"}

  def read_and_detect_format(path) do
    if File.exists?(path) do
      ext = Path.extname(path) |> String.downcase()
      case ext do
        ".json" -> read_data(:json, %{"file_path" => path})
        ".csv" -> read_data(:csv, %{"file_path" => path})
        _ -> 
          # Try to detect by content
          case File.read(path) do
            {:ok, content} ->
              if String.starts_with?(String.trim(content), "[") or String.starts_with?(String.trim(content), "{") do
                read_data(:json, %{"content" => content})
              else
                # Default to CSV if not JSON-like
                read_data(:csv, %{"content" => content})
              end
            {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
          end
      end
    else
      {:error, "File not found: #{path}"}
    end
  end

  def infer_data_types(data) when is_list(data) and data != [] do
    # Sample first 10 records
    sample = Enum.take(data, 10)
    keys = get_fields(sample)
    
    Enum.reduce(keys, %{}, fn key, acc ->
      types = Enum.map(sample, fn record -> 
        val = Map.get(record, key)
        infer_type(val)
      end) 
      |> Enum.filter(&(&1 != "empty")) # Ignore empty values
      |> Enum.uniq()
      
      final_type = if length(types) == 1, do: hd(types), else: "string"
      # If mixed, fallback to string unless it's nil + type
      final_type = if "string" in types, do: "string", else: final_type
      # If all were empty, default to string
      final_type = if types == [], do: "string", else: final_type
      
      Map.put(acc, key, final_type)
    end)
  end
  def infer_data_types(_), do: %{}

  def validate_required_keys(data, keys) do
    missing = Enum.reduce(data, MapSet.new(), fn record, acc ->
      record_keys = Map.keys(record) |> MapSet.new()
      required = MapSet.new(keys)
      if MapSet.subset?(required, record_keys) do
        acc
      else
        MapSet.union(acc, MapSet.difference(required, record_keys))
      end
    end)

    if MapSet.size(missing) == 0 do
      :ok
    else
      {:error, "Missing required keys: #{Enum.join(missing, ", ")}"}
    end
  end

  def validate_data_size(data, max_records) do
    count = length(data)
    if count <= max_records do
      :ok
    else
      {:error, "Data size #{count} exceeds limit of #{max_records}"}
    end
  end

  def get_data_metadata(data) when is_list(data) do
    %{
      record_count: length(data),
      fields: get_fields(data),
      has_nil_values: has_nil_values?(data),
      sample_types: infer_data_types(data),
      sample_record: List.first(data)
    }
  end
  def get_data_metadata(_), do: %{record_count: 0, fields: [], has_nil_values: false, sample_types: %{}, sample_record: nil}

  def get_sample_records(data, sample_size) when is_list(data) do
    Enum.take(data, sample_size)
  end
  def get_sample_records(_, _), do: []

  # Private Helpers

  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, data} when is_list(data) -> {:ok, data}
      {:ok, _} -> {:error, "JSON must be a list of objects"}
      {:error, _} -> {:error, "JSON parsing failed"}
    end
  end

  defp parse_csv(content, config) do
    delimiter = Map.get(config, "delimiter", ",")
    
    # Simple CSV parsing for now, assuming headers
    lines = String.split(content, "\n", trim: true)
    if length(lines) > 0 do
      headers = hd(lines) |> String.split(delimiter) |> Enum.map(&String.trim/1)
      
      data = Enum.drop(lines, 1) |> Enum.map(fn line ->
        values = String.split(line, delimiter) |> Enum.map(&String.trim/1)
        
        # Zip headers with values
        Enum.zip(headers, values) |> Enum.into(%{})
      end)
      
      {:ok, data}
    else
      {:ok, []}
    end
  end

  defp infer_type(val) when is_integer(val), do: "integer"
  defp infer_type(val) when is_float(val), do: "float"
  defp infer_type(val) when is_boolean(val), do: "boolean"
  defp infer_type(val) when is_binary(val) do
    cond do
      val == "" -> "empty"
      Regex.match?(~r/^\d+$/, val) -> "integer"
      Regex.match?(~r/^\d+\.\d+$/, val) -> "float"
      val in ["true", "false", "yes", "no"] -> "boolean"
      true -> "string"
    end
  end
  defp infer_type(nil), do: "empty" # Treat nil as empty
  defp infer_type(_), do: "string"

  defp get_fields([]), do: []
  defp get_fields([head | _]) when is_map(head), do: Map.keys(head)
  defp get_fields(_), do: []

  defp has_nil_values?(data) do
    Enum.any?(data, fn record ->
      is_map(record) and Enum.any?(Map.values(record), &is_nil/1)
    end)
  end
end
