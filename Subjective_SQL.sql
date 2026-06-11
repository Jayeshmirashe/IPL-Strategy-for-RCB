																				-- Subjective Questions –

-- 1.	How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

-- Query 1 — Overall toss winner win rate

SELECT
    COUNT(*) AS total_matches,
    SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS toss_winner_won,
    ROUND(
        SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS toss_win_pct
FROM Matches
WHERE Outcome_type = 1;  -- exclude no-result/tied matches

-- Query 2 — Win rate by toss decision (bat vs field)

SELECT
    td.Toss_Name AS toss_decision,
    COUNT(*) AS total_matches,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS toss_winner_won,
    ROUND(
        SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS win_pct
FROM Matches m
JOIN Toss_Decision td ON m.Toss_Decide = td.Toss_Id
WHERE m.Outcome_type = 1
GROUP BY td.Toss_Name;

-- Query 3 — Venue-wise toss advantage (main deliverable for the venue question)

SELECT
    v.Venue_Name,
    COUNT(*) AS total_matches,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS toss_winner_won,
    ROUND(
        SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS toss_win_pct
FROM Matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE m.Outcome_type = 1
GROUP BY v.Venue_Name
HAVING COUNT(*) >= 10        -- filter out venues with too few games (unreliable %)
ORDER BY toss_win_pct DESC;

-- 2. Suggest some of the players who would be best fit for the team.

SELECT
    p.Player_Name,
    COUNT(DISTINCT b.Match_Id) AS matches,
    SUM(b.Runs_Scored) AS total_runs,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS batting_avg,
    ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(*), 2) AS strike_rate
FROM Ball_by_Ball b
JOIN Player p ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
HAVING matches >= 20      -- only players with enough games
ORDER BY total_runs DESC
LIMIT 15;

SELECT
    p.Player_Name,
    COUNT(*) AS man_of_match_count
FROM Matches m
JOIN Player p ON m.Man_of_the_Match = p.Player_Id
GROUP BY p.Player_Name
ORDER BY man_of_match_count DESC
LIMIT 10;

-- 3. What are some of the parameters that should be focused on while selecting the players?

-- Think of building an IPL team like assembling a restaurant kitchen. You do not need 5 chefs who all do the same job — you need a head chef, a dessert specialist, a grill expert. Same logic applies to cricket.

-- Strike Rate — How fast a batsman scores. In a 20-over game, time is limited. A batsman who scores quickly is more valuable than one who plays safe and slow.
-- Batting Average — Shows consistency. Anyone can have one great match. What matters is whether they perform match after match, season after season.
-- All-round ability — A player who can both bat and bowl is like an employee who handles two departments. They give the captain more flexibility and save a roster slot.
-- Economy Rate — How many runs a bowler gives away per over. A bowler who concedes fewer runs keeps pressure on the opponent even without taking wickets.
-- Man of the Match count — Stats are good but match-winning moments are better. Players with high MOM count have a habit of showing up when it matters most.
-- Role clarity — The most important parameter. Every player selected should fill a specific gap. Buying a great player who duplicates an existing role adds zero value.
-- Kohli is already a world-class anchor. Every other pick should maximise strike rate and finishing ability. The data supports this clearly — RCB does not need more anchors, they need match-winners.


-- 4.	Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)

WITH batting AS (
    SELECT
        b.Striker AS Player_Id,
        SUM(b.Runs_Scored) AS total_runs,
        ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(*), 2) AS strike_rate,
        COUNT(DISTINCT b.Match_Id) AS bat_matches
    FROM Ball_by_Ball b
    GROUP BY b.Striker
    HAVING bat_matches >= 15
),
bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        SUM(CASE WHEN ot.Out_Name IN (
            'caught','bowled','lbw','stumped',
            'caught and bowled','hit wicket'
        ) THEN 1 ELSE 0 END) AS total_wickets,
        ROUND(SUM(b.Runs_Scored) * 6.0 / COUNT(*), 2) AS economy_rate,
        COUNT(DISTINCT b.Match_Id) AS bowl_matches
    FROM Ball_by_Ball b
    LEFT JOIN Wicket_Taken w
        ON b.Match_Id = w.Match_Id
        AND b.Over_Id = w.Over_Id
        AND b.Ball_Id = w.Ball_Id
        AND b.Innings_No = w.Innings_No
    LEFT JOIN Out_Type ot
        ON w.Kind_Out = ot.Out_Id
    GROUP BY b.Bowler
    HAVING bowl_matches >= 15
)
SELECT
    p.Player_Name,
    bat.total_runs,
    bat.strike_rate,
    bowl.total_wickets,
    bowl.economy_rate,
    ROUND(bat.total_runs + bowl.total_wickets * 20, 0) AS allrounder_score
