-- sample query from the lab video

WITH yesterday AS (
    SELECT * FROM users_cumulated
    WHERE date = DATE('2022-12-31')
),
    today AS (
          SELECT cast(user_id as text),
                 DATE_TRUNC('day', CAST(event_time as TIMESTAMP)) AS today_date,
                 COUNT(1) AS num_events FROM events
            WHERE DATE_TRUNC('day', CAST(event_time as TIMESTAMP)) = DATE('2023-01-01')
            AND user_id IS NOT NULL
         GROUP BY user_id,  DATE_TRUNC('day', CAST(event_time as TIMESTAMP))
    )
INSERT INTO users_cumulated
SELECT
       COALESCE(t.user_id, y.user_id),
       COALESCE(y.dates_active,
           ARRAY[]::DATE[])
            || CASE WHEN
                t.user_id IS NOT NULL
                THEN ARRAY[t.today_date]
                ELSE ARRAY[]::DATE[]
                END AS date_list,
       COALESCE(t.today_date, y.date + Interval '1 day') as date
FROm yesterday y
    FULL OUTER JOIN
    today t ON t.user_id = y.user_id;

-- Automated function to populate users_cumulated for a date range

CREATE OR REPLACE FUNCTION populate_users_cumulated_date_range()
RETURNS void AS $$
DECLARE
    current_date_iter DATE;
    previous_date DATE;
    start_date DATE := DATE('2022-12-31');
    end_date DATE := DATE('2023-03-31');
BEGIN
    current_date_iter := start_date + INTERVAL '1 day';
    
    WHILE current_date_iter <= end_date LOOP
        previous_date := current_date_iter - INTERVAL '1 day';        
        WITH yesterday AS (
            SELECT * FROM users_cumulated
            WHERE date = previous_date
        ),
        today AS (
            SELECT cast(user_id as text),
                   DATE_TRUNC('day', CAST(event_time as TIMESTAMP)) AS today_date,
                   COUNT(1) AS num_events FROM events
                WHERE DATE_TRUNC('day', CAST(event_time as TIMESTAMP)) = current_date_iter
                AND user_id IS NOT NULL
             GROUP BY user_id, DATE_TRUNC('day', CAST(event_time as TIMESTAMP))
        )
        INSERT INTO users_cumulated
        SELECT
               COALESCE(t.user_id, y.user_id),
               COALESCE(y.dates_active,
                   ARRAY[]::DATE[])
                    || CASE WHEN
                        t.user_id IS NOT NULL
                        THEN ARRAY[t.today_date]
                        ELSE ARRAY[]::DATE[]
                        END AS date_list,
               COALESCE(t.today_date, y.date + Interval '1 day') as date
        FROM yesterday y
            FULL OUTER JOIN
            today t ON t.user_id = y.user_id;
        
        current_date_iter := current_date_iter + INTERVAL '1 day';
        
        RAISE NOTICE 'Processed date: %', current_date_iter - INTERVAL '1 day';
    END LOOP;
    
    RAISE NOTICE 'Completed populating users_cumulated from % to %', start_date, end_date;
END;
$$ LANGUAGE plpgsql;
SELECT populate_users_cumulated_date_range();
