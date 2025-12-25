defmodule Mcp.Underwriting.Engine.InstructionLookup do
  @moduledoc """
  Handles lookup of instruction sets for agent blueprints with proper tenant scoping.
  Implements a fallback strategy: tenant-specific -> default -> generated.
  """

  require Ash.Query

  alias Mcp.Underwriting.{AgentBlueprint, InstructionSet}

  @doc """
  Finds the appropriate instruction set for a blueprint and tenant.

  Lookup strategy:
  1. First, try to find a tenant-specific instruction set
  2. If not found, look for a default instruction set (no tenant)
  3. If still not found, generate a default instruction set

  Returns an InstructionSet struct.
  """
  def find(blueprint_id, tenant_id) do
    case find_tenant_specific(blueprint_id, tenant_id) do
      {:ok, instruction} when not is_nil(instruction) ->
        instruction

      _ ->
        find_default(blueprint_id) || generate_default(blueprint_id)
    end
  end

  @doc """
  Finds a tenant-specific instruction set for the given blueprint.
  """
  def find_tenant_specific(_blueprint_id, nil), do: {:ok, nil}

  def find_tenant_specific(blueprint_id, tenant_id) do
    result =
      InstructionSet
      |> Ash.Query.filter(blueprint_id == ^blueprint_id and tenant_id == ^tenant_id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one()

    case result do
      {:ok, instruction} -> {:ok, instruction}
      {:error, _} -> {:ok, nil}
    end
  end

  @doc """
  Finds a default (non-tenant-specific) instruction set for the given blueprint.
  """
  def find_default(blueprint_id) do
    result =
      InstructionSet
      |> Ash.Query.filter(blueprint_id == ^blueprint_id and is_nil(tenant_id))
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one()

    case result do
      {:ok, instruction} -> instruction
      {:error, _} -> nil
    end
  end

  @doc """
  Generates a default instruction set for the given blueprint.
  This is used when no stored instruction set exists.
  """
  def generate_default(blueprint_id) do
    # Try to get the blueprint name for a more meaningful default
    blueprint_name =
      case Ash.get(AgentBlueprint, blueprint_id) do
        {:ok, blueprint} -> blueprint.name
        _ -> "Agent"
      end

    %InstructionSet{
      name: "Generated Default",
      instructions: "Default policy for #{blueprint_name}. Follow standard operating procedures."
    }
  end
end
