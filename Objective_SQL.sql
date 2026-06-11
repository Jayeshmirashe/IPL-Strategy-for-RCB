-- 1.	List the different dtypes of columns in table “ball_by_ball” (using information schema)

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ball_by_ball';

-- 2.	What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)

SELECT
    SUM(b.Runs_Scored + COALESCE(e.Extra_Runs, 0)) AS Total_Runs
FROM ball_by_ball b
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN team t ON b.Team_Batting = t.Team_Id
LEFT JOIN extra_runs e
    ON b.Match_Id = e.Match_Id
    AND b.Over_Id = e.Over_Id
    AND b.Ball_Id = e.Ball_Id
    AND b.Innings_No = e.Innings_No
WHERE m.Season_Id = 1 AND t.Team_Name = 'Royal Challengers Bangalore';

-- 3.	How many players were more than the age of 25 during season 2014?

SELECT
    COUNT(DISTINCT p.Player_Id) AS Older_Than_25
FROM matches m
INNER JOIN player_match pm ON m.Match_Id = pm.Match_Id
INNER JOIN player p ON pm.Player_Id = p.Player_Id
WHERE m.Season_Id IN (
    SELECT Season_Id FROM season WHERE Season_Year = 2014
)
AND TIMESTAMPDIFF(YEAR, p.DOB, m.Match_Date) > 25;

-- 4.	How many matches did RCB win in 2013?

SELECT
    COUNT(Match_Id) Total_Win_By_RCB
FROM matches m
INNER JOIN team t
ON m.Team_1= t.team_id OR m.Team_2 = t.Team_Id
INNER JOIN season s
ON m.Season_Id= s.Season_Id
WHERE s.Season_Year=2013 AND t.Team_Name='Royal Challengers Bangalore';

-- 5.	List the top 10 players according to their strike rate in the last 4 seasons

SELECT
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs,
    COUNT(*) AS Balls_Faced,
    ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(*), 2) AS Strike_Rate
FROM ball_by_ball b
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN season s ON m.Season_Id = s.Season_Id
JOIN player p ON b.Striker = p.Player_Id
WHERE s.Season_Year >= (
    SELECT MAX(Season_Year) - 3 FROM season
)
GROUP BY p.Player_Name
HAVING COUNT(*) >= 20
ORDER BY Strike_Rate DESC
LIMIT 10;

-- 6.	What are the average runs scored by each batsman considering all the seasons?

SELECT
    p.Player_Name,
    ROUND(AVG(b.Runs_Scored), 2) AS Avg_Runs_Per_Ball
FROM ball_by_ball b
INNER JOIN player p ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Avg_Runs_Per_Ball DESC;

-- 7.	What are the average wickets taken by each bowler considering all the seasons?

SELECT
    p.Player_Name,
    SUM(CASE WHEN ot.Out_Name IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 ELSE 0 END) AS Total_Wickets,
    COUNT(DISTINCT b.Match_Id) AS Matches_Played,
    ROUND(
        SUM(CASE WHEN ot.Out_Name IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 ELSE 0 END) * 1.0
        / COUNT(DISTINCT b.Match_Id), 2
    ) AS Avg_Wickets_Per_Match
FROM ball_by_ball b
INNER JOIN wicket_taken wt
    ON b.Match_Id = wt.Match_Id
    AND b.Over_Id = wt.Over_Id
    AND b.Ball_Id = wt.Ball_Id
    AND b.Innings_No = wt.Innings_No
INNER JOIN out_type ot
    ON wt.Kind_Out = ot.Out_Id
INNER JOIN player p
    ON b.Bowler = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Avg_Wickets_Per_Match DESC;

-- 8.	List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average

WITH avg_runs AS (
    SELECT
        b.Striker AS player_id,
        p.player_name,
        AVG(b.runs_scored) AS avg_runs
    FROM ball_by_ball b
    INNER JOIN player p ON p.player_id = b.striker
    GROUP BY b.Striker, p.player_name
),
wicket_taken AS (
    SELECT
        b.bowler AS player_id,
        SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS wicket_taken
    FROM ball_by_ball b
    LEFT JOIN wicket_taken wt
        ON b.match_id = wt.match_id
        AND b.over_id = wt.over_id
        AND b.ball_id = wt.ball_id
        AND b.innings_no = wt.innings_no
    LEFT JOIN out_type ot ON ot.out_id = wt.kind_out
    GROUP BY b.bowler
)
-- Bring your two clean CTEs together!
SELECT
    a.player_name,
    ROUND(a.avg_runs, 2) AS avg_runs,
    w.wicket_taken
