WITH last_year AS (
    SELECT * FROM actors 
    WHERE current_year = 1999
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
        2000 as current_year
    FROM actor_films
    WHERE year = 2000
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
    2000 as current_year
FROM this_year ty
FULL OUTER JOIN last_year ly
ON ty.actorid = ly.actorid;
