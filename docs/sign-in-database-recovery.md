# Sign-in outage: 7 November 2026

## Verified cause

The live API health endpoint returned HTTP **503**, `database: disconnected`.
A single read-only `SELECT 1` against the configured database failed with:

> This cluster has reached its Request Unit limit for the month and is now disabled.

The provider also reported that the maximum allowed connections was **0**.
No customer password was tested or changed. No production data was modified.

## Required recovery in the provider account

1. Sign in to the [CockroachDB Cloud Console](https://cockroachlabs.cloud/).
2. Select the FastStore/Ram Prasad cluster hosting the `ram_prasad_store` database.
3. Check its Request Unit consumption and resource/spending limits. Restore the cluster by increasing the exhausted limit if you approve the account's associated charges. Use the console's current billing information; this is an account setting, not an app or SQL setting.
4. Wait for the cluster to accept connections again, then check the [API health endpoint](https://ram-prasad-kirana-backend.onrender.com/api/v1/health). It should return HTTP 200 with `database: connected`.
5. Retry signing in. This outage does not require reinstalling FastStore or resetting a customer password. If a different error remains after connectivity returns, investigate that error separately.

For a spending-capped cluster, the alternative may be to wait for its next billing-cycle allowance. Check the actual cycle in your account; no reset date has been assumed. The database remains unavailable meanwhile.

Cockroach Labs' [operations guide](https://github.com/cockroachlabs/cockroachdb-skills/blob/main/skills/cockroachdb-operations-and-lifecycle/reviewing-cluster-health/SKILL.md) describes checking RU consumption, remaining budget and spending limits in the Cloud Console. Its [Cloud API guide](https://www.cockroachlabs.com/blog/cockroachdb-cloud-api/) documents changing resource limits. No paid setting was changed automatically.

## Code changes and validation

- [Database availability classification](../backend/src/services/database-availability.ts) distinguishes the provider's usage-limit error from ordinary connection failures and credential failures.
- [Login and health](../backend/src/server.ts) now report a safe HTTP 503 with `DATABASE_USAGE_LIMIT` or `DATABASE_UNAVAILABLE`, without exposing SQL or connection strings.
- [Admin errors](../backend/src/middleware/auth.ts) use the same classification.
- The client already displays the backend error, so a new app install is not required for this message change. Deploy the backend patch for the improved message; restoring the provider limit is required independently.
- [Regression tests](../backend/tests/database-availability.test.ts), the complete isolated backend suite and TypeScript compilation passed. Invalid credentials remain separate from database outages; no authentication bypass was added.
- After the backend build, `npm run db:check` performs one read-only availability check without printing connection credentials.

## Current limitation

The account owner must restore the database resource limit. The live sign-in flow cannot be verified successfully while the provider refuses all connections. Code changes alone cannot enable a provider-disabled cluster.
