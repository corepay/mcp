# Tenant Isolation and "Ghost" Table Faults

Diagnostics for multi-tenant state corruption and isolation breaches.

## 1. Ghost Tables/Columns
**Symptom**: An Ash resource fails because of a column that isn't defined in the resource, or a table exists but can't be mapped.
**Cause**: Leftover database artifacts from previous failed migrations or "manual" SQL edits that weren't rolled back.

### Diagnostics
Use `information_schema.columns` to find the truth:
```sql
SELECT column_name, is_nullable, data_type 
FROM information_schema.columns 
WHERE table_name = 'reviews' AND table_schema = 'acq_...';
```

## 2. Sandbox Contention
**Symptom**: `duplicate_table` error in the test environment only.
**Cause**: The test runner is initializing from a `structure.sql` that already contains the table you are trying to create in a migration.

**Resolution**: Force a rebuild by deleting `priv/repo/structure.sql` and performing a `mix ecto.reset`.

## 3. Prefix Mismatch
**Symptom**: `relation "underwriting_documents" does not exist` even after migration.
**Cause**: Attempting to query `public.underwriting_documents` when the table was correctly created in the `platform` or dynamic tenant schema.
**Fix**: Ensure all Repo and Resource calls specify the correct `prefix`.
