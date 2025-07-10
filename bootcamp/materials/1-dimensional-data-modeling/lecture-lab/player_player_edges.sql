-- WITH deduped AS (
--     SELECT *, row_number() over (PARTITION BY player_id, game_id) AS row_num
--     FROM game_details
-- ),
--      filtered AS (
--          SELECT * FROM deduped
--          WHERE row_num = 1
--      ),
--      aggregated AS (
--           SELECT
--            f1.player_id,
--             f1.player_name,
--            f2.player_id,
--            f2.player_name,
--            CASE WHEN f1.team_abbreviation =         f2.team_abbreviation
--                 THEN 'shares_team'::edge_type
--             ELSE 'plays_against'::edge_type
--             END,
--             COUNT(1) AS num_games,
--             SUM(f1.pts) AS left_points,
--             SUM(f2.pts) as right_points
--         FROM filtered f1
--             JOIN filtered f2
--             ON f1.game_id = f2.game_id
--             AND f1.player_name <> f2.player_name
--         WHERE f1.player_id > f2.player_id
--         GROUP BY
--                 f1.player_id,
--             f1.player_name,
--            f2.player_id,
--            f2.player_name,
--            CASE WHEN f1.team_abbreviation =         f2.team_abbreviation
--                 THEN  'shares_team'::edge_type
--             ELSE 'plays_against'::edge_type
--             END
--      )





insert into edges
WITH deduped AS (
    SELECT *, row_number() over (PARTITION BY player_id, game_id) AS row_num
    FROM game_details
),
     filtered AS (
         SELECT * FROM deduped
         WHERE row_num = 1
     ),
     aggregated AS (
          SELECT
           f1.player_id as sub_id,
            max(f1.player_name) as sub_name,
           f2.player_id as obj_id,
           max(f2.player_name) as obj_name,
           CASE WHEN f1.team_abbreviation =         f2.team_abbreviation
                THEN 'shares_team'::edge_type
            ELSE 'plays_against'::edge_type
            END as edge_type,
            COUNT(1) AS num_games,
            SUM(f1.pts) AS left_points,
            SUM(f2.pts) as right_points
        FROM filtered f1
            JOIN filtered f2
            ON f1.game_id = f2.game_id
            AND f1.player_name <> f2.player_name
        WHERE f1.player_id > f2.player_id
        GROUP BY
                f1.player_id,
           f2.player_id,
           CASE WHEN f1.team_abbreviation =         f2.team_abbreviation
                THEN  'shares_team'::edge_type
            ELSE 'plays_against'::edge_type
            END
     )
     
     select 
     sub_id as subject_identifier, 
     'player'::vertex_type as subject_type,
     obj_id as object_identifier,
     'player'::vertex_type as object_type,
     edge_type as edge_type,
     json_build_object(
     'num_games', num_games,
     'sub_points', left_points,
     'obj_points', right_points
     )
     from aggregated;
     