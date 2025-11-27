# priv/scripts/test_chat.exs
require Ash.Query

# Load application configuration without starting
Application.load(:mcp)

# Set environment variables to override Repo init/2 defaults
System.put_env("POSTGRES_PORT", "5432")
System.put_env("POSTGRES_HOST", "localhost")

# Ensure dependencies are started
{:ok, _} = Application.ensure_all_started(:telemetry)
{:ok, _} = Application.ensure_all_started(:ash)
{:ok, _} = Application.ensure_all_started(:db_connection)
{:ok, _} = Application.ensure_all_started(:postgrex)

# Start the main application
{:ok, _} = Application.ensure_all_started(:mcp)

IO.puts("\n--- Starting Chat Verification ---\n")

# 1. Get or Create User
IO.puts("1. Getting or creating user...")
user = Mcp.Accounts.User |> Ash.Query.limit(1) |> Ash.read!() |> List.first()

user =
  if user do
    IO.puts("   Found existing user: #{user.email}")
    user
  else
    email = "test_chat_#{System.unique_integer([:positive])}@example.com"
    IO.puts("   Creating new user: #{email}")
    Mcp.Accounts.User.register!(email, "Password123!", "Password123!")
  end

# 2. Create Conversation
IO.puts("\n2. Creating conversation...")
conv = Mcp.Chat.Conversation.create!(%{title: "Test Chat via Script"}, actor: user)
IO.puts("   Conversation created: #{conv.id}")

# 3. Send Message
IO.puts("\n3. Sending message...")
msg = Mcp.Chat.Message.create!(%{text: "Hello! Can you hear me?", conversation_id: conv.id}, actor: user)
IO.puts("   Message sent: \"#{msg.text}\"")

IO.puts("\n--- Verification Complete ---")
IO.puts("The AI response will be processed in the background.")
IO.puts("Check your server logs for Ollama activity.")
