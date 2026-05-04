-- Add timezone to device_tokens so the notification cron can send at the
-- correct local time per user instead of a fixed UTC hour.

ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';

-- Replace the old once-daily cron with an hourly cron.
-- The edge function now filters users whose local 20:00 matches current UTC hour.
SELECT cron.unschedule('send-daily-notifications');

SELECT cron.schedule(
    'send-daily-notifications',
    '0 * * * *',
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
