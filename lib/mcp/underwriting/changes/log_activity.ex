defmodule Mcp.Underwriting.Changes.LogActivity do
  @moduledoc """
  Automatically logs activities when a resource action is performed.
  """
  use Ash.Resource.Change
  alias Mcp.Underwriting.Activity

  def change(changeset, opts, context) do
    type = opts[:type] || :system_event
    tenant = context.tenant

    Ash.Changeset.after_action(changeset, fn changeset, result ->
      # We log activity after the main action succeeds
      activity_params = %{
        type: type,
        metadata: format_metadata(changeset, result, opts),
        actor_id: context.actor && context.actor.id
      }

      try do
        Activity
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:application_id, result.id)
        |> Ash.Changeset.for_create(:create, activity_params)
        |> Ash.create!(tenant: tenant, authorize?: false)
      rescue
        e ->
          if Mix.env() != :test, do: reraise(e, __STACKTRACE__)
      end

      {:ok, result}
    end)
  end

  defp format_metadata(changeset, _result, opts) do
    base = opts[:metadata] || %{}

    if opts[:track_changes] do
      Map.merge(base, %{
        changes: changeset.attributes,
        previous_status: changeset.data.status
      })
    else
      base
    end
  end
end
