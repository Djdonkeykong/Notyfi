-- Fix missing INSERT RLS policy on public.users.
-- UPSERT (INSERT ON CONFLICT DO UPDATE) requires INSERT privilege in Postgres
-- regardless of whether a conflict occurs. Without this policy every
-- upsertUserProfile / upsertProfilePreferences call returned 403, causing
-- the onboarding bootstrap to fail silently and write nothing to the DB.
CREATE POLICY "Users can insert own record"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK ((SELECT auth.uid()) = id);

-- Remove the DEFAULT 'USD' and NOT NULL constraint on currency_code.
-- The trigger (handle_new_user) only sets id/email/display_name.
-- With DEFAULT 'USD' the new row had currency_code != null immediately,
-- making hasServerData = true in CloudSyncManager and risking an incorrect
-- skip of the onboarding bootstrap push in edge cases.
-- Existing rows keep their current values; new rows get NULL until the app
-- writes the real currency during bootstrap.
ALTER TABLE public.users
    ALTER COLUMN currency_code DROP NOT NULL,
    ALTER COLUMN currency_code DROP DEFAULT;
