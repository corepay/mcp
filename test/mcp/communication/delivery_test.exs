defmodule Mcp.Communication.DeliveryTest do
  @moduledoc false
  use Mcp.DataCase

  alias Mcp.Accounts.User
  alias Mcp.Communication.DeliveryWorker
  alias Mcp.Communication.WebhookDelivery
  alias Mcp.Communication.WebhookEndpoint
  alias Mcp.Platform.Team
  alias Mcp.Platform.TeamMember
  alias Mcp.Platform.Tenant

  setup do
    unique_id = "delivery#{System.unique_integer([:positive])}"
    {:ok, user} = User.register("#{unique_id}@example.com", "Password123!")

    # Create isolated test tenant
    tenant =
      Mcp.Repo.insert!(%Tenant{
        id: Ecto.UUID.generate(),
        name: "Test Tenant #{unique_id}",
        slug: "test-tenant-#{unique_id}",
        subdomain: "test-#{unique_id}",
        company_schema: "acq_test_#{unique_id}",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      })

    team =
      Team.create!(
        %{
          name: "Delivery Test Team #{unique_id}",
          slug: "delivery-team-#{unique_id}",
          entity_type: :tenant,
          entity_id: tenant.id
        },
        actor: user
      )

    TeamMember.create!(
      %{
        role: :admin,
        user_id: user.id,
        team_id: team.id,
        user_profile_id: Ash.UUID.generate()
      },
      actor: user
    )

    endpoint =
      WebhookEndpoint
      |> Ash.Changeset.for_create(
        :create,
        %{
          url: "https://example.com/webhook",
          events: ["document.processed"],
          tenant_id: tenant.id
        },
        actor: user
      )
      |> Ash.create!(actor: user)

    {:ok, endpoint: endpoint, user: user}
  end

  test "worker sends request and updates status on success", %{endpoint: endpoint, user: user} do
    # Create Delivery
    delivery =
      WebhookDelivery
      |> Ash.Changeset.for_create(:create, %{
        endpoint_id: endpoint.id,
        payload: %{"message" => "hello"}
      })
      |> Ash.create!()

    # Stub Request
    Req.Test.stub(DeliveryWorker, fn conn ->
      assert conn.method == "POST"
      assert conn.host == "example.com"
      assert conn.request_path == "/webhook"

      # Verify signature header presence - implementation returns raw hex
      assert [signature] = Plug.Conn.get_req_header(conn, "x-mcp-signature")
      # SHA256 hex is 64 chars
      assert byte_size(signature) == 64

      Plug.Conn.send_resp(conn, 200, "OK")
    end)

    # Run Worker
    assert :ok = DeliveryWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})

    # Verify Status Updated
    updated_delivery = Ash.reload!(delivery, actor: user)
    assert updated_delivery.status == :success
    assert updated_delivery.response_code == 200
  end

  test "worker handles failure", %{endpoint: endpoint, user: user} do
    delivery =
      WebhookDelivery
      |> Ash.Changeset.for_create(:create, %{
        endpoint_id: endpoint.id,
        payload: %{"fail" => "true"}
      })
      |> Ash.create!()

    Req.Test.stub(DeliveryWorker, fn conn ->
      Plug.Conn.send_resp(conn, 500, "Internal Server Error")
    end)

    # Worker performs and returns {:error, ...} for retry usually
    # Our worker implementation captures error and updates status to :failure for 4xx/5xx responses?
    # Logic: 200..299 -> success, other -> failure?
    # Worker: `{:ok, %Req.Response{status: status}} -> record_result(delivery, :failure, status)`
    # It returns `{:error, ...}` tuple to Oban ONLY if it wants retry?
    # The code says: `{:error, "Webhook failed with status #{status}"}`
    # So Oban will retry.

    result = DeliveryWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})
    assert {:error, "Webhook failed with status 500"} = result

    updated_delivery = Ash.reload!(delivery, actor: user)
    # We updated it before returning error
    assert updated_delivery.status == :failure
    assert updated_delivery.response_code == 500
  end
end
