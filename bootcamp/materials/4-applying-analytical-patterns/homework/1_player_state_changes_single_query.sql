-- This query is an iteration of the query in 1_minimal_solution.sql and includes the first and last season data in the output based on the feedback from the assessment.
WITH player_state AS(
	SELECT
		player_name,
		current_season,
		is_active,
		LAG(is_active) OVER(PARTITION BY player_name ORDER BY current_season) AS prev_active,
		MIN(current_season) OVER(PARTITION BY player_name) AS first_season,
		MAX(current_season) FILTER( WHERE is_active = true) OVER(PARTITION BY player_name) AS last_season
	FROM players
)
SELECT
	player_name,
	current_season,
	is_active,
	first_season,
	CASE
		WHEN is_active = TRUE THEN current_season
		ELSE last_season
	END AS last_season,
	CASE
		WHEN prev_active IS NULL AND is_active = TRUE THEN 'New'
		WHEN prev_active = TRUE AND is_active = TRUE THEN 'Continued Playing'
		WHEN prev_active = TRUE AND is_active = FALSE THEN 'Retired'
		WHEN prev_active = FALSE AND is_active = TRUE THEN 'Returned From Retirement'
		WHEN prev_active = FALSE AND is_active = FALSE THEN 'Stayed Retired'
		ELSE 'Unknown'
	END AS state_change
FROM player_state;