# Turso migration validation — 2026-11-07

## Completed checks

| Check | Actual result |
|---|---|
| Prisma schema generation | Passed on existing Prisma 5.22 |
| Staging schema generation | 54 models, 16 enums |
| Migration-tool tests | 7 passed, 0 failed |
| Synthetic import | One complete record for each of all 54 models imported and verified locally |
| Exact values | Large Decimal strings, BigInt above 2^53, binary fields, JSON, hashes and UTC microseconds preserved |
| Referential integrity | Foreign keys checked; invalid references rejected |
| Atomic import | Invalid foreign key rolls back all DDL and records |
| Retry | Identical snapshot verified again without duplicates |
| Existing data protection | Nonempty unrelated target refused and existing row preserved |
| Damaged export | Hash mismatch and incomplete manifest rejected |
| Backend TypeScript build | Passed |
| Existing complete backend npm test / pretest | Passed, exit 0; primarily isolated/mocked service and API fixtures |
| Read-only CockroachDB connection | Passed after the request-unit limit was increased |
| Current CockroachDB export | Completed: 54 source tables, 583 records, SHA256-verified files |
| Source schema state | `PosCataloguePriceChange` is an unapplied local migration; it was explicitly recorded as absent and created empty in staging |
| Local Turso-compatible staging import | Completed and verified: SQLite integrity `ok`, 0 foreign-key violations, 55 tables including the import marker |

Tests use synthetic data in isolated in-memory libSQL databases and remove their
temporary fixtures afterward. None of these tests wrote to the real source,
Turso Cloud, the store's Windows files or business records. Expected failure-path
logs for mail and corrupt image fixtures appeared in the existing backend suite.

## Not completed or verified

- No Turso Cloud credentials were configured/used by these checks.
- No remote upload, cloud verification or real Turso connection test.
- The staging import validates every exported record by primary key, typed
  canonical digest and count. It does not yet compare the finished application
  runtime behaviour or every financial aggregate on the target provider.
- No application runtime switch: Prisma provider, raw stock SQL, Decimal storage
  semantics and application sequence allocation still require conversion.
- No application registration, cart, order, POS, delivery or report workflow has
  been tested against Turso. Existing backend fixtures are not evidence of this.
- No deployment, production cutover or Flutter compatibility change.

The full migration is **not production-ready**. Keep the current runtime and
historical migrations intact. Follow the gates in the
[migration plan](turso-migration-plan.md) and
[tool instructions](../backend/database-migration/README.md).
