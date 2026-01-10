# OLA (Online Application) Documentation

**Last Updated**: January 2, 2026

This directory contains comprehensive documentation for the OLA (Online Application) merchant onboarding portal.

---

## Quick Links

| Document | Purpose | Audience |
|----------|---------|----------|
| **[Implementation Status](./ola_implementation_status.md)** | Current state, architecture, features | Developers, Product |
| **[Enhancement Roadmap](./ola_enhancement_roadmap.md)** | Planned features, priorities, timelines | Product, Engineering Leads |
| **[Underwriting Integration](./ola_underwriting_integration.md)** | Integration details, data flow, APIs | Developers, Architects |

---

## What is OLA?

OLA is an **AI-powered merchant onboarding portal** that enables merchants to apply for accounts through an intuitive multi-step wizard with real-time AI guidance from Atlas, an AI concierge.

**Key Features**:
- Multi-step application wizard (business info, owners, documents, review)
- Atlas AI assistant (contextual help, proactive guidance)
- Document intelligence (OCR, validation, autofill)
- Magic Camera (QR code mobile handoff)
- Save & Resume (magic links)
- Real-time status tracking ("Pizza Tracker")

**Current Status**: ✅ Phase 1 Complete, Production Ready

---

## Getting Started

### For Developers

**First Time Setup**:
1. Read [Implementation Status](./ola_implementation_status.md) → "Current Implementation"
2. Review [Underwriting Integration](./ola_underwriting_integration.md) → "Shared Resources"
3. Check environment variables and configuration
4. Run tests: `mix test test/mcp_web/live/ola/`

**Making Changes**:
1. Review [Enhancement Roadmap](./ola_enhancement_roadmap.md) for planned work
2. Check if your feature aligns with roadmap priorities
3. Follow architectural patterns from existing code
4. Add tests for new features
5. Update documentation

### For Product Managers

**Understanding OLA**:
1. Start with [Implementation Status](./ola_implementation_status.md) → "Executive Summary"
2. Review current features and capabilities
3. Check [Enhancement Roadmap](./ola_enhancement_roadmap.md) for priorities
4. Review success metrics and targets

**Planning Features**:
1. Check roadmap for alignment
2. Review technical debt and limitations
3. Coordinate with engineering on resource needs
4. Define success criteria and metrics

### For Business Stakeholders

**Business Value**:
- Faster merchant onboarding (target: < 5 minutes)
- Reduced manual review burden (target: 70% auto-approval)
- Superior UX with AI guidance
- Zero-entry applications via document intelligence

**Key Metrics**:
- Application completion rate
- Average time to complete
- Auto-approval rate
- Customer satisfaction

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  OLA Portal                     │
│  Multi-step wizard + Atlas AI sidebar          │
└───────────────────┬─────────────────────────────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
┌─────────────────┐  ┌─────────────────────┐
│   Atlas AI      │  │ Document Intel      │
│ (Contextual     │  │ (TheEye OCR +       │
│  Assistance)    │  │  Validation)        │
└─────────────────┘  └─────────────────────┘
         │                     │
         └──────────┬──────────┘
                    ▼
