defmodule Mcp.SystemHelperTest do
  use ExUnit.Case, async: true
  alias Mcp.SystemHelper

  describe "get_cpu_usage/0" do
    test "returns a float between 0 and 100" do
      cpu_usage = SystemHelper.get_cpu_usage()

      assert is_float(cpu_usage)
      assert cpu_usage >= 0.0
      assert cpu_usage <= 100.0
    end

    test "returns value with 2 decimal places" do
      cpu_usage = SystemHelper.get_cpu_usage()

      # Check that it has at most 2 decimal places
      rounded = Float.round(cpu_usage, 2)
      assert cpu_usage == rounded
    end
  end

  describe "get_memory_usage/0" do
    test "returns a map with memory information" do
      memory_usage = SystemHelper.get_memory_usage()

      assert is_map(memory_usage)
      assert Map.has_key?(memory_usage, :total)
      assert Map.has_key?(memory_usage, :used)
      assert Map.has_key?(memory_usage, :percentage)
    end

    test "memory values are reasonable" do
      memory_usage = SystemHelper.get_memory_usage()

      assert is_integer(memory_usage.total)
      assert is_integer(memory_usage.used)
      assert is_float(memory_usage.percentage)

      assert memory_usage.total > 0
      assert memory_usage.used > 0
      assert memory_usage.used <= memory_usage.total
      assert memory_usage.percentage >= 0.0
      assert memory_usage.percentage <= 100.0
    end

    test "percentage matches used/total ratio" do
      memory_usage = SystemHelper.get_memory_usage()

      expected_percentage = (memory_usage.used / memory_usage.total) * 100
      assert Float.round(memory_usage.percentage, 1) == Float.round(expected_percentage, 1)
    end
  end

  describe "get_system_load/0" do
    test "returns a map with load averages" do
      system_load = SystemHelper.get_system_load()

      assert is_map(system_load)
      assert Map.has_key?(system_load, :load_1min)
      assert Map.has_key?(system_load, :load_5min)
      assert Map.has_key?(system_load, :load_15min)
    end

    test "load values are reasonable floats" do
      system_load = SystemHelper.get_system_load()

      assert is_float(system_load.load_1min)
      assert is_float(system_load.load_5min)
      assert is_float(system_load.load_15min)

      # Load averages should be non-negative
      assert system_load.load_1min >= 0.0
      assert system_load.load_5min >= 0.0
      assert system_load.load_15min >= 0.0

      # Should have reasonable decimal precision
      assert Float.round(system_load.load_1min, 2) == system_load.load_1min
      assert Float.round(system_load.load_5min, 2) == system_load.load_5min
      assert Float.round(system_load.load_15min, 2) == system_load.load_15min
    end
  end

  describe "get_disk_usage/0" do
    test "returns a map with disk information" do
      disk_usage = SystemHelper.get_disk_usage()

      assert is_map(disk_usage)
      assert Map.has_key?(disk_usage, :total)
      assert Map.has_key?(disk_usage, :used)
      assert Map.has_key?(disk_usage, :percentage)
    end

    test "disk values are reasonable" do
      disk_usage = SystemHelper.get_disk_usage()

      assert is_integer(disk_usage.total)
      assert is_integer(disk_usage.used)
      assert is_float(disk_usage.percentage)

      assert disk_usage.total > 0
      assert disk_usage.used > 0
      assert disk_usage.used <= disk_usage.total
      assert disk_usage.percentage >= 0.0
      assert disk_usage.percentage <= 100.0
    end

    test "disk percentage matches used/total ratio" do
      disk_usage = SystemHelper.get_disk_usage()

      expected_percentage = (disk_usage.used / disk_usage.total) * 100
      assert Float.round(disk_usage.percentage, 1) == Float.round(expected_percentage, 1)
    end
  end

  describe "overall system health" do
    test "all monitoring functions return data consistently" do
      # Call all functions multiple times to ensure consistency
      cpu_1 = SystemHelper.get_cpu_usage()
      memory_1 = SystemHelper.get_memory_usage()
      load_1 = SystemHelper.get_system_load()
      disk_1 = SystemHelper.get_disk_usage()

      cpu_2 = SystemHelper.get_cpu_usage()
      memory_2 = SystemHelper.get_memory_usage()
      load_2 = SystemHelper.get_system_load()
      disk_2 = SystemHelper.get_disk_usage()

      # All should return valid data
      assert is_float(cpu_1) and is_float(cpu_2)
      assert is_map(memory_1) and is_map(memory_2)
      assert is_map(load_1) and is_map(load_2)
      assert is_map(disk_1) and is_map(disk_2)

      # Memory and disk totals should be consistent (they shouldn't change between calls)
      assert memory_1.total == memory_2.total
      assert disk_1.total == disk_2.total
    end
  end
end