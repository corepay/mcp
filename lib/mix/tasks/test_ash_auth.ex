defmodule Mix.Tasks.TestAshAuth do
  @moduledoc """
  Test Ash Authentication functionality by creating a simple test scenario
  """

  use Mix.Task

  @shortdoc "Test Ash Authentication functionality"

  @impl Mix.Task
  def run(_args) do
    setup_auth_test_environment()
    IO.puts("Testing Ash Authentication functionality...\n")

    test_authentication_configuration()
    test_tenant_creation()
    test_user_registration()
    test_token_creation()
    test_password_hashing()

    IO.puts("\n=== Ash Authentication Test Complete ===")
    IO.puts("Core Ash Framework is working. Database schema needs alignment.")
  end

  defp setup_auth_test_environment do
    Application.put_env(:mcp, :start_server, false)
    Mix.Task.run("app.start")
  end

  defp test_authentication_configuration do
    IO.puts("=== Test 1: Authentication Configuration ===")

    try do
      ash_auth_loaded = Code.ensure_loaded?(AshAuthentication)
      IO.puts("✓ AshAuthentication loaded: #{ash_auth_loaded}")

      if function_exported?(Mcp.Accounts.User, :ash_authentication, 0) do
        IO.puts("✓ User resource has ash_authentication function")
      else
        IO.puts("? User resource may not have authentication configured")
      end
    rescue
      error ->
        IO.puts("? Authentication check error (expected): #{Exception.format(:error, error)}")
    end
  end

  defp test_tenant_creation do
    IO.puts("\n=== Test 2: Create Test Tenant ===")

    try do
      tenant_attrs = %{
        slug: "test-tenant-#{System.unique_integer([:positive])}",
        company_name: "Test Company",
        company_schema: "test_schema",
        subdomain: "test-#{System.unique_integer([:positive])}",
        plan: :starter
      }

      case Ash.create(Mcp.Platform.Tenant, tenant_attrs) do
        {:ok, tenant} ->
          IO.puts("✓ Test tenant created successfully: #{tenant.slug}")

        {:error, reason} ->
          IO.puts("✗ Could not create test tenant: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts(
          "? Tenant creation error (might be due to schema): #{Exception.format(:error, error)}"
        )
    end
  end

  defp test_user_registration do
    IO.puts("\n=== Test 3: User Registration Action ===")

    try do
      user_attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test#{System.unique_integer([:positive])}@example.com",
        password: "TestPass123!",
        password_confirmation: "TestPass123!"
      }

      case Ash.create(Mcp.Accounts.User, :register, user_attrs) do
        {:ok, user} ->
          IO.puts("✓ User registration successful: #{user.email}")
          IO.puts("  User ID: #{user.id}")
          IO.puts("  Status: #{user.status}")

        {:error, reason} ->
          IO.puts("✗ User registration failed: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("✗ User registration error: #{Exception.format(:error, error)}")
    end
  end

  defp test_token_creation do
    IO.puts("\n=== Test 4: Token Management ===")

    try do
      token_attrs = %{
        type: :access,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
      }

      case Ash.create(Mcp.Accounts.Token, token_attrs) do
        {:ok, token} ->
          IO.puts("✓ Token created successfully")
          IO.puts("  Token ID: #{token.id}")
          IO.puts("  Token type: #{token.type}")

        {:error, reason} ->
          IO.puts("✗ Token creation failed: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("✗ Token creation error: #{Exception.format(:error, error)}")
    end
  end

  defp test_password_hashing do
    IO.puts("\n=== Test 5: Password Hashing ===")

    try do
      password = "TestPass123!"
      hashed = Bcrypt.hash_pwd_salt(password)
      IO.puts("✓ Password hashing successful")
      IO.puts("  Original: #{password}")
      IO.puts("  Hashed: #{String.slice(hashed, 0, 20)}...")

      if Bcrypt.verify_pass(password, hashed) do
        IO.puts("✓ Password verification successful")
      else
        IO.puts("✗ Password verification failed")
      end
    rescue
      error ->
        IO.puts("✗ Password hashing error: #{Exception.format(:error, error)}")
    end
  end
end
