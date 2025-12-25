[
  # Known Dialyzer warnings to ignore
  # This file helps reduce noise while maintaining type safety

  # GDPR controller - defensive catchall for cancel_user_deletion
  {"lib/mcp_web/controllers/gdpr_controller.ex", :pattern_match_cov}
]
