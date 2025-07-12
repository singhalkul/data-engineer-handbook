INSERT INTO actors
WITH this_year AS (
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
        MIN(year) as current_year
    FROM actor_films
    WHERE year = (SELECT MIN(year) FROM actor_films)
    GROUP BY actor, actorid
)
SELECT 
    actor,
    actorid,
    films,
    CASE 
        WHEN avg_rating > 8 THEN 'star'
        WHEN avg_rating > 7 THEN 'good'
        WHEN avg_rating > 6 THEN 'average'
        ELSE 'bad'
    END::quality_class as quality_class,
    TRUE as is_active,
    current_year
FROM this_year;

CREATE OR REPLACE FUNCTION populate_actors_for_year(target_year INTEGER)
RETURNS VOID AS $$
BEGIN
    INSERT INTO actors
    WITH last_year AS (
        SELECT * FROM actors 
        WHERE current_year = target_year - 1
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
            target_year as current_year
        FROM actor_films
        WHERE year = target_year
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
        target_year as current_year
    FROM this_year ty
    FULL OUTER JOIN last_year ly
    ON ty.actorid = ly.actorid;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    year_record RECORD;
BEGIN
    FOR year_record IN 
        SELECT DISTINCT year 
        FROM actor_films 
        WHERE year > (SELECT MIN(year) FROM actor_films)
        ORDER BY year
    LOOP
        PERFORM populate_actors_for_year(year_record.year);
        RAISE NOTICE 'Populated year %', year_record.year;
    END LOOP;
END;
$$;
