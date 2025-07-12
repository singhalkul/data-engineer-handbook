-- Complete Example: How to run the homework solution
-- This script demonstrates the complete workflow

-- Step 1: Create the data types and tables
-- (Run actors_table_ddl.sql and actors_history_scd_ddl.sql first)

-- Step 2: Example of running the cumulative query for multiple years
-- Note: Replace the {current_year} placeholder with actual years

-- Example for year 1970
INSERT INTO actors
WITH last_year AS (
    SELECT * FROM actors 
    WHERE current_year = 1969
),
this_year AS (
    SELECT 
        actor,
        actorid,
        ARRAY_AGG(
            ROW(
                film,
                votes,
                rating,
                filmid
            )::film_stats
        ) as films,
        AVG(rating) as avg_rating,
        1970 as current_year
    FROM actor_films
    WHERE year = 1970
    GROUP BY actor, actorid
)
SELECT 
    COALESCE(ty.actor, ly.actor) as actor,
    COALESCE(ty.actorid, ly.actorid) as actorid,
    CASE 
        WHEN ty.films IS NULL THEN ly.films
        WHEN ly.films IS NULL THEN ty.films
        ELSE ly.films || ty.films
    END as films,
    CASE 
        WHEN ty.avg_rating > 8 THEN 'star'
        WHEN ty.avg_rating > 7 THEN 'good'
        WHEN ty.avg_rating > 6 THEN 'average'
        ELSE 'bad'
    END::quality_class as quality_class,
    CASE 
        WHEN ty.actorid IS NOT NULL THEN TRUE
        ELSE FALSE
    END as is_active,
    1970 as current_year
FROM this_year ty
FULL OUTER JOIN last_year ly
ON ty.actorid = ly.actorid;

-- Step 3: After populating actors table for all years, run the backfill for SCD
-- (Run actors_history_scd_backfill.sql)

-- Step 4: Test queries to verify the solution works

-- Query 1: Check actors table structure
SELECT 
    actor,
    actorid,
    ARRAY_LENGTH(films, 1) as film_count,
    quality_class,
    is_active,
    current_year
FROM actors 
WHERE current_year = 1970
LIMIT 10;

-- Query 2: Examine the films array structure
SELECT 
    actor,
    (films[1]).film as first_film,
    (films[1]).rating as first_film_rating,
    (films[1]).votes as first_film_votes
FROM actors 
WHERE current_year = 1970 
AND ARRAY_LENGTH(films, 1) > 0
LIMIT 5;

-- Query 3: Quality class distribution
SELECT 
    quality_class,
    COUNT(*) as actor_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM actors 
WHERE current_year = 1970
GROUP BY quality_class
ORDER BY actor_count DESC;

-- Query 4: Check SCD table for a specific actor
SELECT 
    actor,
    quality_class,
    is_active,
    start_date,
    end_date,
    (end_date - start_date + 1) as duration_years
FROM actors_history_scd 
WHERE actorid = 'nm0000001'  -- Replace with actual actor ID
ORDER BY start_date;

-- Query 5: Find actors who changed quality class
SELECT 
    actorid,
    actor,
    COUNT(DISTINCT quality_class) as quality_changes
FROM actors_history_scd
GROUP BY actorid, actor
HAVING COUNT(DISTINCT quality_class) > 1
ORDER BY quality_changes DESC
LIMIT 10;

-- Query 6: Active vs inactive actors by year
SELECT 
    current_year,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_actors,
    SUM(CASE WHEN NOT is_active THEN 1 ELSE 0 END) as inactive_actors
FROM actors
GROUP BY current_year
ORDER BY current_year;

-- Query 7: Find most prolific actors (most films in a single year)
SELECT 
    actor,
    current_year,
    ARRAY_LENGTH(films, 1) as film_count,
    quality_class
FROM actors
WHERE ARRAY_LENGTH(films, 1) IS NOT NULL
ORDER BY ARRAY_LENGTH(films, 1) DESC
LIMIT 10;

-- Query 8: Average rating by quality class to verify logic
SELECT 
    quality_class,
    COUNT(*) as actor_count,
    AVG(
        (SELECT AVG((f).rating) 
         FROM UNNEST(films) as f 
         WHERE (f).film IS NOT NULL)
    ) as avg_rating
FROM actors
WHERE current_year = 1970
GROUP BY quality_class
ORDER BY avg_rating DESC;