FROM avg_runs a
INNER JOIN wicket_taken w ON a.player_id = w.player_id
WHERE a.avg_runs > (SELECT AVG(avg_runs) FROM avg_runs)
  AND w.wicket_taken > (SELECT AVG(wicket_taken) FROM wicket_taken)
ORDER BY w.wicket_taken DESC, a.avg_runs DESC;

-- 9.	Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

CREATE TABLE rcb_record AS
SELECT
    v.Venue_Name,
    -- Bucket 1: Count a Win if RCB's Team_Id matches the Match_Winner
    SUM(CASE WHEN m.Match_Winner = rcb.Team_Id THEN 1 ELSE 0 END) AS Total_Wins,

    -- Bucket 2: Count a Loss if there WAS a winner, but it wasn't RCB
    SUM(CASE WHEN m.Match_Winner != rcb.Team_Id AND m.Match_Winner IS NOT NULL THEN 1 ELSE 0 END) AS Total_Losses

FROM matches m
JOIN venue v ON m.Venue_Id = v.Venue_Id
-- Dynamically fetch RCB's ID
JOIN team rcb ON rcb.Team_Name = 'Royal Challengers Bangalore'

-- Filter the dataset to ONLY include matches where RCB stepped on the field
WHERE m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id

GROUP BY v.Venue_Name
ORDER BY Total_Wins DESC;

-- 10.What is the impact of bowling style on wickets taken?

SELECT
    bs.bowling_skill,

    SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS wicket_taken,

    -- Adding Strike Rate (Total Balls / Total Wickets) to measure true impact
    ROUND(
        COUNT(b.ball_id) * 1.0 /
        NULLIF(SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END), 0), 2
    ) AS strike_rate

FROM ball_by_ball b
INNER JOIN player p
    ON b.bowler = p.player_id
INNER JOIN bowling_style bs
    ON p.bowling_skill = bs.bowling_id
LEFT JOIN wicket_taken wt
    ON b.match_id = wt.match_id
    AND b.over_id = wt.over_id
    AND b.ball_id = wt.ball_id
    AND b.innings_no = wt.innings_no
LEFT JOIN out_type ot
    ON ot.out_id = wt.kind_out
GROUP BY bs.bowling_skill
ORDER BY wicket_taken DESC;

-- 11.	Write the SQL query to provide a status of whether the performance of the team is better 
-- than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken

WITH Team_Batting AS (
    SELECT
        t.team_name,
        s.season_year,
        SUM(b.runs_scored) AS total_runs,
        LAG(SUM(b.runs_scored)) OVER(PARTITION BY t.team_name ORDER BY s.season_year) AS prev_yr_runs
    FROM ball_by_ball b
    INNER JOIN matches m ON b.match_id = m.match_id
    INNER JOIN season s ON m.season_id = s.season_id
    INNER JOIN team t ON b.team_batting = t.team_id
    GROUP BY t.team_name, s.season_year
),
Team_Bowling AS (
    SELECT
        t.team_name,
        s.season_year,
        -- wicket-counting logic:
        SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS total_wickets,
        LAG(SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END)) OVER(PARTITION BY t.team_name ORDER BY s.season_year) AS prev_yr_wickets
    FROM ball_by_ball b
    INNER JOIN wicket_taken wt 
        ON b.match_id = wt.match_id 
        AND b.over_id = wt.over_id 
        AND b.ball_id = wt.ball_id 
        AND b.innings_no = wt.innings_no
    INNER JOIN out_type ot ON ot.out_id = wt.kind_out
    INNER JOIN matches m ON b.match_id = m.match_id
    INNER JOIN season s ON m.season_id = s.season_id
    INNER JOIN team t ON b.team_bowling = t.team_id
    GROUP BY t.team_name, s.season_year
)
-- Bring your two optimized CTEs together to create the final review
SELECT
    bat.team_name,
    bat.season_year,
    bat.total_runs,
    bat.prev_yr_runs,
    bowl.total_wickets,
    bowl.prev_yr_wickets,
    CASE
        WHEN bat.prev_yr_runs IS NULL THEN 'First Season'
        WHEN bat.total_runs > bat.prev_yr_runs AND bowl.total_wickets > bowl.prev_yr_wickets THEN 'Improved in Both'
        WHEN bat.total_runs > bat.prev_yr_runs THEN 'Improved Batting Only'
        WHEN bowl.total_wickets > bowl.prev_yr_wickets THEN 'Improved Bowling Only'
        ELSE 'Declined in Both'
    END AS performance_review
FROM Team_Batting bat
INNER JOIN Team_Bowling bowl
    ON bat.team_name = bowl.team_name
    AND bat.season_year = bowl.season_year
ORDER BY bat.team_name, bat.season_year;

