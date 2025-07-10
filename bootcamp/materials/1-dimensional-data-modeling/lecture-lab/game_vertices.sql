INSERT into vertices
SELECT
  game_id AS identifier,
  'game'::vertex_type AS TYPE,
  json_build_object('pts_home', pts_home, 'pts_away', pts_away, 'winning_team', case when home_team_wins = 1 then home_team_id else visitor_team_id end) AS properties
FROM
  games;
select * from vertices;