FROM batting bat
JOIN bowling bowl ON bat.Player_Id = bowl.Player_Id
JOIN Player p ON p.Player_Id = bat.Player_Id
ORDER BY allrounder_score DESC
LIMIT 10;

-- 5.	Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)

SELECT
    p.Player_Name,
    COUNT(DISTINCT pm.Match_Id)       AS matches_played,
    SUM(CASE WHEN m.Match_Winner = pm.Team_Id 
        THEN 1 ELSE 0 END)           AS matches_won,
    ROUND(SUM(CASE WHEN m.Match_Winner = pm.Team_Id 
        THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(DISTINCT pm.Match_Id), 2)  AS win_rate_pct,
    SUM(CASE WHEN m.Man_of_the_Match = p.Player_Id 
        THEN 1 ELSE 0 END)    AS mom_count
FROM Player_Match pm
JOIN Player p ON pm.Player_Id = p.Player_Id
JOIN Matches m ON pm.Match_Id = m.Match_Id
WHERE m.Outcome_type = 1
GROUP BY p.Player_Name
HAVING matches_played >= 30
ORDER BY win_rate_pct DESC
LIMIT 15;

-- 6. What would you suggest to RCB before going to the mega auction?

-- Keep Virat Kohli — no matter what — He is the heart of the team. 2,472 runs, most consistent player in the data. Every other decision should be built around him.
-- Fix the bowling first — RCB's problem has never been scoring runs. It has always been giving away too many runs while bowling. At least 40% of auction budget should go to quality bowlers.
-- Buy finishers, not more run-scorers — A batsman who scores 30 slowly is less useful than one who scores 30 in 10 balls. Players like AB de Villiers and KA Pollard who accelerate in the final overs are exactly what RCB needs.
-- Pick players who win matches, not just look good on paper — The win rate data shows players like SK Raina and RA Jadeja — their teams win nearly 2 out of every 3 games they play. That kind of influence cannot be ignored.
-- Always choose to chase after winning the toss — Data proves it — teams that field first win 55% of the time vs only 43% when batting first. This is a free advantage available every single game.

-- 7. What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies


-- Think of a high-scoring IPL match like a blockbuster movie — the more action there is, the more people want to watch. Here's what causes those big-score games and why it matters.
-- Factors that cause high-scoring matches:
-- 1. Flat batting-friendly pitches Some grounds like Chinnaswamy Stadium (RCB's home) have pitches where the ball comes onto the bat easily. Bowlers struggle, batsmen dominate, and scores go above 200 regularly. The ground itself is a factor before a single ball is bowled.
-- 2. Short boundaries Smaller grounds mean more sixes and fours. A ball that would be a comfortable catch in a big ground becomes a six in a small one. Chinnaswamy is again a perfect example — one of the smallest boundaries in IPL.
-- 3. Powerplay rules In the first 6 overs only 2 fielders are allowed outside the inner ring. This forces bowlers into high-risk areas and gives explosive openers like CH Gayle and DA Warner the freedom to attack from ball one — directly inflating scores.
-- 4. Dew factor in evening matches As the night progresses, dew makes the ball wet and harder to grip for bowlers. Spinners become ineffective, swing disappears, and the batting team chasing benefits massively — leading to higher second-innings scores.
-- 5. Quality of batting available The data shows players like AB de Villiers (SR 164.27), KA Pollard (SR 142.86) in the same team. When world-class finishers bat together, even 10 overs can produce 120+ runs.
-- ________________________________________
-- Impact on viewership:
-- High-scoring matches = more entertainment = more viewers. A match where 400+ runs are scored across both innings keeps fans on the edge of their seat till the last ball. This directly increases TV ratings, stadium attendance, and social media engagement — which is why broadcasters and franchises both love high-scoring venues.
-- ________________________________________
-- Impact on team strategies:
-- For batting teams — high-scoring conditions encourage aggressive batting from ball one. Every over matters. Teams stop playing safe and start targeting 200+ as a standard score.
-- For bowling teams — in high-scoring conditions, the strategy shifts from taking wickets to simply restricting runs. A bowler who concedes only 8 runs per over in a 220-run game is more valuable than one who takes 2 wickets but gives 12 runs per over.
-- For auction strategy — teams playing in high-scoring venues specifically target power hitters and death-over specialists in the auction rather than defensive players.
-- ________________________________________
-- Core idea: High-scoring matches are not random — they are caused by specific conditions like ground size, pitch nature, rules, and weather. Smart teams identify these conditions early and build their squad and strategy specifically around them.

-- 8. Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB

SELECT
    CASE 
        WHEN v.Venue_Name LIKE '%Chinnaswamy%' THEN 'Home'
        ELSE 'Away'
    END AS match_type,
    COUNT(DISTINCT m.Match_Id)  AS total_matches,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END)  AS matches_won,
    ROUND(SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(DISTINCT m.Match_Id), 2)   AS win_rate_pct
FROM Matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
  AND m.Outcome_type = 1
GROUP BY match_type;

-- 9. Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy

-- Query 1 — RCB season-wise win/loss record

SELECT
    s.Season_Year,
    COUNT(DISTINCT m.Match_Id)  AS matches_played,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END)  AS matches_won,
    SUM(CASE WHEN m.Match_Winner != 2
        AND m.Outcome_type = 1 THEN 1 ELSE 0 END)  AS matches_lost,
    ROUND(SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(DISTINCT m.Match_Id), 2) AS win_rate_pct
