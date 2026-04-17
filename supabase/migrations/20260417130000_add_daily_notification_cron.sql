-- Daily cron job to send personalized push notifications via FCM.
-- Fires every day at 08:00 UTC. Adjust the schedule as needed.
-- Requires pg_cron and pg_net extensions (enabled by default on Supabase).

SELECT cron.schedule(
    'send-daily-notifications',
    '0 8 * * *',
    $$
    SELECT net.http_post(
        url    := (SELECT value FROM vault.secrets WHERE name = 'supabase_url') || '/functions/v1/send-daily-notifications',
        body   := '{}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || (SELECT value FROM vault.secrets WHERE name = 'supabase_service_role_key'),
            'x-supabase-cron', '1'
        )
    );
    $$
);
