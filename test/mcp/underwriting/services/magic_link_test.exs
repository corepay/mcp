defmodule Mcp.Underwriting.Services.MagicLinkTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Services.MagicLink

  describe "generate/2" do
    test "creates a valid token for an application" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      {:ok, token} = MagicLink.generate(app_id, email)

      assert is_binary(token)
      assert byte_size(token) > 20
    end
  end

  describe "verify/1" do
    test "returns application id for valid token" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      {:ok, token} = MagicLink.generate(app_id, email)
      {:ok, result} = MagicLink.verify(token)

      assert result.application_id == app_id
      assert result.email == email
    end

    test "returns error for expired token" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      # Generate token with 0 TTL
      {:ok, token} = MagicLink.generate(app_id, email, ttl: 0)

      # Wait a moment
      Process.sleep(100)

      assert {:error, :expired} = MagicLink.verify(token)
    end

    test "returns error for invalid token" do
      assert {:error, :invalid} = MagicLink.verify("garbage")
    end
  end

  describe "resume_url/2" do
    test "generates a full URL with token" do
      app_id = Ecto.UUID.generate()
      email = "test@example.com"

      url = MagicLink.resume_url(app_id, email)

      assert url =~ "/online-application/resume/"
      assert String.length(url) > 50
    end
  end
end
