defmodule Mcp.Underwriting.Adapters.ComplyCubeTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Adapters.ComplyCube

  setup do
    bypass = Bypass.open()
    
    # Configure the adapter to use the bypass URL
    Application.put_env(:mcp, :comply_cube_base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:mcp, :comply_cube, 
      base_url: "http://localhost:#{bypass.port}",
      api_key: "test_api_key"
    )

    {:ok, bypass: bypass}
  end

  describe "verify_identity/2" do
    test "successfully creates a client and check", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/clients", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "person"
        assert body =~ "John"
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "client_123"}))
      end)

      Bypass.expect(bypass, "POST", "/checks", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "client_123"
        assert body =~ "standard_screening_check"
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "check_456"}))
      end)

      applicant_data = %{
        "email" => "john@example.com",
        "first_name" => "John",
        "last_name" => "Doe",
        "dob" => "1990-01-01"
      }

      assert {:ok, result} = ComplyCube.verify_identity(applicant_data, %{})
      assert result.check_id == "check_456"
      assert result.client_id == "client_123"
      assert result.provider == "comply_cube"
    end

    test "handles API errors", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/clients", fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(%{error: "Invalid data"}))
      end)

      applicant_data = %{
        "email" => "bad@example.com"
      }

      assert {:error, _reason} = ComplyCube.verify_identity(applicant_data, %{})
    end
  end

  describe "screen_business/2" do
    test "successfully creates a corporate client and check", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/clients", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "corporate"
        assert body =~ "Acme Corp"
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "client_corp_123"}))
      end)

      Bypass.expect(bypass, "POST", "/checks", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "client_corp_123"
        assert body =~ "company_check"
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "check_corp_456"}))
      end)

      business_data = %{
        "email" => "info@acme.com",
        "business_name" => "Acme Corp",
        "registration_number" => "12345678"
      }

      assert {:ok, result} = ComplyCube.screen_business(business_data, %{})
      assert result.check_id == "check_corp_456"
      assert result.client_id == "client_corp_123"
    end
  end

  describe "document_check/3" do
    test "successfully uploads document and creates check", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/documents", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "clientId"
        assert body =~ "client_123"
        assert body =~ "passport"
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "doc_789"}))
      end)

      Bypass.expect(bypass, "POST", "/checks", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "client_123"
        assert body =~ "document_check"
        assert body =~ "doc_789"
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "check_doc_101"}))
      end)

      document_image = "fake_image_content"
      context = %{client_id: "client_123"}

      assert {:ok, result} = ComplyCube.document_check(document_image, :identity, context)
      assert result.check_id == "check_doc_101"
      assert result.document_id == "doc_789"
    end
  end
end
