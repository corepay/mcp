defmodule Mcp.Registration.RegistrationServiceTest do
  use Mcp.DataCase, async: true

  alias Mcp.Registration.RegistrationService
  alias Mcp.Accounts.RegistrationRequest

  describe "initialize_registration/4" do
    test "creates a registration request successfully" do
      tenant_id = Ecto.UUID.generate()
      registration_data = %{
        "email" => "test@example.com",
        "first_name" => "John",
        "last_name" => "Doe",
        "company_name" => "Test Company"
      }

      {:ok, request} = RegistrationService.initialize_registration(
        tenant_id,
        :customer,
        registration_data,
        %{"source" => "web"}
      )

      assert request.tenant_id == tenant_id
      assert request.type == :customer
      assert request.email == "test@example.com"
      assert request.first_name == "John"
      assert request.last_name == "Doe"
      assert request.company_name == "Test Company"
      assert request.status == :pending
      assert request.context["source"] == "web"
      assert request.inserted_at != nil
    end

    test "handles invalid registration data" do
      tenant_id = Ecto.UUID.generate()
      registration_data = %{}

      {:error, reason} = RegistrationService.initialize_registration(
        tenant_id,
        :customer,
        registration_data,
        %{}
      )

      assert reason != nil
    end
  end

  describe "submit_registration/1" do
    test "submits a pending registration request" do
      # Create a registration request first
      {:ok, request} = insert(:registration_request)
      assert request.status == :pending

      {:ok, submitted} = RegistrationService.submit_registration(request.id)

      assert submitted.status == :submitted
      assert submitted.submitted_at != nil
    end

    test "returns error for non-existent request" do
      non_existent_id = Ecto.UUID.generate()

      {:error, :not_found} = RegistrationService.submit_registration(non_existent_id)
    end
  end

  describe "approve_registration/2" do
    test "approves a submitted registration request" do
      # Create and submit a registration request
      {:ok, request} = insert(:submitted_registration_request)
      approver_id = Ecto.UUID.generate()

      {:ok, approved} = RegistrationService.approve_registration(request.id, approver_id)

      assert approved.status == :approved
      assert approved.approved_by_id == approver_id
      assert approved.approved_at != nil
    end

    test "returns error for non-existent request" do
      non_existent_id = Ecto.UUID.generate()
      approver_id = Ecto.UUID.generate()

      {:error, :not_found} = RegistrationService.approve_registration(non_existent_id, approver_id)
    end
  end

  describe "reject_registration/2" do
    test "rejects a registration request with reason" do
      # Create and submit a registration request
      {:ok, request} = insert(:submitted_registration_request)
      reason = "Invalid company information"

      {:ok, rejected} = RegistrationService.reject_registration(request.id, reason)

      assert rejected.status == :rejected
      assert rejected.rejection_reason == reason
      assert rejected.rejected_at != nil
    end

    test "returns error for non-existent request" do
      non_existent_id = Ecto.UUID.generate()
      reason = "Test rejection"

      {:error, :not_found} = RegistrationService.reject_registration(non_existent_id, reason)
    end

    test "returns error for invalid reason" do
      {:ok, request} = insert(:submitted_registration_request)

      {:error, :invalid_reason} = RegistrationService.reject_registration(request.id, 123)
    end
  end

  describe "get_registration/1" do
    test "returns existing registration request" do
      {:ok, request} = insert(:registration_request)

      {:ok, found} = RegistrationService.get_registration(request.id)

      assert found.id == request.id
      assert found.email == request.email
      assert found.status == request.status
    end

    test "returns error for non-existent request" do
      non_existent_id = Ecto.UUID.generate()

      {:error, :not_found} = RegistrationService.get_registration(non_existent_id)
    end
  end

  describe "list_pending_registrations/1" do
    test "returns all pending registration requests when no tenant specified" do
      # Create mixed status requests
      {:ok, _pending1} = insert(:registration_request, %{email: "pending1@example.com"})
      {:ok, _pending2} = insert(:registration_request, %{email: "pending2@example.com"})
      {:ok, _submitted} = insert(:submitted_registration_request, %{email: "submitted@example.com"})
      {:ok, _approved} = insert(:approved_registration_request, %{email: "approved@example.com"})

      {:ok, pending} = RegistrationService.list_pending_registrations()

      assert length(pending) == 2
      assert Enum.all?(pending, fn r -> r.status == :pending end)
    end

    test "returns pending requests for specific tenant" do
      tenant_id = Ecto.UUID.generate()

      # Create requests for the tenant
      {:ok, _pending1} = insert(:registration_request, %{tenant_id: tenant_id, email: "pending1@example.com"})
      {:ok, _pending2} = insert(:registration_request, %{tenant_id: tenant_id, email: "pending2@example.com"})
      {:ok, _submitted} = insert(:submitted_registration_request, %{tenant_id: tenant_id, email: "submitted@example.com"})

      # Create requests for another tenant
      other_tenant_id = Ecto.UUID.generate()
      {:ok, _other_pending} = insert(:registration_request, %{tenant_id: other_tenant_id, email: "other@example.com"})

      {:ok, pending} = RegistrationService.list_pending_registrations(tenant_id)

      assert length(pending) == 2
      assert Enum.all?(pending, fn r -> r.tenant_id == tenant_id end)
      assert Enum.all?(pending, fn r -> r.status == :pending end)
    end
  end

  describe "get_registration_status/1" do
    test "returns detailed status for existing request" do
      {:ok, request} = insert(:submitted_registration_request, %{
        submitted_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
      })

      {:ok, status} = RegistrationService.get_registration_status(request.id)

      assert status.id == request.id
      assert status.status == :submitted
      assert status.email == request.email
      assert status.type == request.type
      assert status.submitted_at != nil
      assert status.approved_at == nil
      assert status.rejected_at == nil
      assert status.rejection_reason == nil
    end

    test "returns error for non-existent request" do
      non_existent_id = Ecto.UUID.generate()

      {:error, :not_found} = RegistrationService.get_registration_status(non_existent_id)
    end
  end

  describe "process_registration/1" do
    test "processes approved registration and creates user" do
      {:ok, request} = insert(:approved_registration_request)

      {:ok, user} = RegistrationService.process_registration(request.id)

      assert user.email == request.email
      assert user.status == :active
      assert user.inserted_at != nil
    end

    test "returns error for non-existent request" do
      non_existent_id = Ecto.UUID.generate()

      {:error, :not_found} = RegistrationService.process_registration(non_existent_id)
    end

    test "returns error for non-approved request" do
      {:ok, request} = insert(:submitted_registration_request)

      {:error, :not_approved} = RegistrationService.process_registration(request.id)
    end
  end
end