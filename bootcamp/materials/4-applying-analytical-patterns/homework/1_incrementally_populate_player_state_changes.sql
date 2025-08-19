CREATE TABLE IF NOT EXISTS player_state_changes_table (
    player_name TEXT,
    current_season INTEGER,
    is_active BOOLEAN,
    first_season INTEGER,
    last_season INTEGER,
    state_change TEXT
);

INSERT into player_state_changes_table
WITH
  prev_year AS (
    SELECT * FROM player_state_changes_table
    WHERE current_season = 1995
),
curr_year AS (
SELECT * FROM players
WHERE current_season = 1996
)
SELECT
  COALESCE(c.player_name, p.player_name) AS player_name,
  COALESCE(c.current_season, p.current_season) AS current_season,
  COALESCE(c.is_active, p.is_active) AS is_active,
  COALESCE(p.first_season, c.current_season) AS first_season,
  CASE
    WHEN c.is_active = TRUE THEN c.current_season
    ELSE p.last_season
  END as last_season,
  CASE
    WHEN p.player_name IS NULL THEN 'New'
    WHEN p.is_active = TRUE AND c.is_active = TRUE THEN 'Continued Playing'
    WHEN p.is_active = TRUE AND c.is_active = FALSE THEN 'Retired'
    WHEN p.is_active = FALSE AND c.is_active = TRUE THEN 'Returned From Retirement'
    WHEN p.is_active = FALSE AND c.is_active = FALSE THEN 'Stayed Retired'
    ELSE 'Unknown'
  END AS state_change
FROM
  curr_year c
  FULL OUTER JOIN prev_year p ON c.player_name = p.player_name;