FROM Matches m
JOIN Season s ON m.Season_Id = s.Season_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
  AND m.Outcome_type = 1
GROUP BY s.Season_Year
ORDER BY s.Season_Year;

SELECT
    s.Season_Year,
    SUM(b.Runs_Scored)       AS total_runs,
    COUNT(w.Player_Out)      AS total_wickets_taken
FROM Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Season s ON m.Season_Id = s.Season_Id
LEFT JOIN Wicket_Taken w
    ON b.Match_Id   = w.Match_Id
    AND b.Over_Id   = w.Over_Id
    AND b.Ball_Id   = w.Ball_Id
    AND b.Innings_No = w.Innings_No
WHERE b.Team_Batting = 2
GROUP BY s.Season_Year
ORDER BY s.Season_Year;

-- 10. How would you approach this problem, if the objective and subjective questions weren't given?

-- Step 1 — Understand the business problem first Before touching any data, the first question is — what is the actual goal? In this case it is helping RCB make smarter decisions at the mega auction. Everything else flows from that one goal.
-- Step 2 — Explore the data Open the database, look at all the tables, understand what data is available. Check how many seasons, how many matches, which columns exist, are there any missing values or errors. You cannot analyze what you do not understand first.
-- Step 3 — Ask the right business questions yourself Without given questions, a good analyst generates their own. Questions like — which players perform best under pressure? Does winning the toss actually matter? Does home ground help? These come naturally once you understand the goal.
-- Step 4 — Start with the team's overall performance Look at RCB's win/loss record across seasons first. This gives a baseline — how good or bad has the team actually been? Everything else is analyzed in context of this baseline.
-- Step 5 — Dig into why — batting, bowling, or both? Split the analysis into batting performance and bowling performance separately. Compare RCB's numbers against other teams. This tells you exactly where the problem is — not just that they lost, but why they lost.
-- Step 6 — Identify the best available players Once you know the gaps — for example RCB needs better bowling — you look at which players across all IPL teams fill that gap. Strike rate, economy, consistency, all-round ability — rank them all.
-- Step 7 — Build visualizations to tell the story Raw numbers do not convince people. Charts and dashboards make the findings clear and memorable. A good analyst does not just find the answer — they present it in a way anyone can understand.
-- Step 8 — Give actionable recommendations The final output is not just analysis — it is specific suggestions. Not "RCB needs better bowlers" but "target DJ Bravo and Harbhajan Singh specifically because the data shows they fit the exact gaps RCB has."

-- 11. In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" 
-- instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils"

SELECT * FROM Team
WHERE Team_Name LIKE '%Delhi%';

-- If incorrect, fix it there
UPDATE Team
SET Team_Name = 'Delhi Daredevils'
WHERE Team_Name = 'Delhi Capitals';