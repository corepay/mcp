defmodule McpWeb.GdprControllerTest do
  use McpWeb.ConnCase, async: true

  import Mox

  alias Mcp.Accounts.User
  alias Mcp.Gdpr.Compliance

  setup %{conn: conn} do
    {:ok, user} = create_test_user()

    auth_conn =
      init_test_session(conn, %{})
      |> assign(:current_user, user)

    %{conn: auth_conn, user: user}
  end

  describe "GET /gdpr/data-export" do
    test "renders export request page", %{conn: conn} do
      conn = get(conn, ~p"/gdpr/data-export")

      assert html_response(conn, 200) =~ "Data Export"
    end
  end

  describe "POST /gdpr/data-export" do
    test "creates data export request", %{conn: conn} do
      expect(ComplianceMock, :request_data_export, fn _user_id, "json", _categories, _context ->
        {:ok,
         %{
           id: Ecto.UUID.generate(),
           status: "requested",
           requested_format: "json",
           requested_at: DateTime.utc_now()
         }}
      end)

      conn = post(conn, ~p"/gdpr/data-export", %{"format" => "json"})

      assert %{"success" => true} = json_response(conn, 202)

      assert %{"export_request" => %{"format" => "json", "status" => "requested"}} =
               json_response(conn, 202)
    end

    test "returns error for invalid format", %{conn: conn} do
      conn = post(conn, ~p"/gdpr/data-export", %{"format" => "xml"})

      assert %{"error" => "Unsupported export format"} = json_response(conn, 400)
    end
  end

  describe "GET /gdpr/export/:token" do
    test "downloads export file", %{conn: conn} do
      token = "test-token"

      expect(Mcp.Gdpr.ExportMock, :download_export, fn ^token ->
        {:ok, "/tmp/export.json", "user-data.json", "application/json"}
      end)

      conn = get(conn, ~p"/gdpr/export/#{token}")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment"
    end

    test "returns 404 for invalid token", %{conn: conn} do
      expect(Mcp.Gdpr.ExportMock, :download_export, fn "invalid-token" ->
        {:error, :not_found}
      end)

      conn = get(conn, ~p"/gdpr/export/invalid-token")

      assert %{"error" => "Export not found or expired"} = json_response(conn, 404)
    end
  end

  describe "POST /gdpr/request-deletion" do
    test "creates deletion request", %{conn: conn, user: user} do
      user_id = user.id
      expect(ComplianceMock, :initiate_soft_deletion, fn ^user_id, "test_reason", _context ->
        {:ok,
         %{user: %{id: user.id, status: :deleted, gdpr_retention_expires_at: DateTime.utc_now()}}}
      end)

      conn = post(conn, ~p"/gdpr/request-deletion", %{"reason" => "test_reason"})

      assert %{"success" => true} = json_response(conn, 200)
      assert %{"deletion_info" => %{"can_cancel" => true}} = json_response(conn, 200)
    end

    test "returns error for missing reason", %{conn: conn} do
      conn = post(conn, ~p"/gdpr/request-deletion", %{})

      assert response(conn, 400)
    end
  end

  describe "POST /gdpr/cancel-deletion" do
    test "cels pending deletion", %{conn: conn, user: user} do
      user_id = user.id
      expect(ComplianceMock, :cancel_deletion_request, fn ^user_id, ^user_id, "user_canceled" ->
        {:ok, %{user: %{id: user.id, status: :active}}}
      end)

      conn = post(conn, ~p"/gdpr/cancel-deletion", %{"reason" => "user_canceled"})
      assert json_response(conn, 200)["status"] == "cancelled"
    end
  end

  describe "GET /gdpr/consent" do
    test "gets user consent status", %{conn: conn, user: user} do
      user_id = user.id
      expect(Mcp.Gdpr.ConsentMock, :get_user_consents, fn ^user_id ->
        {:ok,
         [
           %{
             consent_type: "marketing",
             granted: true,
             granted_at: DateTime.utc_now()
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
      expect(Mcp.Gdpr.ConsentMock, :record_consent, fn ^user_id,
                                                       "marketing",
                                                       true,
                                                       _context ->
        {:ok, %{consent_type: "marketing", granted: true}}
      end)

      consent_params = %{"consent" => %{"marketing" => true}}

      conn = post(conn, ~p"/gdpr/consent", consent_params)

      assert %{"success" => true} = json_response(conn, 200)
    end
  end

  describe "GET /gdpr/audit-trail" do
    test "gets user audit trail", %{conn: conn, user: user} do
      user_id = user.id
      expect(ComplianceMock, :get_user_audit_trail, fn ^user_id, _opts ->
        {:ok,
         [
           %{
             action: "login",
             ip_address: "127.0.0.1",
             timestamp: DateTime.utc_now()
           }
         ]}
      end)

      conn = get(conn, ~p"/gdpr/audit-trail")
      assert length(json_response(conn, 200)["events"]) == 1
    end

    test "respects pagination parameters", %{conn: conn, user: user} do
      user_id = user.id
      expect(ComplianceMock, :get_user_audit_trail, fn ^user_id, opts ->
        assert opts[:limit] == 10
        assert opts[:offset] == 0
        {:ok, []}
      end)

      conn = get(conn, ~p"/gdpr/audit-trail", %{"limit" => "10", "offset" => "0"})
      assert json_response(conn, 200)["events"] == []
    end
  end

  describe "unauthenticated requests" do
    test "require authentication for GDPR endpoints", %{conn: conn} do
      # Remove current_user assignment
      unauth_conn = assign(conn, :current_user, nil)

      conn = post(unauth_conn, ~p"/gdpr/data-export", %{"format" => "json"})
      assert %{"error" => "Authentication required"} = json_response(conn, 401)

      conn = post(unauth_conn, ~p"/gdpr/request-deletion", %{"reason" => "test"})
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

    final_attrs = Map.merge(default_attrs, attrs)

    %User{}
    |> Ecto.Changeset.change(final_attrs)
    |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt(final_attrs.password))
    |> Repo.insert()
  end
end