-- 12.	Can you derive more KPIs for the team strategy?

-- 1.	Boundary Reliance Percentage (Batting Aggression)

SELECT
    t.Team_Name,
    SUM(b.Runs_Scored) AS Total_Runs,
    -- Count the runs ONLY if they were a 4 or a 6
    SUM(CASE WHEN b.Runs_Scored IN (4, 6) THEN b.Runs_Scored ELSE 0 END) AS Boundary_Runs,

    -- Calculate the percentage
    ROUND(
        SUM(CASE WHEN b.Runs_Scored IN (4, 6) THEN b.Runs_Scored ELSE 0 END) * 100.0
        / SUM(b.Runs_Scored), 2
    ) AS Boundary_Reliance_Pct
FROM ball_by_ball b
JOIN team t ON b.team_batting = t.team_id
GROUP BY t.Team_Name
ORDER BY Boundary_Reliance_Pct DESC;

-- 2.	Dot Ball Percentage (Bowling Pressure)

SELECT
    t.Team_Name,
    COUNT(b.Ball_Id) AS Total_Balls_Bowled,

    -- Count a ball as a "Dot" if zero runs were scored
    SUM(CASE WHEN b.Runs_Scored = 0 THEN 1 ELSE 0 END) AS Total_Dot_Balls,

    -- Calculate the percentage
    ROUND(
        SUM(CASE WHEN b.Runs_Scored = 0 THEN 1 ELSE 0 END) * 100.0
        / COUNT(b.Ball_Id), 2
    ) AS Dot_Ball_Pct
FROM ball_by_ball b
JOIN team t ON b.team_bowling = t.team_id
GROUP BY t.Team_Name
ORDER BY Dot_Ball_Pct DESC;

-- 13.	Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.

SELECT
    v.venue_name,
    p.player_name,

    -- Using your explicit inclusion list for perfect accuracy
    SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS total_venue_wickets,

    COUNT(DISTINCT b.match_id) AS matches_played,

    -- Calculating the average
    ROUND(
        SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) * 1.0
        / COUNT(DISTINCT b.match_id), 2
    ) AS avg_wickets_per_match,

    -- Ranking the bowlers strictly within their specific venue
    DENSE_RANK() OVER(
        PARTITION BY v.venue_name
        ORDER BY ROUND(
            SUM(CASE WHEN ot.out_name IN ('caught','bowled','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) * 1.0
            / COUNT(DISTINCT b.match_id), 2
        ) DESC
    ) AS venue_rank

FROM ball_by_ball b
INNER JOIN matches m ON b.match_id = m.match_id
INNER JOIN venue v ON m.venue_id = v.venue_id
INNER JOIN player p ON b.bowler = p.player_id
LEFT JOIN wicket_taken wt
    ON b.match_id = wt.match_id
    AND b.over_id = wt.over_id
    AND b.ball_id = wt.ball_id
    AND b.innings_no = wt.innings_no
LEFT JOIN out_type ot ON ot.out_id = wt.kind_out

GROUP BY v.venue_name, p.player_name
HAVING COUNT(DISTINCT b.match_id) >= 5  -- Filters out part-timers who only bowled 1 match at a venue
ORDER BY v.venue_name, venue_rank;

-- 14.	Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

SELECT
    p.player_name,
    COUNT(DISTINCT s.season_year) AS total_seasons_played,
    SUM(b.runs_scored) AS total_career_runs,
    ROUND(SUM(b.runs_scored) * 1.0 / COUNT(DISTINCT b.match_id), 2) AS avg_runs_per_match

FROM ball_by_ball b
INNER JOIN player p ON b.striker = p.player_id
INNER JOIN matches m ON b.match_id = m.match_id
INNER JOIN season s ON m.season_id = s.season_id
GROUP BY p.player_name

-- Adjusted filters for a 4-year dataset
HAVING COUNT(DISTINCT s.season_year) >= 3
    AND SUM(b.runs_scored) >= 1000

ORDER BY total_career_runs DESC;

-- 15.	Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?)

SELECT
    p.Player_Name,
    v.Venue_Name,
    COUNT(DISTINCT b.Match_Id)   AS matches_played,
    SUM(b.Runs_Scored)           AS total_runs,
    ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(*), 2) AS strike_rate
FROM Ball_by_Ball b
JOIN Player p ON b.Striker = p.Player_Id
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE p.Player_Name IN (
    'V Kohli', 'AB de Villiers', 'CH Gayle',
    'DA Warner', 'RG Sharma', 'SK Raina'
)
GROUP BY p.Player_Name, v.Venue_Name
HAVING matches_played >= 3
ORDER BY p.Player_Name, total_runs DESC;




