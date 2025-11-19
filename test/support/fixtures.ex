defmodule Mcp.TestFixtures do
  @moduledoc """
  Common test fixtures and test data for reuse across tests.
  """

  # Import ExMachina if available
  if Code.ensure_loaded?(ExMachina) do
    import ExMachina
  end

  # Common test data
  @valid_user_attrs %{
    email: "test@example.com",
    password: "password123",
    password_confirmation: "password123"
  }

  @valid_tenant_attrs %{
    name: "Test Tenant",
    slug: "test-tenant",
    subdomain: "testtenant",
    description: "A test tenant for testing purposes"
  }

  @valid_user_profile_attrs %{
    display_name: "Test User",
    bio: "A test user for testing purposes",
    is_admin: false,
    is_developer: false
  }

  # Error scenarios
  @invalid_user_attrs %{
    email: "invalid-email",
    password: "short",
    password_confirmation: "different"
  }

  @invalid_tenant_attrs %{
    name: "",
    slug: "invalid slug!",
    subdomain: "Invalid Subdomain"
  }

  # API responses
  def api_response(data, status \\ :ok) do
    %{
      data: data,
      status: status,
      message: message_for_status(status)
    }
  end

  def api_error(message, status \\ :bad_request) do
    %{
      error: message,
      status: status,
      message: message_for_status(status)
    }
  end

  # Pagination fixtures
  def paginated_response(data, page \\ 1, page_size \\ 10, total \\ nil) do
    actual_total = total || length(data)
    total_pages = ceil(actual_total / page_size)

    %{
      data: data,
      pagination: %{
        page: page,
        page_size: page_size,
        total: actual_total,
        total_pages: total_pages,
        has_next: page < total_pages,
        has_prev: page > 1
      }
    }
  end

  # Helper functions
  def message_for_status(:ok), do: "Success"
  def message_for_status(:created), do: "Resource created successfully"
  def message_for_status(:updated), do: "Resource updated successfully"
  def message_for_status(:deleted), do: "Resource deleted successfully"
  def message_for_status(:bad_request), do: "Bad request"
  def message_for_status(:unauthorized), do: "Unauthorized"
  def message_for_status(:forbidden), do: "Forbidden"
  def message_for_status(:not_found), do: "Resource not found"
  def message_for_status(:conflict), do: "Resource conflict"
  def message_for_status(:unprocessable_entity), do: "Validation failed"
  def message_for_status(:internal_server_error), do: "Internal server error"

  # Getters for use in tests
  def valid_user_attrs, do: @valid_user_attrs
  def valid_tenant_attrs, do: @valid_tenant_attrs
  def valid_user_profile_attrs, do: @valid_user_profile_attrs
  def invalid_user_attrs, do: @invalid_user_attrs
  def invalid_tenant_attrs, do: @invalid_tenant_attrs

  # Auth fixtures
  def auth_headers(user) do
    token = generate_jwt_token(user)
    %{
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end

  def generate_jwt_token(user) do
    # This would typically use your actual JWT implementation
    # For testing purposes, we can create a mock token
    "mock_jwt_token_#{user.id}"
  end

  # Test data generators
  def generate_email do
    sequence = :crypto.strong_rand_bytes(8) |> Base.encode16()
    "test-#{sequence}@example.com"
  end

  def generate_slug(base \\ "test") do
    sequence = :crypto.strong_rand_bytes(4) |> Base.encode16()
    "#{base}-#{sequence}"
  end

  # JSON fixtures
  def valid_user_json do
    Jason.encode!(@valid_user_attrs)
  end

  def invalid_user_json do
    Jason.encode!(@invalid_user_attrs)
  end

  def valid_tenant_json do
    Jason.encode!(@valid_tenant_attrs)
  end

  # Multi-tenant fixtures
  def tenant_context(tenant) do
    %{
      tenant: tenant,
      search_path: "acq_#{tenant.slug},platform,shared,public",
      headers: %{
        "X-Tenant-ID" => tenant.id,
        "X-Tenant-Slug" => tenant.slug
      }
    }
  end

  # Integration test fixtures (simplified)
  def setup_multi_tenant_test(context) do
    # Placeholder for multi-tenant test setup
    %{context | tenant: nil, user: nil}
  end

  # Performance test fixtures (simplified)
  def generate_bulk_users(_count) do
    # Placeholder implementation
    []
  end

  def generate_bulk_tenants(_count) do
    # Placeholder implementation
    []
  end
end