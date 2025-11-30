defmodule Mcp.SSL.SSLManagerTest do
  use ExUnit.Case, async: true

  alias Mcp.Platform.Tenant
  alias Mcp.SSL.SSLManager

  @sample_tenant %Tenant{
    id: "123e4567-e89b-12d3-a456-426614174000",
    slug: "test-tenant",
    name: "Test Company",
    company_schema: "test_tenant",
    subdomain: "test",
    custom_domain: "test-company.com",
    plan: :professional,
    status: :active
  }

  @tenant_without_custom_domain %Tenant{
    id: "123e4567-e89b-12d3-a456-426614174001",
    slug: "basic-tenant",
    name: "Basic Company",
    company_schema: "basic_tenant",
    subdomain: "basic",
    custom_domain: nil,
    plan: :starter,
    status: :active
  }

  describe "ssl_enabled?" do
    test "returns configuration value" do
      Application.put_env(:mcp, :ssl_enabled, true)
      assert SSLManager.ssl_enabled?() == true

      Application.put_env(:mcp, :ssl_enabled, false)
      assert SSLManager.ssl_enabled?() == false
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end
  end

  describe "get_ssl_config" do
    test "returns SSL config when enabled" do
      Application.put_env(:mcp, :ssl_enabled, true)
      Application.put_env(:mcp, :ssl_provider, :letsencrypt)

      config = SSLManager.get_ssl_config(@sample_tenant)

      assert config.enabled == true
      assert config.auto_renew == true
      assert config.provider == :letsencrypt
      assert "test" in config.domains
      assert "test-company.com" in config.domains
    after
      Application.put_env(:mcp, :ssl_enabled, false)
      Application.put_env(:mcp, :ssl_provider, :letsencrypt)
    end

    test "returns disabled config when SSL is disabled" do
      Application.put_env(:mcp, :ssl_enabled, false)

      config = SSLManager.get_ssl_config(@sample_tenant)

      assert config.enabled == false
      assert config.auto_renew == false
      assert config.provider == nil
      assert config.domains == []
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end
  end

  describe "requires_ssl?" do
    test "returns true for tenant with custom domain when SSL enabled" do
      Application.put_env(:mcp, :ssl_enabled, true)

      assert SSLManager.requires_ssl?(@sample_tenant) == true
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end

    test "returns false for tenant without custom domain when SSL enabled and ssl_for_subdomains is false" do
      Application.put_env(:mcp, :ssl_enabled, true)
      Application.put_env(:mcp, :ssl_for_subdomains, false)

      assert SSLManager.requires_ssl?(@tenant_without_custom_domain) == false
    after
      Application.put_env(:mcp, :ssl_enabled, false)
      Application.put_env(:mcp, :ssl_for_subdomains, false)
    end

    test "returns true for subdomain when SSL enabled and ssl_for_subdomains is true" do
      Application.put_env(:mcp, :ssl_enabled, true)
      Application.put_env(:mcp, :ssl_for_subdomains, true)

      assert SSLManager.requires_ssl?(@tenant_without_custom_domain) == true
    after
      Application.put_env(:mcp, :ssl_enabled, false)
      Application.put_env(:mcp, :ssl_for_subdomains, false)
    end

    test "returns false when SSL is disabled" do
      Application.put_env(:mcp, :ssl_enabled, false)

      assert SSLManager.requires_ssl?(@sample_tenant) == false
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end
  end

  describe "validate_custom_domain" do
    test "validates proper domain format" do
      assert SSLManager.validate_custom_domain("example.com") == :ok
      assert SSLManager.validate_custom_domain("sub.example.com") == :ok
      assert SSLManager.validate_custom_domain("test-company.co.uk") == :ok
    end

    test "rejects invalid domain formats" do
      assert SSLManager.validate_custom_domain("invalid..domain") == {:error, :invalid_format}
      assert SSLManager.validate_custom_domain(".leadingdot.com") == {:error, :invalid_format}
      assert SSLManager.validate_custom_domain("trailingdot.") == {:error, :invalid_format}
      assert SSLManager.validate_custom_domain("") == {:error, :invalid_format}
      assert SSLManager.validate_custom_domain(nil) == {:error, :invalid_domain}
      assert SSLManager.validate_custom_domain(123) == {:error, :invalid_domain}
    end

    test "checks DNS resolution" do
      # Test with a known non-existent domain
      if Application.get_env(:mcp, :skip_dns_check) do
        assert SSLManager.validate_custom_domain("this-domain-does-not-exist-12345.com") == :ok
      else
        assert SSLManager.validate_custom_domain("this-domain-does-not-exist-12345.com") ==
                 {:error, :dns_not_resolved}
      end
    end
  end

  describe "generate_ssl_challenge" do
    test "generates challenge with proper structure" do
      challenge = SSLManager.generate_ssl_challenge("example.com")

      assert challenge.domain == "example.com"
      assert is_binary(challenge.challenge_token)
      assert String.starts_with?(challenge.challenge_file, ".well-known/acme-challenge/")
      assert is_binary(challenge.content)
      assert %DateTime{} = challenge.expires_at
    end
  end

  describe "setup_ssl_certificate" do
    test "sets up certificate for tenant requiring SSL" do
      Application.put_env(:mcp, :ssl_enabled, true)

      result = SSLManager.setup_ssl_certificate(@sample_tenant)

      assert {:ok, config} = result
      assert config.status == :pending_setup
      assert "test.localhost" in config.domains
      assert "test-company.com" in config.domains
      assert config.auto_renew == true
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end

    test "returns not_required for tenant not requiring SSL" do
      Application.put_env(:mcp, :ssl_enabled, false)

      result = SSLManager.setup_ssl_certificate(@sample_tenant)

      assert {:ok, config} = result
      assert config.status == :not_required
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end

    test "validates custom domain before setup" do
      Application.put_env(:mcp, :ssl_enabled, true)

      result = SSLManager.setup_ssl_certificate(@sample_tenant)

      # Since test-company.com is a valid format but may not resolve DNS,
      # we expect either success or DNS error, not format error
      case result do
        {:ok, _config} -> :ok
        {:error, :dns_not_resolved} -> :ok
        other -> flunk("Expected {:ok, _} or {:error, :dns_not_resolved}, got: #{inspect(other)}")
      end
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end
  end

  describe "get_certificate_status" do
    test "returns not_required status when SSL not required" do
      Application.put_env(:mcp, :ssl_enabled, false)

      status = SSLManager.get_certificate_status(@sample_tenant)
      assert status.status == :not_required
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end

    test "returns no_custom_domain status for tenant without custom domain" do
      Application.put_env(:mcp, :ssl_enabled, true)
      Application.put_env(:mcp, :ssl_for_subdomains, true)

      status = SSLManager.get_certificate_status(@tenant_without_custom_domain)
      assert status.status == :no_custom_domain
      assert "basic.localhost" in status.domains
    after
      Application.put_env(:mcp, :ssl_enabled, false)
      Application.put_env(:mcp, :ssl_for_subdomains, false)
    end

    test "returns unknown status for tenant with custom domain" do
      Application.put_env(:mcp, :ssl_enabled, true)

      status = SSLManager.get_certificate_status(@sample_tenant)
      assert status.status == :unknown
      assert "test.localhost" in status.domains
      assert "test-company.com" in status.domains
      assert status.auto_renew == true
    after
      Application.put_env(:mcp, :ssl_enabled, false)
    end
  end
end
