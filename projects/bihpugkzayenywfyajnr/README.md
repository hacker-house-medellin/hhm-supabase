# hhaus-project

Supabase project reference: `bihpugkzayenywfyajnr`

The GitHub integration working directory is `projects/bihpugkzayenywfyajnr`. The nested `supabase/` directory is the provider deploy tree. This target is scaffolded as `planned`; do not enable production deployment until `target.json` passes the baseline and connection gates.

The reviewed intake provider migration is
`supabase/migrations/20260830000100_hhm_intake.sql`. It is derived from the
cross-database `hhm-lib-core` declarative schema and adds Supabase-only
service-role grants, explicit browser-role revocations, service-only RLS
policies, and the private bounded upload bucket.

Read-only hosted-project evidence is recorded in
`../../docs/provider-preflight-2026-08-30.md`. That preflight deliberately
does not change the target's `planned` state or bypass the required
`supabase db pull` and provider-preview gates.
