-- This query solves only the minimal homework about solving for the player's is_active state changes but does not store the start and end season values for a player.

WITH player_state AS(
	SELECT
		player_name,
		current_season,
		is_active,
		LAG(is_active) OVER(PARTITION BY player_name ORDER BY current_season) AS prev_active
	FROM players
)

SELECT
	player_name,
	current_season,
	is_active,
	CASE
		WHEN prev_active IS NULL AND is_active = TRUE THEN 'New'
		WHEN prev_active = TRUE AND is_active = TRUE THEN 'Continued Playing'
		WHEN prev_active = TRUE AND is_active = FALSE THEN 'Retired'
		WHEN prev_active = FALSE AND is_active = TRUE THEN 'Returned From Retirement'
		WHEN prev_active = FALSE AND is_active = FALSE THEN 'Stayed Retired'
		ELSE 'Unknown'
	END AS active_status
FROM player_state;