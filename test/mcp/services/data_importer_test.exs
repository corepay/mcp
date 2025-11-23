defmodule Mcp.Services.DataImporterTest do
  @moduledoc """
  Unit tests for DataImporter service.
  """

  use ExUnit.Case, async: true
  alias Mcp.Services.DataImporter

  describe "read_data/2" do
    test "reads JSON data from file" do
      json_content = ~s([{"name": "John", "email": "john@example.com"}])
      temp_file = write_temp_file("test.json", json_content)

      try do
        config = %{"file_path" => temp_file}
        result = DataImporter.read_data(:json, config)

        assert {:ok, data} = result
        assert is_list(data)
        assert length(data) == 1
        assert hd(data)["name"] == "John"
        assert hd(data)["email"] == "john@example.com"
      after
        File.rm(temp_file)
      end
    end

    test "reads JSON data from content" do
      json_content = ~s([{"name": "Jane", "age": 30}])
      config = %{"content" => json_content}

      result = DataImporter.read_data(:json, config)

      assert {:ok, data} = result
      assert is_list(data)
      assert hd(data)["name"] == "Jane"
      assert hd(data)["age"] == 30
    end

    test "reads CSV data from file" do
      csv_content = "name,email,age\nJohn,john@example.com,25\nJane,jane@example.com,30"
      temp_file = write_temp_file("test.csv", csv_content)

      try do
        config = %{"file_path" => temp_file}
        result = DataImporter.read_data(:csv, config)

        assert {:ok, data} = result
        assert is_list(data)
        assert length(data) == 2
        assert hd(data)["name"] == "John"
        assert hd(data)["email"] == "john@example.com"
        assert hd(data)["age"] == "25"
      after
        File.rm(temp_file)
      end
    end

    test "reads CSV data with custom delimiter" do
      csv_content = "name;email;age\nJohn;john@example.com;25"
      temp_file = write_temp_file("test.csv", csv_content)

      try do
        config = %{
          "file_path" => temp_file,
          "delimiter" => ";"
        }

        result = DataImporter.read_data(:csv, config)

        assert {:ok, data} = result
        assert hd(data)["name"] == "John"
        assert hd(data)["email"] == "john@example.com"
        assert hd(data)["age"] == "25"
      after
        File.rm(temp_file)
      end
    end

    test "handles missing file error" do
      config = %{"file_path" => "/nonexistent/file.json"}

      result = DataImporter.read_data(:json, config)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "not found")
    end

    test "handles invalid JSON" do
      json_content = ~s({"invalid": json})
      temp_file = write_temp_file("invalid.json", json_content)

      try do
        config = %{"file_path" => temp_file}
        result = DataImporter.read_data(:json, config)

        assert {:error, error_message} = result
        assert String.contains?(error_message, "JSON parsing failed")
      after
        File.rm(temp_file)
      end
    end

    test "returns error for unsupported format" do
      config = %{"file_path" => "test.xyz"}

      result = DataImporter.read_data(:xyz, config)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "Unsupported import format")
    end
  end

  describe "read_and_detect_format/1" do
    test "detects JSON format" do
      json_content = ~s([{"test": "data"}])
      temp_file = write_temp_file("test.json", json_content)

      try do
        result = DataImporter.read_and_detect_format(temp_file)

        assert {:ok, data} = result
        assert is_list(data)
        assert hd(data)["test"] == "data"
      after
        File.rm(temp_file)
      end
    end

    test "detects CSV format" do
      csv_content = "name,email\nJohn,john@example.com"
      temp_file = write_temp_file("test.csv", csv_content)

      try do
        result = DataImporter.read_and_detect_format(temp_file)

        assert {:ok, data} = result
        assert is_list(data)
        assert hd(data)["name"] == "John"
      after
        File.rm(temp_file)
      end
    end

    test "detects format by content for unknown extension" do
      json_content = ~s([{"format": "json"}])
      temp_file = write_temp_file("test.unknown", json_content)

      try do
        result = DataImporter.read_and_detect_format(temp_file)

        assert {:ok, data} = result
        assert hd(data)["format"] == "json"
      after
        File.rm(temp_file)
      end
    end

    test "handles non-existent file" do
      result = DataImporter.read_and_detect_format("/nonexistent/file")

      assert {:error, error_message} = result
      assert String.contains?(error_message, "not found")
    end
  end

  describe "infer_data_types/1" do
    test "infers data types from sample data" do
      data_sample = [
        %{"name" => "John", "age" => "25", "active" => "true", "score" => "95.5"},
        %{"name" => "Jane", "age" => "30", "active" => "false", "score" => "87.0"},
        %{"name" => "Bob", "age" => "", "active" => "yes", "score" => ""}
      ]

      result = DataImporter.infer_data_types(data_sample)

      assert result["name"] == "string"
      assert result["age"] == "integer"
      assert result["active"] == "boolean"
      assert result["score"] == "float"
    end

    test "handles empty sample" do
      result = DataImporter.infer_data_types([])

      assert result == %{}
    end

    test "handles mixed types with fallback to string" do
      data_sample = [
        %{"mixed" => "123"},
        %{"mixed" => "text"}
      ]

      result = DataImporter.infer_data_types(data_sample)

      assert result["mixed"] == "string"
    end
  end

  describe "validate_required_keys/2" do
    test "validates all required keys are present" do
      data = [
        %{"name" => "John", "email" => "john@example.com"},
        %{"name" => "Jane", "email" => "jane@example.com"}
      ]

      required_keys = ["name", "email"]

      result = DataImporter.validate_required_keys(data, required_keys)

      assert result == :ok
    end

    test "detects missing required keys" do
      data = [
        %{"name" => "John"},
        %{"name" => "Jane", "email" => "jane@example.com"}
      ]

      required_keys = ["name", "email"]

      result = DataImporter.validate_required_keys(data, required_keys)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "Missing required keys")
      assert String.contains?(error_message, "email")
    end

    test "handles empty data" do
      data = []
      required_keys = ["name"]

      result = DataImporter.validate_required_keys(data, required_keys)

      assert result == :ok
    end
  end

  describe "validate_data_size/2" do
    test "validates data within limit" do
      data = List.duplicate(%{"test" => "data"}, 100)
      max_records = 200

      result = DataImporter.validate_data_size(data, max_records)

      assert result == :ok
    end

    test "detects data exceeding limit" do
      data = List.duplicate(%{"test" => "data"}, 150)
      max_records = 100

      result = DataImporter.validate_data_size(data, max_records)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "exceeds limit")
      assert String.contains?(error_message, "150")
      assert String.contains?(error_message, "100")
    end
  end

  describe "get_sample_records/2" do
    test "returns sample of records" do
      data = Enum.map(1..20, fn i -> %{"id" => i} end)
      sample_size = 5

      result = DataImporter.get_sample_records(data, sample_size)

      assert is_list(result)
      assert length(result) <= sample_size
      assert hd(result)["id"] in 1..20
    end

    test "returns all records if data is smaller than sample size" do
      data = Enum.map(1..3, fn i -> %{"id" => i} end)
      sample_size = 10

      result = DataImporter.get_sample_records(data, sample_size)

      assert is_list(result)
      assert length(result) == 3
    end

    test "handles empty data" do
      result = DataImporter.get_sample_records([], 10)

      assert result == []
    end
  end

  describe "get_data_metadata/1" do
    test "returns metadata for data" do
      data = [
        %{"name" => "John", "age" => "25", "active" => "true"},
        %{"name" => "Jane", "age" => "30", "active" => "false"}
      ]

      result = DataImporter.get_data_metadata(data)

      assert result.record_count == 2
      assert "name" in result.fields
      assert "age" in result.fields
      assert "active" in result.fields
      assert result.sample_types["name"] == "string"
      assert result.sample_types["age"] == "integer"
      assert result.sample_types["active"] == "boolean"
      assert is_map(result.sample_record)
      assert result.sample_record["name"] == "John"
    end

    test "handles empty data" do
      result = DataImporter.get_data_metadata([])

      assert result.record_count == 0
      assert result.fields == []
      assert result.sample_types == %{}
      assert result.sample_record == nil
    end
  end

  # Helper function to write temporary files
  defp write_temp_file(filename, content) do
    temp_dir = System.tmp_dir!()
    temp_path = Path.join(temp_dir, filename)
    File.write!(temp_path, content)
    temp_path
  end
end
