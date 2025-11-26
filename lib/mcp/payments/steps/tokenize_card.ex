defmodule Mcp.Payments.Steps.TokenizeCard do
  @moduledoc """
  Reactor step to tokenize a card via the gateway.
  """

  use Reactor.Step
  alias Mcp.Payments.Gateways.Factory

  def run(arguments, _context, _options) do
    with {:ok, adapter} <- get_adapter(arguments.provider),
         {:ok, input_params} <- build_input_params(arguments),
         {:ok, result} <- adapter.tokenize(input_params, build_context(arguments)) do
      extract_token_and_metadata(result, input_params)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_adapter(provider) do
    {:ok, Factory.get_adapter(provider)}
  end

  defp build_context(arguments) do
    %{customer_id: arguments.customer_id}
  end

  defp build_input_params(arguments) do
    cond do
      card = get_value(arguments, :card) ->
        {:ok, %{card: card, type: :card}}

      bank_account = get_value(arguments, :bank_account) ->
        {:ok, %{bank_account: bank_account, type: :bank_account}}

      true ->
        {:error, :no_payment_method}
    end
  end

  defp extract_token_and_metadata(result, input_params) do
    token = result["token"] || result[:token]
    metadata = extract_metadata(result, input_params)

    {:ok, Map.merge(%{provider_token: token}, metadata)}
  end

  defp extract_metadata(result, %{type: :card} = input_params) do
    %{
      last4: Map.get(result, "last_4") || String.slice(input_params.card[:number] || "", -4..-1),
      brand: Map.get(result, "card_type") || detect_brand(input_params.card[:number]),
      exp_month: input_params.card[:exp_month],
      exp_year: input_params.card[:exp_year]
    }
  end

  defp extract_metadata(result, %{type: :bank_account} = input_params) do
    %{
      last4_account: String.slice(input_params.bank_account[:account_number] || "", -4..-1),
      bank_name: input_params.bank_account[:bank_name],
      account_type: input_params.bank_account[:account_type],
      account_holder_name: input_params.bank_account[:account_holder_name]
    }
  end

  defp extract_metadata(_result, _input_params), do: %{}

  defp get_value(map, key) when is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp get_value(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    _ -> nil
  end

  defp detect_brand(nil), do: "unknown"

  defp detect_brand(number) do
    cond do
      String.starts_with?(number, "4") -> "visa"
      String.starts_with?(number, "5") -> "mastercard"
      String.starts_with?(number, "3") -> "amex"
      true -> "unknown"
    end
  end
end
