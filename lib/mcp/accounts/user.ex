defmodule Mcp.Accounts.User do
  @moduledoc """
  User schema and operations.
  """

  defstruct [:id, :email, :name, :tenant_id]

  @doc """
  Gets a user by ID.
  """
  def get(id) do
    # Stub implementation
    {:ok, %__MODULE__{id: id, email: "user@example.com", name: "Test User", tenant_id: nil}}
  end

  @doc """
  Gets a user by email.
  """
  def get_by_email(email) do
    # Stub implementation
    {:ok, %__MODULE__{id: UUID.uuid4(), email: email, name: "Test User", tenant_id: nil}}
  end

  @doc """
  Creates a new user.
  """
  def create(attrs) do
    # Stub implementation
    {:ok, %__MODULE__{id: UUID.uuid4(), email: attrs["email"], name: attrs["name"], tenant_id: attrs["tenant_id"]}}
  end

  @doc """
  Updates a user.
  """
  def update(user, attrs) do
    # Stub implementation
    {:ok, struct(user, attrs)}
  end
end