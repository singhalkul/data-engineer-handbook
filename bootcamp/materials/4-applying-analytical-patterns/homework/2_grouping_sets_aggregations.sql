WITH game_data AS (
    SELECT 
        gd.player_name,
        gd.team_id,
        gd.team_abbreviation,
        gd.pts,
        gd.reb,
        gd.ast,
        gd.game_id,
        g.season,
        CASE 
            WHEN gd.team_id = g.home_team_id AND g.home_team_wins = 1 THEN 1
            WHEN gd.team_id = g.visitor_team_id AND g.home_team_wins = 0 THEN 1
            ELSE 0
        END AS team_won
    FROM game_details gd
    JOIN games g ON gd.game_id = g.game_id
),
grouped_set AS (
  SELECT
    CASE 
        WHEN GROUPING(player_name, team_id) = 0 THEN 'Player-Team'
        WHEN GROUPING(player_name, season) = 0 THEN 'Player-Season' 
        WHEN GROUPING(team_id) = 0 THEN 'Team-Overall'
    END AS analysis_type,   
    COALESCE(player_name, 'Overall') as player_name,
    COALESCE(team_id::VARCHAR, 'Overall') as team,
    COALESCE(season::VARCHAR, 'Overall') as season,
    SUM(pts) as total_points,
    SUM(reb) as total_rebounds,
    SUM(ast) as total_assists,
    COUNT(DISTINCT game_id) as games_played,
    SUM(team_won) as games_won,
    ROUND(AVG(pts)::numeric, 1) as avg_points_per_game
  FROM game_data
  GROUP BY GROUPING SETS (
      (player_name, team_id),
      (player_name, season),
      (team_id)
  )
)
SELECT 
    player_name,
    team,
    total_points,
    games_played,
    avg_points_per_game
FROM grouped_set
where analysis_type='Player-Team' and total_points is not null
ORDER BY total_points DESC
LIMIT 10;

SELECT 
    player_name,
    team,
    total_points,
    games_played,
    avg_points_per_game
FROM grouped_set
where analysis_type='Player-Season' and total_points is not null
ORDER BY total_points DESC
LIMIT 10;

SELECT 
    player_name,
    team,
    total_points,
    games_played,
    avg_points_per_game
FROM grouped_set
where analysis_type='Team-Overall' and total_points is not null
ORDER BY total_points DESC
LIMIT 10;
