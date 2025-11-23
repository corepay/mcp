defmodule Mcp.Storage.CDNManager do
  @moduledoc """
  CDN management service.
  Handles cache invalidation, warming, and analytics.
  """

  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Storage CDNManager")
    {:ok, %{}}
  end

  def invalidate_file_urls(urls) do
    GenServer.call(__MODULE__, {:invalidate_urls, urls})
  end

  def warm_file_urls(urls) do
    GenServer.call(__MODULE__, {:warm_urls, urls})
  end

  def get_cdn_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @impl true
  def handle_call({:invalidate_urls, urls}, _from, state) do
    # McpStorage.CDNClient.purge_cache always returns {:ok, _}, so no error handling needed
    Mcp.Storage.CDNClient.purge_cache(urls)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:warm_urls, urls}, _from, state) do
    # McpStorage.CDNClient.warm_cache always returns {:ok, _}, so no error handling needed
    Mcp.Storage.CDNClient.warm_cache(urls)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    # McpStorage.CDNClient.get_cache_stats always returns {:ok, _}, so no error handling needed
    stats = Mcp.Storage.CDNClient.get_cache_stats()
    {:reply, {:ok, stats}, state}
  end
end
