# Script to verify ComplyCube integration
# Run with: mix run priv/repo/scripts/verify_comply_cube.exs

alias Mcp.Underwriting.Adapters.ComplyCube

IO.puts("Verifying ComplyCube Integration...")

# check if api key is loaded
config = Application.get_env(:mcp, :comply_cube, [])
if is_nil(config[:api_key]) do
  IO.puts("Error: COMPLY_CUBE_API_KEY not found in configuration.")
  System.halt(1)
else
  IO.puts("API Key found: #{String.slice(config[:api_key], 0, 10)}...")
end

# Test Data
applicant_data = %{
  "email" => "john.doe.#{System.unique_integer()}@example.com",
  "first_name" => "John",
  "last_name" => "Doe",
  "dob" => "1990-01-01"
}

IO.puts("\nAttempting Identity Verification...")
case ComplyCube.verify_identity(applicant_data, %{}) do
  {:ok, result} ->
    IO.puts("Success!")
    IO.inspect(result, label: "Result")
  
  {:error, reason} ->
    IO.puts("Failed!")
    IO.inspect(reason, label: "Reason")
end
