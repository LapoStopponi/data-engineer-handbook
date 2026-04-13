select * from player_seasons;

/*To better deal with the temporal component, we want to create a table that has
one row per player, and has an array of all of their seasons, to kinda remove 
the temporal component or push it aside */

-- We need to create a STRUCT

CREATE TYPE season_stats AS (
                    season INTEGER,
                    gp INTEGER,
                    pts REAL,
                    reb REAL,
                    ast REAL
)

/* We want to consider a new table, it will be all of the columns that are
the players so that we don't duplicate them, and then we'll have the array of
seasons stats */

CREATE TYPE scoring_class AS ENUM ('star', 'good', 'average', 'bad');

CREATE TABLE players(
    player_name TEXT,
    height TEXT,
    college TEXT,
    country TEXT,
    draft_year TEXT,
    draft_round TEXT,
    draft_number TEXT,
    season_stats season_stats[],
    scoring_class scoring_class,
    years_since_last_season INTEGER,
    current_season INTEGER,
    PRIMARY KEY(player_name, current_season)
)

-- Those are the values that don't really change in the dataset

-- this is gonna give us the cumulation between today and yesterday
INSERT INTO players
WITH yesterday as (
    SELECT * from players
    WHERE current_season = 2000
),
    today AS(
        SELECT * FROM player_seasons
        WHERE season = 2001
    )


-- you want to coalesce the values that are not temporal
SELECT 
    COALESCE(t.player_name, y.player_name) as player_name, 
    COALESCE(t.height, y.height) as height, 
    COALESCE(t.college, y.college) as college, 
    COALESCE(t.country, y.country) as country, 
    COALESCE(t.draft_year, y.draft_year) as draft_year, 
    COALESCE(t.draft_round, y.draft_round) as draft_round, 
    COALESCE(t.draft_number, y.draft_number) as draft_number, 
    CASE WHEN y.season_stats IS NULL
        THEN ARRAY [ROW(
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
    WHEN t.season IS NOT NULL THEN y.season_stats || ARRAY [ROW(
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
    ELSE y.season_stats
    END season_stats,
    CASE
        WHEN t.season IS NOT NULL THEN
            CASE WHEN t.pts > 20 THEN 'star'
                WHEN t.pts > 15 THEN 'good'
                WHEN t.pts > 10 THEN 'average'
                ELSE 'bad'
            END::scoring_class
            ELSE y.scoring_class
        END AS scoring_class,
    CASE WHEN t.season IS NOT NULL THEN 0
        ELSE y.years_since_last_season + 1
    END AS years_since_last_season,
    COALESCE(t.season, y.current_season + 1) as current_season
     FROM today t FULL OUTER JOIN yesterday y 
    ON t.player_name = y.player_name;

SELECT * FROM players
where current_season = 2001 and player_name = 'Michael Jordan';

/* U can also unnested it if you need it, it is very useful to use cumulative
tables: 

with unnested as(
    SELECT player_name,
        UNNEST(season_stats)::season_stats ad season_stats
    FROM players
    WHERE current_season = 2001
)

SELECT player_name,
    (season_stats::season::stats).*
FROM unnested;
*/


SELECT 
    player_name,
    (season_stats[cardinality(season_stats)]::season_stats).pts/
    CASE WHEN (season_stats[1]::season_stats).pts = 0 THEN 1 ELSE (season_stats[1]::season_stats).pts END
    
FROM players
WHERE current_season = 2001
AND scoring_class = 'star';
