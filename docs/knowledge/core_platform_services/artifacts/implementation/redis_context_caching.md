# Redis Context Caching

Performance optimization for high-traffic subdomain and routing resolution.

## 1. Architectural Decision
The platform uses **Redis** rather than node-local ETS for context caching to ensure cluster-wide consistency. In a multi-node environment, routing changes (e.g., tenant revocation or custom domain updates) must be reflected across all nodes simultaneously. A centralized Redis cache ensures invalidations are global.

## 2. Implementation: `ContextPlug`
The `McpWeb.Plugs.ContextPlug` intercepts every request to resolve the organization.

- **Key**: `routing:{hostname}` (e.g., `routing:acme.localhost`)
- **TTL**: 300 seconds (5 minutes).
- **Serialization**: uses `:erlang.term_to_binary/1` to preserve complex structs and composite types.

## 3. Logic Flow
1. **Extract Host**: Extract `host` from `conn`.
2. **Global Cache Check**: Attempt hit on Redis.
3. **Hit**: Rehydrate assigns and Ash context.
4. **Miss**: Execute full regex and DB resolution (`by_subdomain`). Cache the success.
5. **Divergence**: proceed with 404 if no entity is found.

## 4. Performance
Caches avoid repeating OID resolution for PostgreSQL custom types and eliminate database bottleneck for high-frequency subdomain lookups.
