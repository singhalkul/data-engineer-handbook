
SELECT 
    actorid,
    actor,
    COUNT(DISTINCT quality_class) as quality_changes
FROM actors_history_scd
GROUP BY actorid, actor
HAVING COUNT(DISTINCT quality_class) > 1
ORDER BY quality_changes DESC
LIMIT 10;

SELECT 
    current_year,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_actors,
    SUM(CASE WHEN NOT is_active THEN 1 ELSE 0 END) as inactive_actors
FROM actors
GROUP BY current_year
ORDER BY current_year;

SELECT 
    actor,
    current_year,
    ARRAY_LENGTH(films, 1) as film_count,
    quality_class
FROM actors
WHERE ARRAY_LENGTH(films, 1) IS NOT NULL
ORDER BY ARRAY_LENGTH(films, 1) DESC
LIMIT 10;

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
