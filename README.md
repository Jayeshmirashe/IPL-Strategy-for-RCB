# 🏏 IPL Strategy Analysis — Royal Challengers Bangalore

> **Role:** Sports Data Analyst | **Objective:** Identify top-performing players and optimize auction investments for RCB's 2017 IPL Mega Auction using 9 seasons of historical match data.

---

## 📌 Problem Statement

Royal Challengers Bangalore (RCB) — one of IPL's most popular franchises — has never won a title despite consistently boasting world-class batsmen. As a data analyst appointed by RCB management, the task was to:

- Diagnose **why** RCB has repeatedly fallen short
- Identify **which players** to target in the 2017 mega auction
- Recommend **strategic decisions** backed entirely by data

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| MySQL | All querying, analysis, and KPI engineering |
| INFORMATION_SCHEMA | Data profiling and schema exploration |
| Excel / Visualization Tool | Charts and dashboards for presentation |
| PowerPoint | Management presentation |

---

## 🗄️ Database Overview

- **20 relational tables** spanning 9 IPL seasons (2008–2016)
- **Granularity:** Ball-by-ball — every single delivery across all matches
- **Key tables:** `ball_by_ball`, `matches`, `player`, `season`, `venue`, `wicket_taken`, `team`, `extra_runs`, `out_type`, `bowling_style`

```
ball_by_ball ──── matches ──── season
     │                │
   player           venue
     │
wicket_taken ──── out_type
```

---

## 📁 Project Structure

```
IPL-Strategy-for-RCB/
│
├── Objective_SQL.sql       # 15 objective queries with full analysis
├── Subjective_SQL.sql      # 11 subjective queries with strategic insights
├── Project.docx            # Complete answers + reasoning document
└── RCB_IPL_Analysis.pptx   # Management presentation deck
```

---

## 🔍 Key Insights Uncovered

### 1. 🚨 RCB's Real Problem — Bowling, Not Batting
RCB's batting ranked **top 3 league-wide** across most seasons. Yet they kept losing. The LAG() year-over-year tracker revealed the pattern clearly:
- Batting improved or held steady → ✅
- Bowling economy worsened in the same seasons → ❌
- They scored 180s and conceded 185s — every single time

**Root cause:** Not bad luck. A repeating structural failure hidden inside the win/loss record.

---

### 2. 🎯 The Free 12-Point Win-Rate Edge
By joining `matches` + `toss_decision` + `outcomes`:

| Toss Decision | Win Rate |
|---------------|----------|
| **Field First** | **55%** |
| Bat First | 43% |

A 12-point win-rate advantage available **every single game** at zero additional cost — purely a strategy call.

---

### 3. 🏟️ Venue Rankings Expose Hidden Gems
Using `DENSE_RANK()` partitioned by `venue_id`, bowlers ranked **15th overall** surfaced as **1st at Chinnaswamy**. A flat leaderboard buries these players entirely. Venue-specific performance is a critical — and commonly ignored — selection filter.

---

### 4. 📊 Standard Averages Were Hiding the Wrong Players
A **double-condition subquery** filtered for players who cleared *both* thresholds simultaneously:
- Average runs `>` overall league batting average **AND**
- Wickets taken `>` overall league bowling average

This separated genuine all-rounders from batsmen who occasionally bowl — surfacing players who give double value per roster slot.

---

### 5. 💡 Death-Over Pressure Exposed by Custom KPIs
Career averages tell you nothing about performance under pressure. Two new metrics were engineered from scratch:

**Boundary Reliance %**
```sql
SUM(CASE WHEN Runs_Scored IN (4,6) THEN Runs_Scored ELSE 0 END) * 100.0
/ SUM(Runs_Scored)
```
> High % = aggressive; sudden drop = exposed under pressure

**Dot Ball %**
```sql
SUM(CASE WHEN Runs_Scored = 0 THEN 1 ELSE 0 END) * 100.0
/ COUNT(Ball_Id)
```
> Measures a bowler's ability to build pressure — not just take wickets

These two KPIs **reranked several "elite" players downward** who looked impressive in standard averages but underperformed in crunch overs.

---

### 6. 🏆 All-Rounder Composite Score
```
All-Rounder Score = Total Runs + (Total Wickets × 20)
```
A single number to rank players who contribute with both bat and ball — enabling direct comparison across roles for auction prioritization.

