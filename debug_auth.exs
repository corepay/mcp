
# Load environment variables first
IO.puts("Loading environment variables...")
{:ok, _} = Application.ensure_all_started(:dotenvy)
Dotenvy.source!([".env", ".env.example"])

alias Mcp.Accounts.User
alias Mcp.Accounts.Auth
alias Mcp.Platform.Tenant
alias Mcp.Seeder

IO.puts("Starting applications...")
{:ok, _} = Application.ensure_all_started(:telemetry)
{:ok, _} = Application.ensure_all_started(:ash)
{:ok, _} = Application.ensure_all_started(:mcp)

IO.puts("Checking Mcp.Repo...")
case Process.whereis(Mcp.Repo) do
  nil -> IO.puts("Mcp.Repo is NOT running! (This is unexpected after ensure_all_started)")
  pid -> IO.puts("Mcp.Repo is running at #{inspect(pid)}")
end

email = "admin@acme.local"
password = "Password123!"
subdomain = "acme"

IO.puts("\n--- Debugging Tenant 'acme' ---")
case Tenant.by_subdomain(subdomain) do
  {:ok, tenant} ->
    IO.puts("Tenant found: #{tenant.name} (#{tenant.id})")
    
    # Check if user exists
    case User.by_email(email) do
      {:ok, user} ->
        IO.puts("\nUser found: #{user.email} (#{user.id})")
        
        # Check if user is in tenant settings
        users = Map.get(tenant.settings || %{}, "users", [])
        is_member = Enum.any?(users, fn u -> u["user_id"] == user.id end)
        IO.puts("User in tenant settings? #{is_member}")
        
        if !is_member do
           IO.puts("User NOT linked to tenant. Attempting to link manually...")
           
           new_user_entry = %{
            "user_id" => user.id,
            "email" => user.email,
            "role" => "owner",
            "joined_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }
          
          updated_users = [new_user_entry | users]
          updated_settings = Map.put(tenant.settings || %{}, "users", updated_users)
          
          Tenant.update!(tenant, %{settings: updated_settings})
          IO.puts("Tenant settings updated.")
        end
        
        # Test Auth
        IO.puts("\nTesting Auth...")
        case Auth.authenticate(email, password) do
          {:ok, _} -> IO.puts("✅ Auth SUCCESS")
          {:error, r} -> IO.puts("❌ Auth FAILED: #{inspect(r)}")
        end
        
      {:error, _} ->
        IO.puts("User not found. Running Seeder...")
        Seeder.run()
        IO.puts("Seeder finished. Checking auth...")
        case Auth.authenticate(email, password) do
             {:ok, _} -> IO.puts("✅ Auth SUCCESS after seed")
             {:error, r} -> IO.puts("❌ Auth FAILED after seed: #{inspect(r)}")
        end
    end

  {:error, error} ->
    IO.puts("Tenant lookup failed:")
    IO.inspect(error)
    
    IO.puts("Attempting to run Seeder...")
    try do
      Seeder.run()
      IO.puts("Seeder completed.")
       # Test Auth
        IO.puts("\nTesting Auth...")
        case Auth.authenticate(email, password) do
          {:ok, _} -> IO.puts("✅ Auth SUCCESS")
          {:error, r} -> IO.puts("❌ Auth FAILED: #{inspect(r)}")
        end
    rescue
      e -> 
        IO.puts("Seeder failed!")
        IO.inspect(e)
    end
end
