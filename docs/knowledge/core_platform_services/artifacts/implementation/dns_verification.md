# DNS Verification for Custom Domains

Custom domains (Epic 11) allow tenants to brand their portals with unique URLs (e.g., `portal.tenant.com`). Ownership verification is enforced via DNS TXT records.

## 1. DnsVerifier Service

The platform uses `Mcp.Infrastructure.DnsVerifier` to perform non-recursive DNS checks.

### Key Implementation: `:inet_res`
Unlike standard Elixir/OS resolvers that may cache results, the service uses Erlang's `:inet_res` module to query authoritative servers directly. This significantly reduces the wait time for "DNS Propagation" during the user verification flow.

```elixir
def verify_txt(domain, expected_value) do
  charlist_domain = String.to_charlist(domain)

  case :inet_res.lookup(charlist_domain, :in, :txt) do
    [] -> {:ok, false}
    records ->
      # Normalize and verify chunked TXT records
      is_match? = Enum.any?(records, fn chunks -> 
        IO.iodata_to_binary(chunks) == expected_value 
      end)
      {:ok, is_match?}
  end
end
```

## 2. CustomDomain Resource
`Mcp.Platform.CustomDomain` manages the domain lifecycle:
- `:pending_verification`: Token is generated and shown to the user.
- `:verified`: DNS record matches.
- `:active`: Ready for routing.

## 3. Testing Pattern
Verification tests use **Mox** to stub the `DnsVerifier`, ensuring the test suite is fast and offline-capable.

```elixir
# test/mcp/platform/custom_domain_test.exs
test "verifies a custom domain successfully", %{domain: domain} do
  Mcp.Infrastructure.DnsVerifierMock
  |> expect(:verify_txt, fn ^domain.name, ^domain.verification_token -> {:ok, true} end)

  domain |> Ash.update!(action: :verify_dns)
end
```
