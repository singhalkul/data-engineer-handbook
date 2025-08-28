WITH team_games_with_wins AS (
    SELECT 
        gd.team_abbreviation,
        g.game_date_est,
        g.game_id,
        CASE 
            WHEN gd.team_id = g.home_team_id AND g.home_team_wins = 1 THEN 1
            WHEN gd.team_id = g.visitor_team_id AND g.home_team_wins = 0 THEN 1
            ELSE 0
        END AS team_won
    FROM game_details gd
    JOIN games g ON gd.game_id = g.game_id
    GROUP BY gd.team_abbreviation, g.game_date_est, g.game_id, gd.team_id, g.home_team_id
),
team_games_ordered AS (
    SELECT 
        team_abbreviation,
        game_date_est,
        game_id,
        team_won,
        ROW_NUMBER() OVER (
            PARTITION BY team_abbreviation 
            ORDER BY game_date_est, game_id
        ) as game_number
    FROM team_games_with_wins
),
team_90_game_windows AS (
    SELECT 
        team_abbreviation,
        game_date_est,
        game_id,
        game_number,
        team_won,
        SUM(team_won) OVER (
            PARTITION BY team_abbreviation 
            ORDER BY game_number 
            ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
        ) as wins_in_90_games
    FROM team_games_ordered
),
max_wins_90_games AS (
    SELECT 
        team_abbreviation,
        MAX(wins_in_90_games) as max_wins_in_90_games
    FROM team_90_game_windows
    GROUP BY team_abbreviation
)

SELECT 
    team_abbreviation,
    max_wins_in_90_games
FROM max_wins_90_games
ORDER BY max_wins_in_90_games DESC;