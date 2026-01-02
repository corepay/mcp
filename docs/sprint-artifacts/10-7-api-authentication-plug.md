# Story 10.7: API Authentication Plug

## Story
As a developer,
I want API authentication via header,
So that programmatic access works seamlessly.

## Status
review

## Acceptance Criteria

- [x] AC1: Valid API key in `API-Key` header authenticates request
- [x] AC2: conn.assigns.api_key contains key struct after auth
- [x] AC3: conn.assigns.api_actor contains entity (tenant/merchant/reseller)
- [x] AC4: last_used_at timestamp updates on API key usage
- [x] AC5: Usage is logged to api_key_usage_logs
- [x] AC6: Invalid/expired/revoked keys return 401 Unauthorized
- [x] AC7: Missing permissions return 403 Forbidden
- [x] AC8: Rate limiting enforced (1000 req/hour per key)
- [x] AC9: Unit tests cover all authentication scenarios
- [x] AC10: Integration tests verify full API auth flow

## Tasks/Subtasks

### Implementation Tasks
- [x] Task 1: Create ApiAuthPlug
  - [x] 1.1: Extract API-Key header from request
  - [x] 1.2: Hash incoming key and compare to stored hash
  - [x] 1.3: Load associated entity and permissions
  - [x] 1.4: Set actor for Ash framework
- [x] Task 2: Implement key validation
  - [x] 2.1: Check key exists in database
  - [x] 2.2: Check key is not expired
  - [x] 2.3: Check key is not revoked
  - [x] 2.4: Check entity is active
- [x] Task 3: Implement usage tracking
  - [x] 3.1: Update last_used_at timestamp
  - [x] 3.2: Log usage to api_key_usage_logs (async via Oban)
- [x] Task 4: Implement rate limiting
  - [x] 4.1: Check rate limit in Redis
  - [x] 4.2: Return 429 Too Many Requests when exceeded
  - [x] 4.3: Include Retry-After header
- [x] Task 5: Add to router pipeline
  - [x] 5.1: Create :api pipeline with ApiAuthPlug
  - [x] 5.2: Apply to API routes
- [x] Task 6: Write tests (TDD)
  - [x] 6.1: Unit tests for ApiAuthPlug
  - [x] 6.2: Integration tests for API authentication
  - [x] 6.3: Rate limiting tests
  - [x] 6.4: Error handling tests

## Dev Notes

### Technical Context
- ApiKey resource exists at `lib/mcp/platform/api_key.ex`
- Keys have prefixes: dev_ak_, merch_ak_, res_ak_
- Keys are hashed with bcrypt before storage
- Redis available for rate limiting

### API Response Format
```json
// Success: Request proceeds with assigns set
// Error 401:
{"error": {"code": "invalid_api_key", "message": "Invalid or expired API key"}}
// Error 403:
{"error": {"code": "insufficient_permissions", "message": "API key lacks required permission"}}
// Error 429:
{"error": {"code": "rate_limit_exceeded", "message": "Rate limit exceeded"}}
```

### Rate Limiting
- 1000 requests per hour per API key
- Use Redis INCR with TTL
- Key format: `rate_limit:{api_key_id}:{hour_bucket}`

## Dev Agent Record

### Debug Log
<!-- Implementation notes go here -->

### Completion Notes
<!-- Summary upon completion -->

## File List
<!-- Files created/modified/deleted -->

## Change Log
| Date | Change | Author |
|------|--------|--------|
| 2026-01-01 | Story created | BMad |
