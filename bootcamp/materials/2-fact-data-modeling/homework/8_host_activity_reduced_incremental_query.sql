WITH daily_activity AS (
    SELECT 
        host,
        DATE_TRUNC('day', CAST(event_time AS TIMESTAMP)) AS activity_date,
        DATE_TRUNC('month', CAST(event_time AS TIMESTAMP)) AS activity_month,
        COUNT(1) AS daily_hits,
        COUNT(DISTINCT user_id) AS daily_unique_visitors
    FROM events
    WHERE DATE_TRUNC('day', CAST(event_time AS TIMESTAMP)) = DATE('{{ ds }}')
    AND host IS NOT NULL
    GROUP BY host, DATE_TRUNC('day', CAST(event_time AS TIMESTAMP)), DATE_TRUNC('month', CAST(event_time AS TIMESTAMP))
),
existing_monthly AS (
    SELECT * FROM host_activity_reduced
    WHERE month = DATE_TRUNC('month', DATE('{{ ds }}'))
)

INSERT INTO host_activity_reduced (month, host, hit_array, unique_visitors_array)
SELECT
    da.activity_month AS month,
    da.host,
    CASE 
        WHEN em.hit_array IS NULL THEN ARRAY[da.daily_hits]
        ELSE em.hit_array || da.daily_hits
    END AS hit_array,
    CASE 
        WHEN em.unique_visitors_array IS NULL THEN ARRAY[da.daily_unique_visitors]
        ELSE em.unique_visitors_array || da.daily_unique_visitors
    END AS unique_visitors_array
FROM daily_activity da
LEFT JOIN existing_monthly em ON da.host = em.host AND da.activity_month = em.month
ON CONFLICT (month, host) DO UPDATE SET
    hit_array = EXCLUDED.hit_array,
    unique_visitors_array = EXCLUDED.unique_visitors_array;
