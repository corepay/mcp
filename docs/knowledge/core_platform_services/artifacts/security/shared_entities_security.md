# Shared Entities Security

Legacy designs often utilized "Shared Entities" (e.g., global `Address`, `Email`, `Phone` resources) with permissive policies like `policy always() allow`. The platform has refactored these to a **Polymorphic Secure Ownership** model.

## 1. The Vulnerability: Permissive Shared Access
Resources that are shared across tenants (not isolated by schema) must have strict permission checks based on their ephemeral or permanent ownership. Unrestricted access creates a security risk where one tenant could potentially read or modify another's shared entities if their IDs were guessed.

## 2. Remediation: Polymorphic Secure Ownership

### 2.1. Owner Tracking
Shared entities now track their context via `owner_id` and `owner_type` (e.g., `:tenant`, `:user`, `:platform`).

### 2.2. Standardized Policy Helpers
The platform uses centralized helpers (e.g., `Mcp.Platform.Permissions`) to enforce actor checks during resource preparation.
- **Actor Match**: Does the actor have a membership in the tenant that owns this entity?
- **Relationship Match**: Is the actor the specific user who created the entity?

## 3. Database Row-Level Security (RLS)
As a secondary defense-in-depth layer, the platform implements Postgres RLS helpers:
- **`can_access_owner(owner_id, actor_id)`**: A SQL function that checks the actor's memberships and roles against the entity's owner.
- **Selective Enablement**: RLS is typically enabled on high-risk shared tables (`platform_addresses`, `platform_emails`) while internal platform resources remain protected by standard Ash policies.

## 4. Feature Integration (PostGIS)
For geospatial entities (`Address`), the secure model includes automated geocoding via PostGIS. Security checks ensure that geocoding results are only accessible to the entity's owner.