---

## ⚙️ SQL Techniques Used

| Technique | Applied To |
|-----------|-----------|
| `INFORMATION_SCHEMA` | Data profiling — column types and schema exploration |
| `CTEs` | Modular multi-step analysis (batting + bowling independently, then joined) |
| `LAG()` Window Function | Season-on-season performance delta tracking |
| `DENSE_RANK()` partitioned by venue | Location-specific bowler rankings |
| Double-condition Subquery | All-rounder filtering above dual league averages |
| `NULLIF()` | Division-by-zero protection in rate calculations |
| `COALESCE()` | NULL-safe aggregations across sparse match data |
| `TIMESTAMPDIFF()` | Age calculation relative to match date |
| `CREATE TABLE AS SELECT` | Building the persistent `rcb_record` venue win/loss table |
| `UPDATE + REPLACE` | Data correction (Delhi Capitals → Delhi Daredevils) |
| Multi-table `JOIN` | Connecting up to 6 tables in a single query |
| `CASE-WHEN` aggregations | Win/loss bucketing, wicket-type filtering, performance status flags |
| `HAVING` with subqueries | Filtering above overall league averages |

---

## 📋 Questions Answered

### Objective (15 Questions)
1. Column data types in `ball_by_ball` via INFORMATION_SCHEMA
2. Total runs scored by RCB in Season 1 (including extra runs)
3. Players older than 25 during the 2014 season
4. RCB wins in the 2013 season
5. Top 10 players by strike rate across the last 4 seasons
6. Average runs per batsman across all seasons
7. Average wickets per bowler across all seasons
8. Players above overall batting **and** bowling averages simultaneously
9. `rcb_record` table — wins and losses per venue
10. Impact of bowling style on wickets taken
11. Year-over-year team performance status using `LAG()`
12. Custom KPIs — Boundary Reliance % and Dot Ball %
13. Average wickets per bowler per venue with `DENSE_RANK()`
14. Players who have been consistently performing over multiple seasons
15. Players whose performance is suited to specific venues

### Subjective (11 Questions)
1. How toss decisions affect match results — overall and venue-wise
2. Player recommendations best suited for RCB
3. Key parameters for player selection
4. All-rounders identified by composite score
5. Players whose presence positively influences team win rate
6. Pre-auction strategic recommendations for RCB management
7. Factors contributing to high-scoring matches and their impact
8. Home-ground advantage analysis at Chinnaswamy
9. RCB's historical season performance and root cause of trophy drought
10. End-to-end problem-solving approach without given questions
11. Data correction — replacing incorrect team names via `UPDATE`

---

## 🎯 Strategic Recommendations to RCB

1. **Fix bowling first** — allocate 40%+ of auction budget to quality bowlers; batting is already elite
2. **Always field first after winning the toss** — data-proven 12-point win-rate advantage, zero cost
3. **Target venue-specialists** — use DENSE_RANK venue analysis to find bowlers built for Chinnaswamy's conditions
4. **Buy finishers, not more run-scorers** — death-over accelerators fill the one gap batting still has
5. **Prioritise players with high team win-rate** — Raina, Jadeja-type players whose teams win 2 in 3 games when they play

---

## 🚀 How to Run

```sql
-- Step 1: Run the data setup scripts (allow 7-8 minutes each)
SOURCE ipl_1.sql;
SOURCE ipl_2.sql;

-- Step 2: Run objective queries
SOURCE Objective_SQL.sql;

-- Step 3: Run subjective queries
SOURCE Subjective_SQL.sql;
```

> ⚠️ Run in an isolated MySQL environment with no other applications open alongside it for optimal load performance.

---

## 🙏 Acknowledgements

Special thanks to **Sanjay Mitreja** for the structured guidance and feedback throughout this project — pushing the analysis beyond surface-level answers into real analytical thinking.

Built as part of the **Data Science Program at [Newton School](https://www.newtonschool.co/)**.

---

## 📬 Connect

If you found this useful or have suggestions on KPIs I could have built differently — feel free to reach out or open an issue.

---

*Dataset covers IPL Seasons 1–9 (2008–2016). Analysis conducted for the 2017 Mega Auction context.*
