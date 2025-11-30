defmodule McpWeb.GdprControllerTest do
  use McpWeb.ConnCase, async: true

  import Mox

  alias Mcp.Accounts.User

  setup %{conn: conn} do
    {:ok, user} = create_test_user()

    {:ok, session_data} = Mcp.Accounts.Auth.create_user_session(user, "127.0.0.1")

    key_value = "test_key_#{Ecto.UUID.generate()}"

    {:ok, _api_key} =
      Mcp.Accounts.ApiKey.create(%{
        name: "Test Key",
        key: key_value,
        tenant_id: user.tenant_id
      })

    auth_conn =
      conn
      |> init_test_session(%{})
      |> put_req_header("x-api-key", key_value)
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)
      |> assign(:current_user, user)

    %{conn: auth_conn, user: user, api_key: key_value}
  end

  describe "GET /gdpr/data-export" do
    test "renders export request page", %{conn: conn} do
      conn = get(conn, ~p"/gdpr/data-export")

      assert html_response(conn, 200) =~ "Data Export"
    end
  end

  describe "POST /gdpr/data-export" do
    test "creates data export request", %{conn: conn} do
      expect(ComplianceMock, :request_user_data_export, fn _user_id, "json", _actor_id ->
        {:ok,
         %{
           id: Ecto.UUID.generate(),
           status: "requested",
           requested_format: "json",
           requested_at: DateTime.utc_now(),
           estimated_completion: DateTime.add(DateTime.utc_now(), 3600, :second)
         }}
      end)

      conn = post(conn, ~p"/api/gdpr/export", %{"format" => "json"})

      assert %{"message" => "Data export request accepted"} = json_response(conn, 202)
      assert %{"status" => "requested"} = json_response(conn, 202)
    end

    test "returns error for invalid format", %{conn: conn} do
      expect(ComplianceMock, :request_user_data_export, fn _user_id, "xml", _actor_id ->
        {:error, :unsupported_format}
      end)

      conn = post(conn, ~p"/gdpr/data-export", %{"format" => "xml"})

      assert %{"error" => "Unsupported export format" <> _} = json_response(conn, 400)
    end
  end

  describe "GET /gdpr/export/:token" do
    test "downloads export file", %{conn: conn, user: user} do
      export =
        Mcp.Gdpr.Resources.DataExport
        |> Ash.Changeset.for_create(:create_export, %{
          user_id: user.id,
          format: "json",
          purpose: "user_request"
        })
        |> Ash.create!()
        |> Ash.Changeset.for_update(:mark_completed, %{
          file_path: "/tmp/export.json",
          file_size: 1024,
          download_url: "http://example.com/download"
        })
        |> Ash.update!()

      conn = get(conn, ~p"/gdpr/export/#{export.id}")

      assert json_response(conn, 200)["download_url"] == "http://example.com/download"
    end

    test "returns 404 for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/gdpr/export/#{Ecto.UUID.generate()}")

      assert %{"error" => "Export not found"} = json_response(conn, 404)
    end
  end

  describe "POST /gdpr/request-deletion" do
    test "creates deletion request", %{conn: conn, user: user} do
      user_id = user.id

      expect(ComplianceMock, :request_user_deletion, fn ^user_id,
                                                        "test_reason",
                                                        ^user_id,
                                                        _opts ->
        {:ok, %Mcp.Accounts.User{id: user_id, status: :deleted}}
      end)

      conn = post(conn, ~p"/gdpr/request-deletion", %{"reason" => "test_reason"})

      assert %{
               "status" => "deleted",
               "message" => "Account deletion request processed successfully"
             } = json_response(conn, 200)
    end

    test "returns error for missing reason", %{conn: conn} do
      conn = post(conn, ~p"/gdpr/request-deletion", %{})

      assert response(conn, 400)
    end
  end

  describe "POST /gdpr/cancel-deletion" do
    test "cancels pending deletion", %{conn: conn, user: user} do
      user_id = user.id

      expect(ComplianceMock, :cancel_user_deletion, fn ^user_id, ^user_id ->
        {:ok, %Mcp.Accounts.User{id: user_id, status: :active}}
      end)

      conn = post(conn, ~p"/gdpr/cancel-deletion", %{"reason" => "user_canceled"})
      assert json_response(conn, 200)["status"] == "active"
    end
  end

  describe "GET /gdpr/consent" do
    test "gets user consent status", %{conn: conn, user: user} do
      user_id = user.id

      expect(ComplianceMock, :get_user_consents, fn ^user_id ->
        {:ok,
         [
           %{
             id: Ecto.UUID.generate(),
             purpose: "marketing",
             status: "granted",
             granted_at: DateTime.utc_now(),
             withdrawn_at: nil,
             legal_basis: "consent",
             ip_address: "127.0.0.1"
           }
         ]}
      end)

      conn = get(conn, ~p"/gdpr/consent")
      assert length(json_response(conn, 200)["consents"]) == 1
    end
  end

  describe "POST /gdpr/consent" do
    test "updates consent preferences", %{conn: conn, user: user} do
      user_id = user.id

      expect(ComplianceMock, :update_user_consent, fn ^user_id,
                                                      "marketing",
                                                      "granted",
                                                      ^user_id ->
        {:ok, %{id: Ecto.UUID.generate(), purpose: "marketing", status: "granted"}}
      end)

      consent_params = %{"consents" => %{"marketing" => "granted"}}

      conn = post(conn, ~p"/gdpr/consent", consent_params)

      assert %{
               "message" => "Consent preferences updated successfully",
               "updated_consents" => [_]
             } = json_response(conn, 200)
    end
  end

  describe "GET /gdpr/audit-trail" do
    test "gets user audit trail", %{conn: conn, user: user} do
      user_id = user.id

      expect(ComplianceMock, :get_user_audit_trail, fn ^user_id, _opts ->
        {:ok,
         [
           %{
             id: Ecto.UUID.generate(),
             action: "login",
             actor_id: user_id,
             details: %{},
             ip_address: "127.0.0.1",
             user_agent: "TestAgent",
             inserted_at: DateTime.utc_now()
           }
         ]}
      end)

      conn = get(conn, ~p"/gdpr/audit-trail")
      assert length(json_response(conn, 200)["audit_trail"]) == 1
    end

    test "respects pagination parameters", %{conn: conn, user: user} do
      user_id = user.id

      expect(ComplianceMock, :get_user_audit_trail, fn ^user_id, limit ->
        assert limit == 10
        {:ok, []}
      end)

      conn = get(conn, ~p"/gdpr/audit-trail", %{"limit" => "10"})
      assert json_response(conn, 200)["audit_trail"] == []
    end
  end

  describe "unauthenticated requests" do
    test "require authentication for GDPR endpoints", %{api_key: api_key} do
      unauth_conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-api-key", api_key)

      conn = post(unauth_conn, ~p"/api/gdpr/export", %{"format" => "json"})
      assert %{"error" => "Authentication required"} = json_response(conn, 401)

      conn = post(unauth_conn, ~p"/api/gdpr/request-deletion", %{"reason" => "test"})
      assert %{"error" => "Authentication required"} = json_response(conn, 401)
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "TestPassword123!",
      password_confirmation: "TestPassword123!"
    }

    tenant_id = Ecto.UUID.generate()

    # Create tenant in DB to satisfy foreign key constraints
    {:ok, tenant} =
      Mcp.Platform.Tenant.create(%{
        name: "Test Tenant #{tenant_id}",
        slug: "test-tenant-#{tenant_id}",
        subdomain: "test-#{tenant_id}"
      })

    # Use the actual ID from the created tenant
    attrs = Map.put_new(attrs, :tenant_id, tenant.id)

    user = User.create_for_test(Map.merge(default_attrs, attrs))
    IO.inspect(user, label: "Created User in Test")
    {:ok, user}
  end
end
