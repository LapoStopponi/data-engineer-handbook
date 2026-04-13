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

CREATE TABLE players(
    player_name TEXT,
    height TEXT,
    college TEXT,
    country TEXT,
    draft_year TEXT,
    draft_round TEXT,
    draft_number TEXT,
    season_stats season_stats[],
    current_season INTEGER,
    PRIMARY KEY(player_name, current_season)
)

-- Those are the values that don't really change in the dataset

select min(season) from player_seasons;