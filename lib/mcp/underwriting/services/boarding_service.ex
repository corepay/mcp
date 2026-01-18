defmodule Mcp.Underwriting.Services.BoardingService do
  @moduledoc """
  Service for executing the merchant boarding process to external processors.
  """
  alias Mcp.Underwriting.{Application, BankProfile, Boarding, Processor}

  @doc """
  Boards a merchant application to the specified bank profile.
  """
  def board(application_id, bank_profile_id, tenant_schema, opts \\ %{}) do
    # 1. Load Data
    app = Application.get_by_id!(application_id, tenant: tenant_schema)
    profile = BankProfile.get_by_id!(bank_profile_id)
    processor = Processor.get_by_id!(profile.processor_id)
    rationale = opts[:rationale]

    # 2. Resolve Adapter
    adapter = resolve_adapter(processor.name)

    # 3. Execute Boarding
    try do
      case adapter.board_merchant(app, profile) do
        {:ok, result} ->
          # 4. Create Boarding Record
          boarding =
            Boarding.create!(
              %{
                mid: result.mid,
                tid: result.tid,
                status: result.status,
                application_id: app.id,
                processor_id: processor.id,
                bank_profile_id: profile.id,
                rationale: rationale,
                metadata: %{
                  "adapter" => to_string(adapter),
                  "boarded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
                }
              },
              tenant: tenant_schema,
              actor: opts[:actor]
            )

          # 5. Update Application Status
          new_app_status = if result.status == :active, do: :funded, else: :approved

          Application.update!(app, %{status: new_app_status},
            tenant: tenant_schema,
            actor: opts[:actor]
          )

          {:ok, boarding}

        {:error, reason} ->
          # Create Failed Boarding Record
          boarding =
            Boarding.create!(
              %{
                status: :failed,
                application_id: app.id,
                processor_id: processor.id,
                bank_profile_id: profile.id,
                rationale: rationale,
                error_metadata: %{
                  "reason" => inspect(reason),
                  "failed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
                }
              },
              tenant: tenant_schema,
              actor: opts[:actor]
            )

          {:error, {reason, boarding}}
      end
    rescue
      e ->
        # Emergency persistence of failure
        Boarding.create!(
          %{
            status: :failed,
            application_id: app.id,
            processor_id: processor.id,
            bank_profile_id: profile.id,
            rationale: rationale,
            error_metadata: %{
              "exception" => inspect(e),
              "stacktrace" => inspect(__STACKTRACE__),
              "failed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
            }
          },
          tenant: tenant_schema,
          actor: opts[:actor]
        )

        reraise e, __STACKTRACE__
    end
  end

  @doc """
  Synchronizes the status of a pending boarding by polling the adapter.
  """
  def sync_status(boarding, opts \\ %{}) do
    tenant = opts[:tenant] || boarding.__metadata__.tenant
    processor = Processor.get_by_id!(boarding.processor_id)
    adapter = resolve_adapter(processor.name)

    case adapter.check_status(boarding) do
      {:ok, %{status: :active}} ->
        # Update boarding
        Boarding.update!(boarding, %{status: :active}, tenant: tenant, actor: opts[:actor])

        # Update application to funded
        app = Application.get_by_id!(boarding.application_id, tenant: tenant)
        Application.update!(app, %{status: :funded}, tenant: tenant, actor: opts[:actor])
        :ok

      {:ok, %{status: :pending}} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_adapter("Stripe"), do: Mcp.Underwriting.Adapters.StripeBoarding
  defp resolve_adapter("Fiserv"), do: Mcp.Underwriting.Adapters.FiservBoarding
  defp resolve_adapter("QorPay"), do: Mcp.Underwriting.Adapters.QorPayBoarding
  # Fallback to stripe for mock
  defp resolve_adapter("Adyen"), do: Mcp.Underwriting.Adapters.StripeBoarding
  defp resolve_adapter(_), do: Mcp.Underwriting.Adapters.StripeBoarding
end
