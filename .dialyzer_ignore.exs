[
  # Known Dialyzer warnings to ignore
  # This file helps reduce noise while maintaining type safety

  # Ecto and Phoenix-related warnings (common and usually safe)
  {"lib/mcp_web/endpoint.ex", :no_match},
  {"lib/mcp_web/telemetry.ex", :no_match},
  {"lib/mcp_web/router.ex", :no_match},

  # Test-related warnings (test utilities often trigger false positives)
  {"test/", :no_match},

  # Migrations (Ecto migrations often trigger warnings)
  {"priv/repo/migrations/", :no_match}
]
