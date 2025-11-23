defmodule Mcp.SystemHelper do
  @moduledoc """
  System monitoring and metrics helper.
  """

  @doc """
  Gets CPU usage percentage.
  """
  def get_cpu_usage() do
    # Stub implementation - returns a mock CPU usage value
    Float.round(:rand.uniform() * 100, 2)
  end

  @doc """
  Gets memory usage.
  """
  def get_memory_usage() do
    # Stub implementation - returns mock memory usage
    total_memory = 8_589_934_592  # 8GB in bytes
    used_memory = trunc(total_memory * 0.6)  # 60% used
    %{total: total_memory, used: used_memory, percentage: 60.0}
  end

  @doc """
  Gets system load.
  """
  def get_system_load() do
    # Stub implementation
    %{
      load_1min: Float.round(:rand.uniform() * 2, 2),
      load_5min: Float.round(:rand.uniform() * 2, 2),
      load_15min: Float.round(:rand.uniform() * 2, 2)
    }
  end

  @doc """
  Gets disk usage.
  """
  def get_disk_usage() do
    # Stub implementation
    %{
      total: 100_000_000_000,  # 100GB
      used: 60_000_000_000,    # 60GB
      percentage: 60.0
    }
  end
end