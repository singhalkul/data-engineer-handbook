WITH yesterday AS (
    SELECT * FROM hosts_cumulated
    WHERE date = DATE('{{ ds }}') - INTERVAL '1 day'
),
today AS (
    SELECT 
        host,
        DATE_TRUNC('day', CAST(event_time AS TIMESTAMP)) AS today_date,
        COUNT(1) AS num_events
    FROM events
    WHERE DATE_TRUNC('day', CAST(event_time AS TIMESTAMP)) = DATE('{{ ds }}')
    AND host IS NOT NULL
    GROUP BY host, DATE_TRUNC('day', CAST(event_time AS TIMESTAMP))
)

INSERT INTO hosts_cumulated
SELECT
    COALESCE(t.host, y.host) AS host,
    COALESCE(y.host_activity_datelist, ARRAY[]::DATE[]) ||
    CASE 
        WHEN t.host IS NOT NULL THEN ARRAY[t.today_date]
        ELSE ARRAY[]::DATE[]
    END AS host_activity_datelist,
    COALESCE(t.today_date, y.date + INTERVAL '1 day') AS date
FROM yesterday y
FULL OUTER JOIN today t ON t.host = y.host;
