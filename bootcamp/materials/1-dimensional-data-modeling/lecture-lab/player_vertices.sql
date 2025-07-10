insert into vertices
with players_agg as (
SELECT
  player_id AS identifier,
  MAX(player_name) as player_name,
  'player'::vertex_type AS TYPE,
  count(1) AS games,
  sum(pts) AS total_points,
  ARRAY_AGG(DISTINCT team_id) AS teams
FROM
  game_details
GROUP BY
  player_id
)
select identifier, 'player'::vertex_type AS TYPE, json_build_object('name', player_name, 'num_games', games, 'total_points', total_points, 'teams', teams) from players_agg;
