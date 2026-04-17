

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

DROP table players;

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
    is_active BOOLEAN,
    PRIMARY KEY(player_name, current_season)
)

-- Those are the values that don't really change in the dataset
-- Generating season
INSERT INTO players
WITH years AS (
    SELECT *
    FROM generate_series(1996, 2022) as season
),
    p AS (
        SELECT player_name, MIN(season) as first_season
        FROM player_seasons
        GROUP BY player_name
    ),
    players_and_seasons AS (
        select *
        from p
                join years y on p.first_season <= y.season
    ),
    windowed as (
        select ps.player_name,
               ps.season,
               array_remove(
                    array_agg(CASE
                                WHEN p1.season is not null 
                                THEN CAST (row(p1.season, p1.gp, p1.pts, p1.reb, p1.ast) as season_stats)
                                else null
                    end)
                    over (partition by ps.player_name
                          order by ps.season
                          rows between unbounded preceding and current row
                    ),
                    null
                ) as seasons 
        from players_and_seasons ps
                left join player_seasons p1
                    on ps.player_name = p1.player_name
                        and ps.season = p1.season
        order by ps.player_name, ps.season
        ),
    static as(
        select player_name,
            max(height)         as height,
            max(college)        as college, 
            max(country)        as country,
            max(draft_year)     as draft_year,
            max(draft_round)    as draft_round,
            max(draft_number)   as draft_number
        from player_seasons
        group by player_name 
    )
select w.player_name,
        s.height,
        s.college,
        s.country,
        s.draft_year,
        s.draft_round,
        s.draft_number,
        seasons as seasons_stats,
        case 
            when (seasons[cardinality(seasons)]::season_stats).pts > 20 THEN 'star'
            when (seasons[cardinality(seasons)]::season_stats).pts > 15 THEN 'good'
            when (seasons[cardinality(seasons)]::season_stats).pts > 10 THEN 'average'
            else 'bad'
        end::scoring_class  as scoring_class, 
        w.season - (seasons[cardinality(seasons)]::season_stats).season as years_since_last_season,
        w.season,
                (seasons[cardinality(seasons)]::season_stats).season = w.season as is_active
from windowed w
    join static s on w.player_name = s.player_name;        
-- this is gonna give us the cumulation between today and yesterday
/*INSERT INTO players
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



-- lab 2

CREATE TABLE players_scd (
    player_name TEXT,
    scoring_class scoring_class,
    is_active BOOLEAN,
    start_season INTEGER,
    end_season INTEGER,
    current_season INTEGER,
    PRIMARY KEY(player_name, start_season)
)

insert into players_scd
with with_previous as(
select 
    player_name,
    current_season, 
    scoring_class, 
    is_active,
    lag(scoring_class, 1) over(partition by player_name order by current_season) as previous_scoring_class,
    lag(is_active, 1) over(partition by player_name order by current_season) as previous_is_active
    
from players
where current_season <= 2021
),

with_indicators AS(
select * , case 
                when scoring_class <> previous_scoring_class then 1 
                when is_active <> previous_is_active then 1 
                else 0 
            end as change_indicator
from with_previous
),

with_streaks as(
select *, 
    sum(change_indicator) over(partition by player_name order by current_season) as streak_identifier
from with_indicators
)

select player_name,
       scoring_class,
       is_active,
       min(current_season) as start_season,
       max(current_season) as end_season,
       2021 as current_season
from with_streaks
group by player_name, streak_identifier, is_active, scoring_class
order by player_name, streak_identifier

select * from players_scd

/* that was how you can create an scd table. You can think of the season in here, and change in other 
occasions to day, month, year, or whatever you want.
Things that are not the best are these windows function, and you do them on all the dataset, only in the
end you crunch the data. But it's a very powerful query*/

create type scd_type as(
    scoring_class scoring_class,
    is_active boolean,
    start_season integer,
    end_season integer
)

with last_season_scd as(
    select * from players_scd
    where current_season = 2021
    and end_season = 2021
),

    historical_scd as(
        select 
            player_name,
            scoring_class,
            is_active,
            start_season,
            end_season
        from players_scd
        where current_season = 2021
        and end_season < 2021
    ),

    this_season_data as(
        select *
        from players
        where current_season = 2022
    ),
    unchanged_records as (
       select ts.player_name,
       ts.scoring_class,
       ts.is_active,
       ls.start_season,
       ts.current_season as end_season 
        from this_season_data ts
        join last_season_scd ls
        on ts.player_name = ls.player_name
        where ts.scoring_class = ls.scoring_class
        and ts.is_active = ls.is_active
    ),
    changed_records as(
               select ts.player_name,
       unnest(array[
        row(
            ls.scoring_class,
            ls.is_active,
            ls.start_season,
            ls.end_season
        )::scd_type,
        row(
            ts.scoring_class,
            ts.is_active,
            ts.current_season,
            ts.current_season
        )::scd_type
       ]) as records
        from this_season_data ts
        left join last_season_scd ls
        on ts.player_name = ls.player_name
        where (ts.scoring_class <> ls.scoring_class
        or ts.is_active<> ls.is_active)
    
    ),
    unnested_changed_records as(
        select 
        player_name,
        (records::scd_type).scoring_class,
        (records::scd_type).is_active,
        (records::scd_type).start_season,
        (records::scd_type).end_season
        from changed_records
    ),
    new_records as(
        SELECT 
        ts.player_name,
        ts.scoring_class,
        ts.is_active,
        ts.current_season as start_season,
        ts.current_season as end_season
        FROM this_season_data ts
        left join last_season_scd ls
        on ts.player_name = ls.player_name
        where ls.player_name is null
    )

select * from historical_scd
union ALL
select * from unchanged_records
union all 
select * from unnested_changed_records
union ALL
select * from new_records