┌─────────────────────────────────────────────────┐
│          Underwriting Platform                  │
│  • KYC/KYB Verification                         │
│  • Risk Assessment                              │
│  • Status Management                            │
└─────────────────────────────────────────────────┘
```

**See**: [Underwriting Integration](./ola_underwriting_integration.md) for detailed data flow

---

## Key Files

### Frontend (LiveView)
- **Application Wizard**: `lib/mcp_web/live/ola/application_live.ex` (507 lines)
- **Registration**: `lib/mcp_web/live/ola/registration_live.ex` (65 lines)
- **Status Tracker**: `lib/mcp_web/live/ola/status_live.ex` (76 lines)
- **Atlas Chat**: `lib/mcp_web/live/ola/components/atlas_chat.ex` (193 lines)

### Backend (Atlas AI)
- **Agent**: `lib/mcp/underwriting/atlas/agent.ex` (469 lines)
- **Context**: `lib/mcp/underwriting/atlas/conversation_context.ex` (97 lines)
- **Hints**: `lib/mcp/underwriting/atlas/context_hints.ex` (145 lines)

### Services
- **Magic Link**: `lib/mcp/underwriting/services/magic_link.ex` (63 lines)
- **Magic Camera**: `lib/mcp/underwriting/services/magic_camera.ex` (156 lines)
- **Document Validator**: `lib/mcp/underwriting/services/document_validator.ex` (183 lines)
- **Document Autofill**: `lib/mcp/underwriting/services/document_autofill.ex` (107 lines)
- **TheEye Client**: `lib/mcp/underwriting/services/the_eye.ex` (147 lines)

**Total**: ~2,900 lines of production code

---

## Integration Points

### Underwriting Platform (Fully Integrated ✅)

**Shared Resources**:
- `Application` - OLA creates, Underwriting processes
- `Client` - Owner information
- `Document` - File storage and validation
- `Check` - Verification results
- `Activity` - Audit trail

**Key Integration**: `Gateway.screen_application/2`
- Triggered on application submission
- Runs KYC, KYB, watchlist screening
- Calculates risk score
- Updates application status

**Real-Time Updates**: Phoenix PubSub
- Status changes broadcast
- OLA Status Tracker subscribes
- Live "Pizza Tracker" updates

**See**: [Underwriting Integration](./ola_underwriting_integration.md) for complete details

---

## Current Limitations

### Technical Debt
1. **Atlas AI (Mock Mode)** - Pattern matching only, LLM integration stubbed
2. **Magic Camera (ETS)** - In-memory, not multi-node safe
3. **Test Coverage** - Sparse, needs comprehensive tests
4. **Error Handling** - Basic, needs user-friendly messages
5. **Mobile UX** - Desktop-first, Atlas hidden on mobile

**See**: [Implementation Status](./ola_implementation_status.md) → "Known Limitations"

---

## Enhancement Roadmap

### Phase 2A: Production Hardening (Q1 2026) - CRITICAL
- Comprehensive test suite
- Redis-backed sessions
- Error handling improvements
- Monitoring and observability

### Phase 2B: AI Enhancement (Q2 2026) - HIGH VALUE
- Live Atlas with LLM
- RAG integration
- Multi-language support

### Phase 2C: Document Intelligence (Q2-Q3 2026) - HIGH VALUE
- ML-powered field extraction
- Expanded document types
- Real-time quality feedback

### Phase 2D: UX Improvements (Q3 2026) - MEDIUM
- Mobile optimization
- Progressive disclosure
- Auto-save
- Accessibility (WCAG 2.1 AA)

### Phase 2E: Advanced Features (Q4 2026) - LOW
- Video KYC
- Bulk processing
- Industry templates
- Partner API

**See**: [Enhancement Roadmap](./ola_enhancement_roadmap.md) for complete details

---

## Success Metrics

### Targets (6 months)
- **Application Completion Rate**: 85% (baseline: 60%)
- **Average Time to Complete**: < 5 minutes (baseline: 15 minutes)
- **Document Upload Success**: 95% (baseline: 85%)
- **Auto-Approval Rate**: 70% (baseline: N/A)
- **Support Tickets**: < 5% of applications

---

## Configuration

### Environment Variables (Required)
```bash
# Document Intelligence
THE_EYE_URL=http://localhost:48291

# Underwriting Vendors
COMPLY_CUBE_API_KEY=xxx
COMPLY_CUBE_API_SECRET=xxx
IDENFY_API_KEY=xxx
IDENFY_API_SECRET=xxx

# LLM (Future)
OLLAMA_PORT=11434
OLLAMA_MODEL=llama3
OPENROUTER_API_KEY=xxx
```

### Application Config
```elixir
# config/config.exs
config :mcp, :underwriting_adapter, :mock  # or :complycube, :idenfy
config :mcp, :agent_runner_adapter, :mock  # or :live

