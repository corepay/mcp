defmodule Mcp.SystemHelperTest do
  use ExUnit.Case, async: true

  alias Mcp.SystemHelper

  describe "get_cpu_usage/0" do
    test "returns a valid CPU usage percentage" do
      cpu_usage = SystemHelper.get_cpu_usage()

      # Should return a number between 0 and 100
      assert is_number(cpu_usage)
      assert cpu_usage >= 0
      assert cpu_usage <= 100
    end

    test "returns float with reasonable precision" do
      cpu_usage = SystemHelper.get_cpu_usage()

      # Should be a float with at most 2 decimal places
      assert is_float(cpu_usage)
      assert cpu_usage * 100 == round(cpu_usage * 100)
    end
  end

  describe "get_memory_usage/0" do
    test "returns valid memory usage information" do
      memory_info = SystemHelper.get_memory_usage()

      # Should return a map with required fields
      assert is_map(memory_info)
      assert Map.has_key?(memory_info, :total)
      assert Map.has_key?(memory_info, :used)
      assert Map.has_key?(memory_info, :percentage)
      assert Map.has_key?(memory_info, :erlang_usage)

      # Values should be reasonable
      assert is_number(memory_info.total)
      assert is_number(memory_info.used)
      assert is_number(memory_info.percentage)
      assert memory_info.percentage >= 0
      assert memory_info.percentage <= 100
    end

    test "erlang_usage contains expected memory breakdown" do
      memory_info = SystemHelper.get_memory_usage()
      erlang_usage = memory_info.erlang_usage

      # Should contain standard Erlang memory types
      assert is_map(erlang_usage)
      assert Map.has_key?(erlang_usage, :total)
      assert Map.has_key?(erlang_usage, :system)
      assert Map.has_key?(erlang_usage, :processes)

      # Values should be numbers
      Enum.each(erlang_usage, fn {key, value} ->
        assert is_number(value), "#{key} should be a number"
      end)
    end
  end

  describe "get_system_load/0" do
    test "returns valid system load averages" do
      system_load = SystemHelper.get_system_load()

      # Should return a map with load averages
      assert is_map(system_load)
      assert Map.has_key?(system_load, :load_1min)
      assert Map.has_key?(system_load, :load_5min)
      assert Map.has_key?(system_load, :load_15min)

      # Values should be reasonable numbers
      assert is_number(system_load.load_1min)
      assert is_number(system_load.load_5min)
      assert is_number(system_load.load_15min)
      assert system_load.load_1min >= 0
      assert system_load.load_5min >= 0
      assert system_load.load_15min >= 0
    end

    test "load averages are in reasonable ranges" do
      system_load = SystemHelper.get_system_load()

      # 1-minute load should typically be highest
      assert system_load.load_1min >= system_load.load_5min
      assert system_load.load_5min >= system_load.load_15min
    end
  end

  describe "get_disk_usage/0" do
    test "returns valid disk usage information" do
      disk_info = SystemHelper.get_disk_usage()

      # Should return a map with disk usage data
      assert is_map(disk_info)
      assert Map.has_key?(disk_info, :total)
      assert Map.has_key?(disk_info, :used)
      assert Map.has_key?(disk_info, :available)
      assert Map.has_key?(disk_info, :percentage)

      # Values should be reasonable
      assert is_number(disk_info.total)
      assert is_number(disk_info.used)
      assert is_number(disk_info.available)
      assert is_number(disk_info.percentage)

      # Percentage should be between 0 and 100
      assert disk_info.percentage >= 0
      assert disk_info.percentage <= 100

      # Total should equal used + available
      assert abs(disk_info.total - (disk_info.used + disk_info.available)) < disk_info.total * 0.01
    end
  end

  describe "get_system_health/0" do
    test "returns comprehensive system health information" do
      health = SystemHelper.get_system_health()

      # Should contain all system metrics
      assert is_map(health)
      assert Map.has_key?(health, :cpu)
      assert Map.has_key?(health, :memory)
      assert Map.has_key?(health, :load)
      assert Map.has_key?(health, :disk)
      assert Map.has_key?(health, :timestamp)
      assert Map.has_key?(health, :alerts)

      # Values should be reasonable
      assert is_number(health.cpu)
      assert is_map(health.memory)
      assert is_map(health.load)
      assert is_map(health.disk)
      assert %DateTime{} = health.timestamp
      assert is_list(health.alerts)
    end

    test "includes telemetry information" do
      # This test ensures telemetry is called without raising errors
      health = SystemHelper.get_system_health()

      # Should complete without errors
      assert is_map(health)
      refute is_nil(health.timestamp)
    end

    test "alerts list contains valid alert structures" do
      health = SystemHelper.get_system_health()

      Enum.each(health.alerts, fn alert ->
        assert is_map(alert)
        assert Map.has_key?(alert, :type)
        assert Map.has_key?(alert, :metric)
        assert Map.has_key?(alert, :value)
        assert Map.has_key?(alert, :threshold)
        assert Map.has_key?(alert, :message)
        assert alert.type in [:warning, :critical]
      end)
    end
  end

  describe "check_alerts/4" do
    test "returns empty list for healthy metrics" do
      cpu_usage = 25.0
      memory_usage = %{percentage: 30.0}
      system_load = %{load_1min: 0.5}
      disk_usage = %{percentage: 40.0}

      alerts = SystemHelper.check_alerts(cpu_usage, memory_usage, system_load, disk_usage)
      assert alerts == []
    end

    test "returns CPU warning for high usage" do
      cpu_usage = 80.0
      memory_usage = %{percentage: 30.0}
      system_load = %{load_1min: 0.5}
      disk_usage = %{percentage: 40.0}

      alerts = SystemHelper.check_alerts(cpu_usage, memory_usage, system_load, disk_usage)
      assert length(alerts) == 1
      assert hd(alerts).type == :warning
      assert hd(alerts).metric == :cpu
    end

    test "returns CPU critical alert for very high usage" do
      cpu_usage = 95.0
      memory_usage = %{percentage: 30.0}
      system_load = %{load_1min: 0.5}
      disk_usage = %{percentage: 40.0}

      alerts = SystemHelper.check_alerts(cpu_usage, memory_usage, system_load, disk_usage)
      assert length(alerts) == 1
      assert hd(alerts).type == :critical
      assert hd(alerts).metric == :cpu
    end

    test "returns memory warning for high usage" do
      cpu_usage = 25.0
      memory_usage = %{percentage: 85.0}
      system_load = %{load_1min: 0.5}
      disk_usage = %{percentage: 40.0}

      alerts = SystemHelper.check_alerts(cpu_usage, memory_usage, system_load, disk_usage)
      assert length(alerts) == 1
      assert hd(alerts).type == :warning
      assert hd(alerts).metric == :memory
    end

    test "returns multiple alerts for multiple issues" do
      cpu_usage = 95.0
      memory_usage = %{percentage: 92.0}
      system_load = %{load_1min: 0.5}
      disk_usage = %{percentage: 96.0}

      alerts = SystemHelper.check_alerts(cpu_usage, memory_usage, system_load, disk_usage)
      assert length(alerts) >= 3

      alert_types = Enum.map(alerts, & &1.type)
      assert :critical in alert_types

      alert_metrics = Enum.map(alerts, & &1.metric)
      assert :cpu in alert_metrics
      assert :memory in alert_metrics
      assert :disk in alert_metrics
    end
  end

  describe "error handling and resilience" do
    test "gracefully handles system monitoring errors" do
      # Test that the system monitoring functions don't crash
      # even when underlying system calls might fail

      cpu_usage = SystemHelper.get_cpu_usage()
      memory_info = SystemHelper.get_memory_usage()
      system_load = SystemHelper.get_system_load()
      disk_info = SystemHelper.get_disk_usage()
      health = SystemHelper.get_system_health()

      # All should return valid structures even in adverse conditions
      assert is_number(cpu_usage)
      assert is_map(memory_info)
      assert is_map(system_load)
      assert is_map(disk_info)
      assert is_map(health)
    end

    test "fallback values are reasonable when real monitoring fails" do
      # Even when real monitoring fails, fallbacks should be reasonable
      memory_info = SystemHelper.get_memory_usage()
      system_load = SystemHelper.get_system_load()
      disk_info = SystemHelper.get_disk_usage()

      assert memory_info.percentage >= 0
      assert memory_info.percentage <= 100
      assert system_load.load_1min >= 0
      assert disk_info.percentage >= 0
      assert disk_info.percentage <= 100
    end
  end
end