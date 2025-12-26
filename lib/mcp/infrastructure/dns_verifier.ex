defmodule Mcp.Infrastructure.DnsVerifier do
  @moduledoc """
  Verifies DNS TXT records for domain ownership proof.
  """

  @callback verify_txt(String.t(), String.t()) :: {:ok, boolean()} | {:error, any()}

  @doc """
  Verifies that a TXT record exists for `domain` with the exact value `expected_value`.
  Returns `{:ok, true}` if found, `{:ok, false}` if not found, or `{:error, reason}`.
  """
  @spec verify_txt(String.t(), String.t()) :: {:ok, boolean()} | {:error, any()}
  def verify_txt(domain, expected_value) do
    # Convert binary string to charlist for Erlang's inet_res
    domain_charlist = String.to_charlist(domain)

    # Use :inet_res.lookup/3 to bypass local hosts file and query DNS directly
    # :in = Internet Class, :txt = TXT Record Type
    case :inet_res.lookup(domain_charlist, :in, :txt) do
      [] ->
        {:ok, false}

      records when is_list(records) ->
        # records is a list of charlists (data of TXT records)
        # We need to flatten chunks if they are split (TXT records > 255 chars are chunked)
        # However, for our simple verification codes, they usually fit in one chunk.
        # :inet_res returns [[~c"value"], [~c"value2"]]

        found? =
          Enum.any?(records, fn record_chunks ->
            txt_value = IO.iodata_to_binary(record_chunks)
            txt_value == expected_value
          end)

        {:ok, found?}
    end
  rescue
    e -> {:error, e}
  end
end
