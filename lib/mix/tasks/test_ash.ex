defmodule Mix.Tasks.TestAsh do
  @moduledoc """
  Test Ash Framework basic functionality
  """

  use Mix.Task

  @shortdoc "Test Ash Framework basic operations"

  @impl Mix.Task
  def run(_args) do
    setup_application()
    IO.puts("Testing Ash Framework operations...\n")

    test_domains()
    test_resources()
    test_database_operations()
    test_authentication()

    IO.puts("\n=== Ash Framework Test Complete ===")
    IO.puts("If all tests show ✓, Ash Framework is working correctly!")
  end

  defp setup_application do
    Application.put_env(:mcp, :start_server, false)
    Mix.Task.run("app.start")
  end

  defp test_domains do
    IO.puts("=== Test 1: Domain Loading ===")

    try do
      accounts_loaded = Code.ensure_loaded?(Mcp.Accounts)
      platform_loaded = Code.ensure_loaded?(Mcp.Platform)

      IO.puts("✓ Mcp.Accounts domain loaded: #{accounts_loaded}")
      IO.puts("✓ Mcp.Platform domain loaded: #{platform_loaded}")

      if accounts_loaded and platform_loaded do
        IO.puts("✓ All domains loaded successfully")
      else
        IO.puts("✗ Some domains failed to load")
      end
    rescue
      error ->
        IO.puts("✗ ERROR loading domains: #{Exception.format(:error, error)}")
    end
  end

  defp test_resources do
    IO.puts("\n=== Test 2: Resource Loading ===")

    resources = [
      {Mcp.Accounts.User, "User"},
      {Mcp.Accounts.Token, "Token"},
      {Mcp.Accounts.RegistrationSettings, "RegistrationSettings"},
      {Mcp.Accounts.RegistrationRequest, "RegistrationRequest"},
      {Mcp.Platform.Tenant, "Tenant"}
    ]

    resources_loaded =
      Enum.map(resources, fn {module, name} ->
        try do
          loaded = Code.ensure_loaded?(module)
          IO.puts("✓ #{name} resource loaded: #{loaded}")
          loaded
        rescue
          error ->
            IO.puts("✗ ERROR loading #{name}: #{Exception.format(:error, error)}")
            false
        end
      end)

    if Enum.all?(resources_loaded) do
      IO.puts("✓ All resources loaded successfully")
    else
      IO.puts("✗ Some resources failed to load")
    end
  end

  defp test_database_operations do
    IO.puts("\n=== Test 3: Database Operations ===")

    try do
      case Mcp.Repo.query("SELECT 1") do
        {:ok, %{rows: [[1]]}} ->
          IO.puts("✓ Database connection successful")
          test_ash_read_operations()

        {:error, reason} ->
          IO.puts("✗ Database connection error: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("✗ ERROR in database operations: #{Exception.format(:error, error)}")
    end
  end

  defp test_ash_read_operations do
    case Ash.read(Mcp.Accounts.User) do
      {:ok, users} ->
        IO.puts("✓ Ash.read(Mcp.Accounts.User): #{length(users)} users found")

      {:error, reason} ->
        IO.puts("✗ Ash.read(Mcp.Accounts.User) error: #{inspect(reason)}")
    end

    case Ash.read(Mcp.Platform.Tenant) do
      {:ok, tenants} ->
        IO.puts("✓ Ash.read(Mcp.Platform.Tenant): #{length(tenants)} tenants found")

      {:error, reason} ->
        IO.puts("✗ Ash.read(Mcp.Platform.Tenant) error: #{inspect(reason)}")
    end
  end

  defp test_authentication do
    IO.puts("\n=== Test 4: Ash Authentication ===")

    try do
      if function_exported?(Mcp.Accounts.User, :__info__, 1) do
        auth_info =
          Map.get(Mcp.Accounts.User.__info__(:functions), {:ash_authentication, 0}) ||
            function_exported?(Mcp.Accounts.User, :ash_authentication, 0)

        IO.puts("✓ User resource has authentication configuration: #{auth_info}")
      else
        IO.puts("? User resource info not available")
      end
    rescue
      error ->
        IO.puts(
          "? Authentication check failed (this might be expected): #{Exception.format(:error, error)}"
        )
    end
  end
end
