-- Tighten device_tokens RLS policy to authenticated role only.
-- The original policy used the default PUBLIC role. While auth.uid() = NULL
-- already blocks unauthenticated callers in practice, explicitly scoping to
-- authenticated makes the intent clear and follows Supabase best practice.
DROP POLICY IF EXISTS "Users can manage their own device tokens" ON device_tokens;

CREATE POLICY "Users can manage their own device tokens"
    ON device_tokens
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
