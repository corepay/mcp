defmodule Mcp.Underwriting.Services.DocumentAutofill do
  @moduledoc """
  Extracts form-fillable data from validated documents.
  Enables "Zero-Entry" applications by auto-populating fields.

  This service takes structured data extracted from documents (via The Eye)
  and maps it to form fields for the OLA application flow.
  """

  @doc """
  Extracts relevant form fields from document structured data.

  Returns a map of form field names to their values, ready to be
  merged with existing form data.

  ## Examples

      iex> extract_fields(%{"name" => "John Doe"}, :government_id)
      %{"owner_name" => "John Doe"}
  """
  @spec extract_fields(map(), atom()) :: map()
  def extract_fields(structured_data, :government_id) do
    %{
      "owner_name" => structured_data["name"],
      "owner_dob" => structured_data["date_of_birth"],
      "owner_address" => structured_data["address"]
    }
    |> reject_nil_values()
  end

  def extract_fields(structured_data, :bank_statement) do
    account = structured_data["account_number"] || ""
    last4 = extract_last4(account)

    %{
      "bank_name" => structured_data["bank_name"],
      "account_last4" => last4,
      "monthly_volume" => parse_currency(structured_data["ending_balance"])
    }
    |> reject_nil_values()
  end

  def extract_fields(structured_data, :business_license) do
    %{
      "business_name" => structured_data["business_name"],
      "license_number" => structured_data["license_number"],
      "business_address" => structured_data["address"]
    }
    |> reject_nil_values()
  end

  def extract_fields(_data, _type), do: %{}

  @doc """
  Merges extracted fields with existing form data.
  Only fills empty fields - never overwrites user input.

  This preserves any data the user has already entered while
  filling in missing fields from document extraction.

  ## Examples

      iex> merge_with_form(%{"ein" => "12-3456789"}, %{"ein" => ""})
      %{"ein" => "12-3456789"}

      iex> merge_with_form(%{"name" => "From Doc"}, %{"name" => "User Input"})
      %{"name" => "User Input"}
  """
  @spec merge_with_form(map(), map()) :: map()
  def merge_with_form(extracted, existing) do
    Enum.reduce(extracted, existing, fn {key, value}, acc ->
      existing_value = Map.get(acc, key)

      if is_nil(existing_value) || existing_value == "" do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  # Private helpers

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_last4(account) when is_binary(account) and byte_size(account) >= 4 do
    String.slice(account, -4, 4)
  end

  defp extract_last4(_), do: nil

  defp parse_currency(nil), do: nil

  defp parse_currency(str) when is_binary(str) do
    str
    |> String.replace(~r/[$,]/, "")
    |> Float.parse()
    |> case do
      {num, _} -> num
      :error -> nil
    end
  end
end
