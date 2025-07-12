INSERT INTO actors_history_scd
WITH streak_started AS (
    SELECT 
        actor,
        actorid,
        current_year,
        quality_class,
        is_active,
        LAG(quality_class, 1) OVER (
            PARTITION BY actorid ORDER BY current_year
        ) <> quality_class
        OR LAG(is_active, 1) OVER (
            PARTITION BY actorid ORDER BY current_year
        ) <> is_active
        OR LAG(quality_class, 1) OVER (
            PARTITION BY actorid ORDER BY current_year
        ) IS NULL
        AS did_change
    FROM actors
),
streak_identified AS (
    SELECT
        actor,
        actorid,
        quality_class,
        is_active,
        current_year,
        SUM(CASE WHEN did_change THEN 1 ELSE 0 END) OVER (
            PARTITION BY actorid ORDER BY current_year
        ) as streak_identifier
    FROM streak_started
),
aggregated AS (
    SELECT
        actor,
        actorid,
        quality_class,
        is_active,
        streak_identifier,
        MIN(current_year) AS start_date,
        MAX(current_year) AS end_date
    FROM streak_identified
    GROUP BY actor, actorid, quality_class, is_active, streak_identifier
)
SELECT 
    actor,
    actorid,
    quality_class,
    is_active,
    start_date,
    end_date,
    end_date as current_year
FROM aggregated;
