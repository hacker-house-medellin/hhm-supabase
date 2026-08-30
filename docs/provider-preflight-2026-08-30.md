# HHaus provider preflight — 2026-08-30

This is bounded read-only evidence, not a substitute for the required
`supabase db pull` baseline or a production deployment approval.

The authenticated Supabase dashboard was opened for the exact production
project `bihpugkzayenywfyajnr` and queried through its SQL editor:

- PostgreSQL reports version `17.6.1.166` in `us-east-1`.
- The `public` schema contains no product table or view.
- No table whose name starts with `hhm_` exists.
- No `hhm-intake-private` Storage bucket exists.
- The only `public` function is the platform-managed
  `rls_auto_enable()` event-trigger function. It is owned by `postgres`,
  uses a fixed `pg_catalog` search path, and enables RLS for new public
  tables.

The provider target remains `planned`, its baseline remains `pending`, and
production deployment remains disabled. The intake migration must first pass
review, exact-head CI, a pinned-CLI `supabase db pull` comparison, provider
preview, and the production read-back sequence in
`docs/github-integration.md`.

