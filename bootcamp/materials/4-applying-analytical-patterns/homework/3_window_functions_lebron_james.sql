WITH lebron_games AS (
    SELECT 
        gd.player_name,
        g.game_date_est,
        gd.pts,
        CASE WHEN gd.pts > 10 THEN 1 ELSE 0 END as scored_over_10
    FROM game_details gd
    JOIN games g ON gd.game_id = g.game_id
    WHERE gd.player_name = 'LeBron James'
    ORDER BY g.game_date_est
),
lebron_with_flags AS (
    SELECT *,
        CASE 
            WHEN LAG(scored_over_10) OVER (ORDER BY game_date_est) = scored_over_10 THEN 0
            ELSE 1
        END AS new_streak
    FROM lebron_games
),
lebron_with_streaks AS (
    SELECT *,
        SUM(new_streak) OVER (ORDER BY game_date_est) AS streak_group
    FROM lebron_with_flags
),
lebron_streak_lengths AS (
    SELECT 
        streak_group,
        scored_over_10,
        COUNT(*) as streak_length,
        MIN(game_date_est) as streak_start,
        MAX(game_date_est) as streak_end
    FROM lebron_with_streaks
    WHERE scored_over_10 = 1
    GROUP BY streak_group, scored_over_10
)
SELECT 
    streak_length,
    streak_start,
    streak_end
FROM lebron_streak_lengths
ORDER BY streak_length DESC;