config :mcp, :uploads,
  bucket: "underwriting-documents"
```

---

## Testing

### Run OLA Tests
```bash
# All OLA tests
mix test test/mcp_web/live/ola/

# Specific test
mix test test/mcp_web/live/ola/components/atlas_chat_test.exs
```

### Run Integration Tests
```bash
# Underwriting integration (includes Gateway)
mix test test/mcp/underwriting/

# All tests
mix test
```

---

## Deployment

### Prerequisites
- PostgreSQL with extensions (PostGIS, pgvector)
- MinIO or S3 for document storage
- TheEye service running
- Vendor API keys configured

### Deployment Checklist
- [ ] Environment variables configured
- [ ] S3 bucket created and accessible
- [ ] TheEye service healthy
- [ ] Vendor API keys valid
- [ ] Multi-tenancy tested
- [ ] Smoke tests passed

**See**: [Implementation Status](./ola_implementation_status.md) → "Deployment Checklist"

---

## Support

### Documentation
- **Architecture**: [Implementation Status](./ola_implementation_status.md)
- **Features**: [Enhancement Roadmap](./ola_enhancement_roadmap.md)
- **Integration**: [Underwriting Integration](./ola_underwriting_integration.md)
- **API Reference**: `docs/features/underwriting/api-reference.md`
- **Developer Guide**: `docs/features/underwriting/developer-guide.md`

### Getting Help
- **Technical Issues**: Check Activity logs, application logs
- **Integration Questions**: Review Underwriting Integration doc
- **Feature Requests**: Check Enhancement Roadmap for planned work

---

## Contributing

### Adding Features
1. Check [Enhancement Roadmap](./ola_enhancement_roadmap.md) for alignment
2. Review architecture in [Implementation Status](./ola_implementation_status.md)
3. Follow existing patterns in codebase
4. Add comprehensive tests
5. Update documentation

### Fixing Bugs
1. Write failing test first (TDD)
2. Fix the bug
3. Verify all tests pass
4. Update documentation if needed

### Code Standards
- Follow Phoenix/Elixir conventions
- Use Ash Framework patterns
- Maintain multi-tenancy (always pass `tenant:`)
- Add telemetry events for monitoring
- Include audit trail (Activity records)

---

## Roadmap Status

| Phase | Status | Timeline | Priority |
|-------|--------|----------|----------|
| Phase 1 | ✅ Complete | Completed | - |
| Phase 2A | 📋 Planned | Q1 2026 | CRITICAL |
| Phase 2B | 📋 Planned | Q2 2026 | HIGH |
| Phase 2C | 📋 Planned | Q2-Q3 2026 | HIGH |
| Phase 2D | 📋 Planned | Q3 2026 | MEDIUM |
| Phase 2E | 📋 Planned | Q4 2026 | LOW |

---

## Next Steps

### Immediate (Next 30 days)
1. **Test Coverage**: Add comprehensive integration tests
2. **Redis Migration**: Move Magic Camera sessions to Redis
3. **Error Handling**: Improve user-facing error messages
4. **Monitoring**: Add telemetry and dashboards

### Short-Term (Next 90 days)
1. **Live Atlas**: Integrate LLM for dynamic responses
2. **Document Intelligence**: Enhance field extraction
3. **Mobile UX**: Optimize for mobile devices

### Long-Term (6-12 months)
1. **Advanced AI**: RAG, multi-language, confidence scoring
2. **Zero-Entry**: ML-powered autofill
3. **Video KYC**: Liveness detection
4. **Partner API**: Developer integrations

---

## Questions?

For questions about:
- **Architecture**: See [Implementation Status](./ola_implementation_status.md)
- **Features**: See [Enhancement Roadmap](./ola_enhancement_roadmap.md)
- **Integration**: See [Underwriting Integration](./ola_underwriting_integration.md)
- **Everything else**: Check the features in `docs/features/`

---

**Last Updated**: January 2, 2026
**Documentation Version**: 1.0
**OLA Version**: Phase 1 Complete
