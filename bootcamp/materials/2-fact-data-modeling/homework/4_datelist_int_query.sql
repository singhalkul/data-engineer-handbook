CREATE TABLE IF NOT EXISTS user_devices_datelist_int (
    user_id numeric,
    browser_type TEXT,
    datelist_int BIT(32),
    date DATE,
    PRIMARY KEY (user_id, browser_type, date)
);



WITH date_series AS (
    SELECT generate_series(DATE('2023-01-01'), DATE('2023-01-31'), INTERVAL '1 day') AS valid_date
),
starter AS (
    SELECT 
        udc.user_id,
        udc.browser_type,
        udc.device_activity_datelist @> ARRAY[DATE(ds.valid_date)] AS is_active,
        EXTRACT(DAY FROM DATE('2023-01-31') - ds.valid_date) AS days_since
    FROM user_devices_cumulated udc
    CROSS JOIN date_series ds
    WHERE udc.date = DATE('2023-01-31')
),
bits AS (
    SELECT 
        user_id,
        browser_type,
        SUM(
            CASE 
                WHEN is_active THEN POW(2, 32 - days_since)
                ELSE 0 
            END
        )::bigint::bit(32) AS datelist_int,
        DATE('2023-01-31') as date
    FROM starter
    GROUP BY user_id, browser_type
)

INSERT INTO user_devices_datelist_int
SELECT 
    user_id,
    browser_type,
    datelist_int,
    date
FROM bits;

