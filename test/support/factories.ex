defmodule Mcp.TestFactories do
  @moduledoc """
  Test factories for creating Ash resource test records.
  """

  alias Mcp.Accounts.{RegistrationRequest, User}
  alias Mcp.Platform.{ApiKey, Merchant, Tenant}
  alias Mcp.Repo

  # Main insert function that mimics ExMachina but works with Ash
  def insert(factory_name, attrs \\ %{})

  def insert(:user, attrs) do
    email = Map.get(attrs, :email, sequence(:email, &"user#{&1}@example.com"))
    password = Map.get(attrs, :password, "password123")

    user_attrs =
      %{
        "email" => email,
        "password" => password,
        "password_confirmation" => Map.get(attrs, :password_confirmation, password)
      }
      |> Map.merge(attrs_to_string_map(attrs))

    case User.register(
           user_attrs["email"],
           user_attrs["password"],
           user_attrs["password_confirmation"]
         ) do
      {:ok, user} -> user
      {:error, reason} -> raise "Failed to create user: #{inspect(reason)}"
    end
  end

  def insert(:registration_request, attrs) do
    tenant_id =
      if Map.has_key?(attrs, :tenant_id) do
        attrs.tenant_id
      else
        id = Ecto.UUID.generate()

        Repo.insert!(%Tenant{
          id: id,
          name: "Factory Tenant #{id}",
          slug: "factory-tenant-#{id}",
          company_schema: "factory_tenant_#{String.replace(id, "-", "_")}",
          subdomain: "factory-#{id}",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })

        id
      end

    default_attrs =
      %{
        tenant_id: tenant_id,
        type: Map.get(attrs, :type, :customer),
        email: Map.get(attrs, :email, sequence(:email, &"register#{&1}@example.com")),
        first_name: Map.get(attrs, :first_name, "Test"),
        last_name: Map.get(attrs, :last_name, "User"),
        phone: Map.get(attrs, :phone, "+1234567890"),
        company_name: Map.get(attrs, :company_name, "Test Company"),
        registration_data: Map.get(attrs, :registration_data, %{}),
        context: Map.get(attrs, :context, %{})
      }
      |> Map.merge(attrs_to_string_map(attrs))

    case RegistrationRequest.initialize(
           default_attrs.tenant_id,
           default_attrs.type,
           default_attrs.email,
           default_attrs.first_name,
           default_attrs.last_name,
           default_attrs.phone,
           default_attrs.company_name,
           default_attrs.registration_data,
           default_attrs.context
         ) do
      {:ok, request} -> request
      {:error, reason} -> raise "Failed to create registration request: #{inspect(reason)}"
    end
  end

  # Variant factories for registration requests
  def insert(:vendor_registration_request, attrs) do
    insert(
      :registration_request,
      Map.merge(attrs, %{type: :vendor, company_name: "Test Vendor Company"})
    )
  end

  def insert(:merchant_registration_request, attrs) do
    insert(
      :registration_request,
      Map.merge(attrs, %{type: :merchant, company_name: "Test Merchant Company"})
    )
  end

  def insert(:submitted_registration_request, attrs) do
    request = insert(:registration_request, attrs)

    {:ok, submitted} = RegistrationRequest.submit(request, %{})

    submitted
  end

  def insert(:approved_registration_request, attrs) do
    request = insert(:submitted_registration_request, attrs)
    approver_id = Map.get(attrs, :approved_by_id, Ecto.UUID.generate())

    {:ok, approved} = RegistrationRequest.approve(request, approver_id)

    approved
  end

  def insert(:rejected_registration_request, attrs) do
    request = insert(:submitted_registration_request, attrs)
    reason = Map.get(attrs, :rejection_reason, "Test rejection")

    {:ok, rejected} =
      request
      |> RegistrationRequest.reject(reason, "system")
      |> Ash.update()

    rejected
  end

  def insert(:tenant, attrs) do
    attrs = Map.new(attrs)

    tenant_attrs =
      %{
        name: Map.get(attrs, :name, sequence(:name, &"Test Tenant #{&1}")),
        slug: Map.get(attrs, :slug, sequence(:slug, &"tenant-#{&1}")),
        subdomain: Map.get(attrs, :subdomain, sequence(:subdomain, &"subdomain-#{&1}")),
        company_schema: Map.get(attrs, :company_schema, sequence(:schema, &"acq_test_#{&1}")),
        plan: Map.get(attrs, :plan, :starter)
      }
      |> Map.merge(attrs)

    case Tenant.create(tenant_attrs) do
      {:ok, tenant} ->
        tenant

      {:error, reason} ->
        raise "Failed to create tenant: #{inspect(reason)}"
    end
  end

  def insert(:merchant, attrs) do
    attrs = Map.new(attrs)

    merchant_attrs =
      %{
        business_name: Map.get(attrs, :business_name, sequence(:name, &"Test Merchant #{&1}")),
        status: Map.get(attrs, :status, :active),
        email: Map.get(attrs, :email, sequence(:email, &"merchant#{&1}@example.com"))
      }
      |> Map.merge(attrs)

    tenant = Map.get(attrs, :tenant)

    case Merchant.create(merchant_attrs, tenant: tenant) do
      {:ok, merchant} -> merchant
      {:error, reason} -> raise "Failed to create merchant: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a Platform.ApiKey and returns {api_key, raw_key}.
  The raw_key is needed for authentication since the key is hashed on create.

  ## Options
    * :prefix - Key prefix (default: "test")
    * :type - Key type: :developer, :merchant, :reseller (default: :developer)
    * :scopes - List of permission scopes (default: [])
    * :owner_id - Owner UUID (default: generated)
    * :owner_type - Owner type: :user, :tenant (default: :user)
  """
  def insert(:api_key, attrs) do
    owner_id = Map.get(attrs, :owner_id, Ecto.UUID.generate())
    owner_type = Map.get(attrs, :owner_type, :user)
    prefix = Map.get(attrs, :prefix, "test")
    type = Map.get(attrs, :type, :developer)
    scopes = Map.get(attrs, :scopes, [])

    {:ok, api_key} =
      ApiKey.create(%{
        prefix: prefix,
        type: type,
        scopes: scopes,
        owner_id: owner_id,
        owner_type: owner_type
      })

    # The raw key is stored in metadata by HashApiKey change
    raw_key = Ash.Resource.get_metadata(api_key, :raw_key)

    {api_key, raw_key}
  end

  @doc """
  Creates a Platform.ApiKey and returns just the raw_key string.
  Convenience wrapper for tests that only need the key for headers.
  """
  def create_api_key(scopes \\ [], opts \\ []) do
    attrs = %{
      scopes: scopes,
      owner_id: Keyword.get(opts, :owner_id, Ecto.UUID.generate()),
      owner_type: Keyword.get(opts, :owner_type, :user),
      prefix: Keyword.get(opts, :prefix, "test"),
      type: Keyword.get(opts, :type, :developer)
    }

    {_api_key, raw_key} = insert(:api_key, attrs)
    raw_key
  end

  # Build function for creating structs without persisting
  def build(factory_name, attrs \\ %{})

  def build(:user, attrs) do
    %{
      id: Ecto.UUID.generate(),
      email: Map.get(attrs, :email, sequence(:email, &"user#{&1}@example.com")),
      status: Map.get(attrs, :status, :active),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)
  end

  def build(:registration_request, attrs) do
    %{
      id: Ecto.UUID.generate(),
      tenant_id: Map.get(attrs, :tenant_id, Ecto.UUID.generate()),
      type: Map.get(attrs, :type, :customer),
      email: Map.get(attrs, :email, sequence(:email, &"register#{&1}@example.com")),
      first_name: Map.get(attrs, :first_name, "Test"),
      last_name: Map.get(attrs, :last_name, "User"),
      phone: Map.get(attrs, :phone, "+1234567890"),
      company_name: Map.get(attrs, :company_name, "Test Company"),
      registration_data: Map.get(attrs, :registration_data, %{}),
      status: Map.get(attrs, :status, :pending),
      context: Map.get(attrs, :context, %{}),
      submitted_at: nil,
      approved_at: nil,
      rejected_at: nil,
      approved_by_id: nil,
      rejection_reason: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)
  end

  def build(:tenant, attrs) do
    %{
      id: Ecto.UUID.generate(),
      name: Map.get(attrs, :name, sequence(:name, &"Test Tenant #{&1}")),
      slug: Map.get(attrs, :slug, sequence(:slug, &"tenant-#{&1}")),
      subdomain: Map.get(attrs, :subdomain, sequence(:subdomain, &"subdomain#{&1}")),
      plan: Map.get(attrs, :plan, "basic"),
      status: Map.get(attrs, :status, :active),
      company_schema: Map.get(attrs, :company_schema, sequence(:schema, &"acq_test_#{&1}")),
      settings: Map.get(attrs, :settings, %{}),
      branding: Map.get(attrs, :branding, %{}),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)
  end

  # Helper function to create sequence values
  defp sequence(_field, generator) when is_function(generator) do
    :erlang.unique_integer()
    |> generator.()
  end

  # Helper to convert atom keys to string keys for Ash
  defp attrs_to_string_map(attrs) do
    for {key, value} <- attrs, into: %{} do
      {to_string(key), value}
    end
  end

  # Helper functions for test data
  def valid_user_attrs do
    %{
      email: sequence(:email, &"test#{&1}@example.com"),
      password: "password123",
      password_confirmation: "password123"
    }
  end

  def valid_registration_request_attrs do
    %{
      tenant_id: Ecto.UUID.generate(),
      type: :customer,
      email: sequence(:email, &"register#{&1}@example.com"),
      first_name: "Test",
      last_name: "User",
      phone: "+1234567890",
      company_name: "Test Company",
      registration_data: %{},
      context: %{}
    }
  end
end
