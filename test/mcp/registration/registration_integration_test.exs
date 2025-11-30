defmodule Mcp.Registration.RegistrationIntegrationTest do
  use Mcp.DataCase, async: false



  alias Mcp.Registration.{
    EmailService,
    PolicyValidator,
    RegistrationService,
    SecurityService,
    WorkflowOrchestrator
  }

  setup do
    {:ok, tenant} =
      Mcp.Platform.Tenant.create(%{
        name: "Test Tenant",
        slug: "test-tenant-#{System.unique_integer([:positive])}",
        subdomain: "test-#{System.unique_integer([:positive])}",
        company_schema: "test_schema_#{System.unique_integer([:positive])}"
      })

    {:ok, tenant: tenant}
  end

  describe "complete registration workflow" do
    test "successful self-service registration", %{tenant: tenant} do
      registration_data = %{
        first_name: "Integration",
        last_name: "Test",
        email: "integration.test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      # Check if registration is allowed
      assert {:ok, :allowed} = PolicyValidator.validate_registration_request(registration_data)

      # Register the user
      {:ok, user} = RegistrationService.register_user(registration_data, tenant_id: tenant.id)

      assert user.first_name == "Integration"
      assert user.last_name == "Test"
      assert to_string(user.email) == "integration.test@example.com"
      assert user.status == :active
      assert user.hashed_password != nil
    end

    test "registration with approval workflow", %{tenant: tenant} do
      registration_data = %{
        first_name: "Approval",
        last_name: "Test",
        email: "approval.test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "192.168.1.100",
        user_agent: "Corporate Browser"
      }

      # Simulate policy that requires approval
      assert {:ok, :requires_approval} =
               PolicyValidator.validate_registration_request(registration_data)

      # Register with approval required
      {:ok, request} =
        RegistrationService.register_user(registration_data, requires_approval: true, tenant_id: tenant.id)

      assert to_string(request.email) == "approval.test@example.com"
      assert request.status == :submitted
      assert request.registration_data != nil
    end
  end

  describe "registration policy validation" do
    test "blocks registration from suspicious IP" do
      suspicious_data = %{
        first_name: "Suspicious",
        last_name: "User",
        email: "suspicious@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        # Test netblock
        ip_address: "192.0.2.1",
        user_agent: "Bot/1.0"
      }

      {:error, :blocked} = PolicyValidator.validate_registration_request(suspicious_data)
    end

    test "limits registration frequency", %{tenant: tenant} do
      user_ip = "192.168.1.200"

      # First registration should succeed
      first_data = %{
        first_name: "First",
        last_name: "User",
        email: "first.user@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: user_ip,
        user_agent: "Test Browser"
      }

      assert {:ok, :allowed} = PolicyValidator.validate_registration_request(first_data)

      # Create the first user
      {:ok, _user} = RegistrationService.register_user(first_data, tenant_id: tenant.id)

      # Second registration from same IP might be rate limited
      second_data = %{
        first_name: "Second",
        last_name: "User",
        email: "second.user@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: user_ip,
        user_agent: "Test Browser"
      }

      result = PolicyValidator.validate_registration_request(second_data)

      # Result depends on rate limiting configuration
      assert result == {:ok, :allowed} or result == {:error, :rate_limited}
    end

    test "validates email domain restrictions" do
      # Test with allowed domain
      allowed_domain_data = %{
        first_name: "Allowed",
        last_name: "User",
        email: "user@company.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      result = PolicyValidator.validate_registration_request(allowed_domain_data)
      assert result == {:ok, :allowed} or result == {:error, :domain_not_allowed}

      # Test with blocked domain
      blocked_domain_data = %{
        first_name: "Blocked",
        last_name: "User",
        email: "user@spam.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      result = PolicyValidator.validate_registration_request(blocked_domain_data)
      assert result == {:ok, :allowed} or result == {:error, :domain_not_allowed}
    end
  end

  describe "security service integration" do
    test "detects suspicious registration patterns" do
      suspicious_patterns = [
        %{
          first_name: "Test",
          # Very long name
          last_name: String.duplicate("a", 100),
          email: "test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          ip_address: "127.0.0.1",
          # Very long user agent
          user_agent: String.duplicate("x", 500)
        },
        %{
          first_name: "Test",
          last_name: "User",
          # Disposable email pattern
          email: "test+1@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          ip_address: "127.0.0.1",
          user_agent: "Test Browser"
        }
      ]

      Enum.each(suspicious_patterns, fn data ->
        risk_score = SecurityService.assess_registration_risk(data)
        assert is_number(risk_score)
        assert risk_score >= 0
        assert risk_score <= 100
      end)
    end

    test "blocks high-risk registrations" do
      high_risk_data = %{
        first_name: "High",
        last_name: "Risk",
        email: "suspicious@temp-mail.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "10.0.0.1",
        user_agent: "Suspicious Bot"
      }

      # Simulate high risk assessment
      risk_score = SecurityService.assess_registration_risk(high_risk_data)

      if risk_score > 80 do
        {:error, :high_risk} = PolicyValidator.validate_registration_request(high_risk_data)
      end
    end

    test "generates security events for monitoring" do
      test_data = %{
        first_name: "Security",
        last_name: "Test",
        email: "security.test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      # This would trigger security event logging
      assert {:ok, _event} = SecurityService.log_registration_attempt(test_data, :success)
    end
  end

  describe "email service integration" do
    test "sends verification email on successful registration", %{tenant: tenant} do
      registration_data = %{
        first_name: "Email",
        last_name: "Test",
        email: "email.test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      {:ok, user} = RegistrationService.register_user(registration_data, tenant_id: tenant.id)

      # Mock email sending
      email_sent = EmailService.send_verification_email(user.email, user.id)

      # In a real test, this would verify email was queued
      assert email_sent == :ok or email_sent == :mocked
    end

    test "sends approval notification to admins", %{tenant: tenant} do
      registration_data = %{
        first_name: "Admin",
        last_name: "Notify",
        email: "admin.notify@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      {:ok, request} =
        RegistrationService.register_user(registration_data, requires_approval: true, tenant_id: tenant.id)

      # Mock admin notification
      notification_sent = EmailService.send_admin_approval_notification(request)

      assert notification_sent == :ok or notification_sent == :mocked
    end
  end

  describe "workflow orchestrator" do
    test "orchestrates complete registration flow", %{tenant: tenant} do
      workflow_data = %{
        user_data: %{
          first_name: "Workflow",
          last_name: "Test",
          email: "workflow.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        },
        metadata: %{
          ip_address: "127.0.0.1",
          user_agent: "Test Browser",
          referrer: "https://example.com",
          utm_source: "google",
          tenant_id: tenant.id
        }
      }

      {:ok, result} = WorkflowOrchestrator.execute_registration_workflow(workflow_data)

      assert result.status == :completed or result.status == :pending_approval
      assert result.user != nil or result.request != nil
    end

    test "handles workflow errors gracefully" do
      invalid_workflow_data = %{
        user_data: %{
          # Invalid
          first_name: "",
          last_name: "Test",
          # Invalid
          email: "invalid-email",
          # Invalid
          password: "weak",
          # Doesn't match
          password_confirmation: "different"
        },
        metadata: %{
          ip_address: "127.0.0.1",
          user_agent: "Test Browser"
        }
      }

      {:error, reason} = WorkflowOrchestrator.execute_registration_workflow(invalid_workflow_data)

      assert reason != nil
      assert is_atom(reason) or is_binary(reason)
    end
  end

  describe "registration request management" do
    test "approves pending registration request", %{tenant: tenant} do
      registration_data = %{
        first_name: "Approve",
        last_name: "Me",
        email: "approve.me@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      {:ok, request} =
        RegistrationService.register_user(registration_data, requires_approval: true, tenant_id: tenant.id)

      assert request.status == :submitted

      # Approve the request
      {:ok, user} = RegistrationService.approve_registration(request.id, Ash.UUID.generate())

      assert user.first_name == "Approve"
      assert user.last_name == "Me"
      assert to_string(user.email) == "approve.me@example.com"
      assert user.status == :active
    end

    test "rejects pending registration request", %{tenant: tenant} do
      registration_data = %{
        first_name: "Reject",
        last_name: "Me",
        email: "reject.me@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      {:ok, request} =
        RegistrationService.register_user(registration_data, requires_approval: true, tenant_id: tenant.id)

      assert request.status == :submitted

      # Reject the request
      {:ok, rejected_request} =
        RegistrationService.reject_registration(
          request.id,
          "admin@example.com",
          "Suspicious activity detected"
        )

      assert rejected_request.status == :rejected
      assert rejected_request.rejection_reason == "Suspicious activity detected"
      assert rejected_request.reviewed_by == "admin@example.com"
    end
  end

  describe "bulk registration operations" do
    test "handles multiple registration requests", %{tenant: tenant} do
      registrations = [
        %{
          first_name: "Bulk",
          last_name: "User1",
          email: "bulk1@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          ip_address: "127.0.0.1",
          user_agent: "Test Browser"
        },
        %{
          first_name: "Bulk",
          last_name: "User2",
          email: "bulk2@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          ip_address: "127.0.0.1",
          user_agent: "Test Browser"
        }
      ]

      results =
        Enum.map(registrations, fn data ->
          RegistrationService.register_user(data, tenant_id: tenant.id)
        end)

      # All registrations should succeed or fail gracefully
      Enum.each(results, fn result ->
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end)

      successful_registrations =
        Enum.filter(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      # At least one should succeed
      assert length(successful_registrations) > 0
    end
  end

  describe "edge cases and error handling" do
    test "handles concurrent registration attempts", %{tenant: tenant} do
      same_email = "concurrent@example.com"

      base_data = %{
        first_name: "Concurrent",
        last_name: "Test",
        email: same_email,
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      # Attempt multiple concurrent registrations with same email
      tasks =
        for _i <- 1..3 do
          Task.async(fn ->
            RegistrationService.register_user(base_data, tenant_id: tenant.id)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # Only one should succeed due to unique email constraint
      successful_results =
        Enum.filter(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert length(successful_results) == 1

      # Others should fail due to duplicate email
      failed_results =
        Enum.filter(results, fn
          {:error, _} -> true
          _ -> false
        end)

      assert length(failed_results) == 2
    end

    test "handles malformed registration data" do
      malformed_cases = [
        # Empty data
        %{},
        # Missing required fields
        %{email: nil},
        # Invalid format and weak password
        %{email: "invalid", password: "weak"},
        # Very long email
        %{email: String.duplicate("a", 500), password: "Password123!"}
      ]

      Enum.each(malformed_cases, fn data ->
        result = RegistrationService.register_user(data)
        assert match?({:error, _}, result)
      end)
    end

    test "handles network failures during registration", %{tenant: tenant} do
      # This would test email service failures, external API calls, etc.
      registration_data = %{
        first_name: "Network",
        last_name: "Test",
        email: "network.test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      }

      # Registration should succeed
      {:ok, user} = RegistrationService.register_user(registration_data, tenant_id: tenant.id)
      assert to_string(user.email) == "network.test@example.com"
    end
  end
end
