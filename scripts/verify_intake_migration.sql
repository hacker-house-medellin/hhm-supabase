\set ON_ERROR_STOP on

DO $verify$
DECLARE
  hhm_table_count integer;
  protected_table_count integer;
  service_policy_count integer;
  leaked_grant_count integer;
  points_balance bigint;
  points_earned bigint;
  points_redeemed bigint;
  points_version bigint;
  points_account_id uuid;
  application_fence_columns integer;
  application_placement_columns integer;
  application_placement_constraints integer;
BEGIN
  SELECT count(*)
  INTO hhm_table_count
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename LIKE 'hhm_%';

  IF hhm_table_count <> 7 THEN
    RAISE EXCEPTION 'expected 7 HHaus tables, found %', hhm_table_count;
  END IF;

  SELECT count(*)
  INTO protected_table_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname LIKE 'hhm_%'
    AND c.relkind = 'r'
    AND c.relrowsecurity
    AND c.relforcerowsecurity;

  IF protected_table_count <> 7 THEN
    RAISE EXCEPTION 'expected 7 forced-RLS tables, found %', protected_table_count;
  END IF;

  SELECT count(*)
  INTO application_fence_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'hhm_applications'
    AND column_name IN ('status_version', 'last_admin_operation_id');

  IF application_fence_columns <> 2 THEN
    RAISE EXCEPTION 'application admin-transition fence columns are missing';
  END IF;

  SELECT count(*)
  INTO application_placement_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'hhm_applications'
    AND column_name IN (
      'allergy_notes',
      'noise_sensitivity',
      'light_sensitivity',
      'room_preference_notes',
      'roommate_preference',
      'preferred_room_occupancy',
      'roommate_for_lower_cost',
      'roommate_for_social_connection',
      'accommodation_data_consent'
    );

  SELECT count(*)
  INTO application_placement_constraints
  FROM pg_constraint
  WHERE conrelid = 'public.hhm_applications'::regclass
    AND conname IN (
      'hhm_applications_noise_sensitivity',
      'hhm_applications_light_sensitivity',
      'hhm_applications_roommate_preference',
      'hhm_applications_room_occupancy',
      'hhm_applications_accommodation_consent'
    );

  IF application_placement_columns <> 9 OR application_placement_constraints <> 5 THEN
    RAISE EXCEPTION 'application placement columns or constraints are missing';
  END IF;

  SELECT count(*)
  INTO service_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename LIKE 'hhm_%'
    AND roles = ARRAY['service_role']::name[]
    AND cmd = 'ALL'
    AND qual = 'true'
    AND with_check = 'true';

  IF service_policy_count <> 7 THEN
    RAISE EXCEPTION 'expected 7 service-role-only policies, found %',
      service_policy_count;
  END IF;

  SELECT count(*)
  INTO leaked_grant_count
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public'
    AND table_name LIKE 'hhm_%'
    AND grantee IN ('anon', 'authenticated');

  IF leaked_grant_count <> 0 THEN
    RAISE EXCEPTION 'browser roles retained % HHaus table grants',
      leaked_grant_count;
  END IF;

  IF has_function_privilege(
    'anon',
    'public.hhm_apply_points_ledger_entry()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon can execute the points trigger function';
  END IF;

  IF has_function_privilege(
    'authenticated',
    'public.hhm_touch_updated_at()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated can execute an internal trigger function';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM storage.buckets
    WHERE id = 'hhm-intake-private'
      AND name = 'hhm-intake-private'
      AND public = false
      AND file_size_limit = 10485760
      AND allowed_mime_types = ARRAY[
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'image/jpeg',
        'image/png',
        'image/heic'
      ]::text[]
  ) THEN
    RAISE EXCEPTION 'private intake bucket contract is absent or unsafe';
  END IF;

  -- Apply entries in separate statements: the ledger contract is ordered, and
  -- SQL does not promise row-trigger execution order for a multi-row VALUES.
  INSERT INTO public.hhm_user_points_ledger (
    idempotency_key,
    subject,
    delta,
    reason_code,
    actor_subject
  )
  VALUES ('verify-award', 'subject-1', 100, 'verification_award', 'admin-1');

  INSERT INTO public.hhm_user_points_ledger (
    idempotency_key,
    subject,
    delta,
    reason_code,
    actor_subject
  )
  VALUES ('verify-redeem', 'subject-1', -25, 'verification_redeem', 'admin-1');

  SELECT id, balance, lifetime_earned, lifetime_redeemed, version
  INTO points_account_id, points_balance, points_earned, points_redeemed, points_version
  FROM public.hhm_user_points_accounts
  WHERE subject = 'subject-1';

  IF points_account_id IS NULL OR (points_balance, points_earned, points_redeemed, points_version)
    <> (75::bigint, 100::bigint, 25::bigint, 2::bigint) THEN
    RAISE EXCEPTION 'points projection is inconsistent';
  END IF;

  BEGIN
    INSERT INTO public.hhm_user_points_ledger (
      idempotency_key,
      subject,
      delta,
      reason_code,
      actor_subject
    )
    VALUES (
      'verify-overdraw',
      'subject-1',
      -100,
      'verification_overdraw',
      'admin-1'
    );
    RAISE EXCEPTION 'negative points balance was accepted';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;

  BEGIN
    UPDATE public.hhm_user_points_ledger
    SET reason_code = 'verification_mutated'
    WHERE idempotency_key = 'verify-award';
    RAISE EXCEPTION 'immutable ledger update was accepted';
  EXCEPTION
    WHEN object_not_in_prerequisite_state THEN
      NULL;
  END;
END
$verify$;

SELECT 'HHaus Supabase intake migration verified' AS result;
