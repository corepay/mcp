defmodule Mcp.Underwriting.Jobs.BoardingStatusWorker do
  @moduledoc """
  Oban worker that polls for status updates on pending boarding records.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Ash.Query
  require Logger

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Boarding
  alias Mcp.Underwriting.Services.BoardingService

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    tenants = list_tenants()

    Enum.each(tenants, fn tenant ->
      sync_pending_boardings(tenant)
    end)

    :ok
  end

  defp list_tenants do
    case Tenant.read(authorize?: false) do
      {:ok, tenants} -> tenants
      _ -> []
    end
  end

  defp sync_pending_boardings(tenant) do
    pending_boardings =
      Boarding
      |> Ash.Query.filter(status == :pending)
      |> Ash.read(tenant: tenant.company_schema, authorize?: false)
      |> case do
        {:ok, items} -> items
        _ -> []
      end

    Enum.each(pending_boardings, fn boarding ->
      # Provide a system actor or bypass authorization for background sync
      case BoardingService.sync_status(boarding, tenant: tenant.company_schema) do
        :ok ->
          Logger.info("Synced boarding status for #{boarding.id}: Active")

        {:error, reason} ->
          Logger.warning("Failed to sync boarding status for #{boarding.id}: #{inspect(reason)}")
      end
    end)
  end
end
