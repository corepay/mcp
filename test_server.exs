#!/usr/bin/env elixir

# Load the application
Mix.install([])

# Source environment variables
System.put_env("POSTGRES_PORT", "41789")
System.put_env("REDIS_PORT", "48234")
System.put_env("MINIO_PORT", "49723")
System.put_env("VAULT_PORT", "44567")

# Start the application
Application.ensure_all_started(:mcp)

# Check if we can bind to port
IO.puts("Application started successfully")
IO.puts("Checking if Phoenix server is running...")

:timer.sleep(3000)

# Test HTTP connection
case :httpc.request('http://localhost:4000') do
  {:ok, {{'HTTP/1.1', status, _}, _headers, _body}} ->
    IO.puts("Phoenix server is responding with status: #{status}")
  {:error, reason} ->
    IO.puts("Phoenix server not responding: #{inspect(reason)}")
end

IO.puts("Test completed")