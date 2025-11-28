defmodule Mcp.Underwriting.Adapters.IdenfyTest do
  use ExUnit.Case, async: true
  alias Mcp.Underwriting.Adapters.Idenfy

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "verify_identity/2 creates a session", %{bypass: bypass} do
    Application.put_env(:mcp, :idenfy, 
      api_key: "test_key", 
      api_secret: "test_secret",
      base_url: "http://localhost:#{bypass.port}"
    )

    Bypass.expect(bypass, "POST", "/api/v2/token", fn conn ->
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      assert body =~ "clientId"
      
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(201, Jason.encode!(%{authToken: "token_123"}))
    end)

    applicant_data = %{
      "email" => "test@example.com",
      "first_name" => "Test",
      "last_name" => "User"
    }

    assert {:ok, result} = Idenfy.verify_identity(applicant_data, %{})
    assert result.session_id == "token_123"
    assert result.provider == "idenfy"
  end

  test "screen_business/2 creates KYB token", %{bypass: bypass} do
    Application.put_env(:mcp, :idenfy, 
      api_key: "test_key", 
      api_secret: "test_secret",
      base_url: "http://localhost:#{bypass.port}"
    )

    Bypass.expect(bypass, "POST", "/kyb/tokens", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(201, Jason.encode!(%{tokenString: "kyb_token_456"}))
    end)

    business_data = %{"email" => "corp@example.com"}
    assert {:ok, result} = Idenfy.screen_business(business_data, %{})
    assert result.check_id == "kyb_token_456"
  end
end
