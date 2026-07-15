--Q1 Calculate average time between referral and approach?
--Reason Measures how quickly OPO staff respond after a referral. 


select  referral_year,
avg(time_approached - time_referred) as avg_time_to_approach
from referrals
where time_approached is not null
group by referral_year
order by referral_year;
--------------------------------------------------------------------------------------------------------------------
--Q2 Find referrals that happened during night hours (22:00–06:00)
--Reason: Identifies after‑hours workload.


select referral_year,
count(*) as night_referrals
from referrals
where extract(hour from time_referred) between 22 and 23
or extract(hour from time_referred) between 0 and 6
group by referral_year;
--------------------------------------------------------------------------------------------------------------------
--Q3 Count referrals by hour of day
--Reason: Understand when referrals happen most.


select extract(hour from time_referred) as referral_hour,
count(*) as total_referrals
from referrals
group by referral_hour
order by referral_hour;
--------------------------------------------------------------------------------------------------------------------
--Q4 Find cases where approach happened after a long delay
--Reason Detect delayed OPO response.


select *
from referrals
where time_approached - time_referred > INTERVAL '24 hours';
--------------------------------------------------------------------------------------------------------------------
---Q5. Calculate average donor age by cause of death
--Reason Shows demographic patterns over cause of death


select 
cause_of_death_opo,
avg(age) as avg_age
from referrals
group by cause_of_death_opo
order by avg_age desc;
--------------------------------------------------------------------------------------------------------------------
---Q6 . Find donors younger than 18 and their causes of death
--Reason Pediatric donors are rare and important.


select age,cause_of_death_opo,
count(*) as total
from referrals
where age < 18 
and transplanted = true
group  by age, cause_of_death_opo
order by total desc;
--------------------------------------------------------------------------------------------------------------------
--Q7. Calculate the number of organs transplanted per donor 
-- Reason Measures donor yield.


select patientid,age,
(case when outcome_heart = 'Transplanted' then 1 else 0 end +
case when outcome_kidney_left = 'Transplanted' then 1 else 0 end +
case when outcome_kidney_right = 'Transplanted' then 1 else 0 end +
case when outcome_liver = 'Transplanted' then 1 else 0 end +
case when outcome_lung_left = 'Transplanted' then 1 else 0 end +
case when outcome_lung_right = 'Transplanted' then 1 else 0 end +
case when outcome_pancreas = 'Transplanted' then 1 else 0 end +
case when outcome_intestine = 'Transplanted' then 1 else 0 end) AS organs_transplanted
from referrals;
--------------------------------------------------------------------------------------------------------------------
--Q8. Rank hospitals by yearly referral volume
--Reason : shows us which hospital got most referrals and least number of referrals
SELECT
    hospitalid,
    DATE_TRUNC('year', time_referred) AS year,
    COUNT(*) AS referral_count,
    RANK() OVER (
        PARTITION BY DATE_TRUNC('year', time_referred)
        ORDER BY COUNT(*) DESC
    ) AS rank_in_year
FROM referrals
GROUP BY hospitalid, DATE_TRUNC('year', time_referred)
ORDER BY year, rank_in_year;
--------------------------------------------------------------------------------------------------------------------
--Q9. For each year, calculate a rolling range of deaths
--sum, average of calculated deaths and min and max with lower bound and upper bound
SELECT
    opo,
    year,
    calc_deaths,
    calc_deaths_lb,
    calc_deaths_ub,
    SUM(calc_deaths) OVER (-- rolling sum of deaths (current year ± 1 year)
        PARTITION BY opo
        ORDER BY year
        RANGE BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS rolling_3yr_deaths,
    AVG(calc_deaths) OVER ( -- rolling average
        PARTITION BY opo
        ORDER BY year
        RANGE BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS rolling_3yr_avg,
   MIN(calc_deaths_lb) OVER ( -- rolling uncertainty range
        PARTITION BY opo
        ORDER BY year
        RANGE BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS rolling_lb,
    MAX(calc_deaths_ub) OVER (
        PARTITION BY opo
        ORDER BY year
        RANGE BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS rolling_ub
FROM calc_deaths
ORDER BY opo, year;
--------------------------------------------------------------------------------------------------------------------
--Q10. Which OPO has lost more Donors
-- Donors that are approached but not authorized

SELECT opo,
       COUNT(*) FILTER (WHERE approached AND NOT authorized) AS lost_donors
FROM referrals
GROUP BY opo
ORDER BY lost_donors DESC;
--------------------------------------------------------------------------------------------------------------------
--Q11. Rank the Hospitals as per their authorization efficiency
SELECT hospitalid,
       ROUND(100.0 * COUNT(*) FILTER (WHERE authorized) /
             NULLIF(COUNT(*) FILTER (WHERE approached),0),2) AS efficiency,
       DENSE_RANK() OVER (ORDER BY 
             COUNT(*) FILTER (WHERE authorized) * 1.0 /
             NULLIF(COUNT(*) FILTER (WHERE approached),0) DESC) AS rank
FROM referrals
GROUP BY hospitalid;
--------------------------------------------------------------------------------------------------------------------
--Q12. What is the first referral of each hospital every year
SELECT *
FROM (
    SELECT hospitalid, patientid, time_referred,
           ROW_NUMBER() OVER (PARTITION BY hospitalid, referral_year 
		   ORDER BY time_referred) AS rn
    FROM referrals
) 
WHERE rn = 1;
--------------------------------------------------------------------------------------------------------------------
--Q13.Identifying the donor who has an extreme BMI

WITH bmi_calc AS (
    SELECT patientid,
           weightkg / NULLIF(POWER(heightin * 0.0254,2),0) AS bmi
    FROM referrals
    WHERE heightin IS NOT NULL
      AND weightkg IS NOT NULL
),
stats AS (
    SELECT AVG(bmi) AS avg_bmi,
           STDDEV(bmi) AS sd
    FROM bmi_calc
)
SELECT b.patientid,
       ROUND(b.bmi,2) AS bmi,
       ROUND((b.bmi - s.avg_bmi) / NULLIF(s.sd,0),2) AS z_score
FROM bmi_calc b
CROSS JOIN stats s
WHERE s.sd IS NOT NULL
  AND s.sd <> 0
  AND ABS((b.bmi - s.avg_bmi) / NULLIF(s.sd,0)) > 2
ORDER BY z_score DESC;

--------------------------------------------------------------------------------------------------------------------
--Q14 Compare authorization speed in quartiles

SELECT patientid,
       NTILE(4) OVER (ORDER BY time_authorized - time_approached) 
	   AS speed_group
FROM referrals
WHERE authorized;
--------------------------------------------------------------------------------------------------------------------
--Q15. Find the patients with rare blood types who have high transplant success.

SELECT abo_bloodtype,
       COUNT(*) AS total_cases,
       COUNT(*) FILTER (WHERE transplanted) / COUNT(*)
	   AS success_rate
FROM referrals
GROUP BY abo_bloodtype
HAVING COUNT(*) < 50
ORDER BY success_rate DESC;
--------------------------------------------------------------------------------------------------------------------

--Q16. Organ-specific transplant count

SELECT 
    outcome_heart,
    COUNT(*) AS total
FROM referrals
WHERE procured = TRUE
GROUP BY outcome_heart;
--------------------------------------------------------------------------------------------------------------------
--Q17. Calculate the authorization rate among those approached
 
SELECT 
    ROUND(
        COUNT(*) FILTER (WHERE authorized = TRUE)::numeric /
        NULLIF(COUNT(*) FILTER (WHERE approached = TRUE), 0),
        2
    ) AS authorization_rate
FROM referrals;
--------------------------------------------------------------------------------------------------------------------
--Q18. Authorization rate by race

SELECT 
    race, 
    ROUND(
        COUNT(*) FILTER (WHERE authorized = TRUE)::numeric /
        NULLIF(COUNT(*) FILTER (WHERE approached = TRUE), 0),
        2
    ) AS authorization_rate
FROM referrals
GROUP BY race
ORDER BY authorization_rate DESC;
--------------------------------------------------------------------------------------------------------------------
--Q19. Which OPO is done more organ transplantation

WITH OPO_ORGAN as(
select opo,
sum(case when outcome_heart = 'Transplanted' then 1 else 0 end) as Heart,
sum(case when outcome_liver = 'Transplanted' then 1 else 0 end) as liver,
sum(case when outcome_kidney_left = 'Transplanted' then 1 else 0 end) Kidney_Left,
sum(case when outcome_kidney_right = 'Transplanted' then 1 else 0 end)Kidney_Right,
sum(case when outcome_lung_left = 'Transplanted' then 1 else 0 end)Lung_left,
sum(case when outcome_lung_right = 'Transplanted' then 1 else 0 end)Lung_right,
sum(case when outcome_intestine = 'Transplanted' then 1 else 0 end)Intestine,
sum(case when outcome_pancreas = 'Transplanted' then 1 else 0 end)Pancreas
from referrals
group by opo)
select opo,(heart+liver+kidney_left+kidney_right+lung_left+lung_right+intestine+pancreas) tot_organ
from OPO_ORGAN order by 2 desc limit 1;
--------------------------------------------------------------------------------------------------------------------
--Q20. OPO year wise performance review based on organ procured
with opo_procurement as(
select opo,procured_year,count(patientid) tot_count from referrals
where procured = true
group by opo,procured_year
)select opo, procured_year,tot_count,lead(tot_count)over(order by procured_year )  from  opo_procurement
where opo='OPO1'
order by procured_year; 
--------------------------------------------------------------------------------------------------------------------
--Q21. Which Organ is getting transplanted more

WITH organ_table as (
select sum(case when outcome_heart = 'Transplanted' then 1 else 0 end) as Heart,
sum(case when outcome_liver = 'Transplanted' then 1 else 0 end) as liver,
sum(case when outcome_kidney_left = 'Transplanted' then 1 else 0 end) Kidney_Left,
sum(case when outcome_kidney_right = 'Transplanted' then 1 else 0 end)Kidney_Right,
sum(case when outcome_lung_left = 'Transplanted' then 1 else 0 end)Lung_left,
sum(case when outcome_lung_right = 'Transplanted' then 1 else 0 end)Lung_right,
sum(case when outcome_intestine = 'Transplanted' then 1 else 0 end)Intestine,
sum(case when outcome_pancreas = 'Transplanted' then 1 else 0 end)Pancreas
from referrals
) 
SELECT organ, count_value
FROM organ_table,
LATERAL (
    VALUES
        ('Heart', heart),
        ('Liver', liver),
        ('Kidney_Left', kidney_left),
        ('Kidney_Right', kidney_right),
        ('Lung_Left', lung_left),
        ('Lung_Right', lung_right),
        ('Intestine', intestine),
        ('Pancreas', pancreas)
) AS v(organ, count_value)
ORDER BY count_value DESC
LIMIT 1;
--------------------------------------------------------------------------------------------------------------------
--Q22. Organ Procurement based on Gender

with patient_count as(
select gender,procured_year, count(patientid) patient_cnt 
from referrals
where procured_year is not null
group by gender,procured_year
)
select gender,procured_year,patient_cnt,rank()over(partition by gender order by patient_cnt desc) 
from patient_count;
--------------------------------------------------------------------------------------------------------------------
--Q23. Time taken between Authorized and Procured

select opo,extract(day from(avg(time_procured-time_authorized)))avg_time_diff from referrals
where time_authorized is not null and
time_procured is not null
group by opo;
--------------------------------------------------------------------------------------------------------------------
--Q24. Donors Cause of death UNOS vs organ transplantation

With cause_of_death as  
(select cause_of_death_unos,(case when transplanted = true then 'Yes' end) as  trans_true,
(case when transplanted = false then 'No' end) as trans_false
from referrals 
where cause_of_death_unos is not null)
select cause_of_death_unos,count(trans_true) as Transplanted,count(trans_false) as Not_Transplanted
from cause_of_death
group by cause_of_death_unos
order by 2 desc;
--------------------------------------------------------------------------------------------------------------------
--Q25. OPO wise report on average deaths vs average patient age in each year

select c.opo,c.year,round(avg(c.calc_deaths),2) Avg_Death_Count,round(avg(r.age),2) Avg_Patient_Age
from calc_deaths c, referrals r
where c.opo = r.opo
and r.age is not null
group by c.opo,c.year;
--------------------------------------------------------------------------------------------------------------------
--Q26. Hospital ranking based on organ procurement for research purpose

WITH organ_table as (
select hospitalid,sum(case when outcome_heart = 'Recovered for Research' then 1 else 0 end) as Heart,
sum(case when outcome_liver = 'Recovered for Research' then 1 else 0 end) as liver,
sum(case when outcome_kidney_left = 'Recovered for Research' then 1 else 0 end) Kidney_Left,
sum(case when outcome_kidney_right = 'Recovered for Research' then 1 else 0 end)Kidney_Right,
sum(case when outcome_lung_left = 'Recovered for Research' then 1 else 0 end)Lung_left,
sum(case when outcome_lung_right = 'Recovered for Research' then 1 else 0 end)Lung_right,
sum(case when outcome_intestine = 'Recovered for Research' then 1 else 0 end)Intestine,
sum(case when outcome_pancreas = 'Recovered for Research' then 1 else 0 end)Pancreas
from referrals
group by hospitalid
) 
SELECT hospitalid,total_recovered,hospital_rank from
(SELECT
    hospitalid,
    (heart + liver + kidney_left + kidney_right +
     lung_left + lung_right + intestine + pancreas) AS total_recovered,
    DENSE_RANK() OVER (
        ORDER BY 
            (heart + liver + kidney_left + kidney_right +
             lung_left + lung_right + intestine + pancreas) DESC
    ) AS hospital_rank
FROM organ_table)
where total_recovered > 0
ORDER BY hospital_rank;
--------------------------------------------------------------------------------------------------------------------
--Q27.Rank hospitals by number of transplants.

select hospitalid,
count(transplanted) as total_referrals,
    rank() over (order by count(transplanted) desc) as hospital_rank
from referrals where transplanted=true
group by hospitalid
order by total_referrals desc;
--------------------------------------------------------------------------------------------------------------------
--Q28.What is the total distribution of available heart_outcomes across the recovery categories? and show how many records currently have an 'Unknown' status?

select 
coalesce(outcome_heart, 'Unknown') as outcome_heart,
count(*) as total_cases
from referrals
where outcome_heart in (
'Transplanted',
'Recovered for Transplant but not Transplanted',
'Recovered for Research'
) or outcome_heart is null
group by 1
order by total_cases desc;
--------------------------------------------------------------------------------------------------------------------
--Q29:Count different organ transplants by year with running total.

select 
extract(year from time_referred) as transplant_year,
    count(*) filter (where outcome_heart = 'Transplanted') +
    count(*) filter (where outcome_liver = 'Transplanted') +
    count(*) filter (where outcome_kidney_left = 'Transplanted') +
    count(*) filter (where outcome_kidney_right = 'Transplanted') +
    count(*) filter (where outcome_lung_left = 'Transplanted') +
    count(*) filter (where outcome_lung_right = 'Transplanted') +
    count(*) filter (where outcome_intestine = 'Transplanted') +
    count(*) filter (where outcome_pancreas = 'Transplanted')
    as total_transplants,
sum(
        count(*) filter (where outcome_heart = 'Transplanted') +
        count(*) filter (where outcome_liver = 'Transplanted') +
        count(*) filter (where outcome_kidney_left = 'Transplanted') +
        count(*) filter (where outcome_kidney_right = 'Transplanted') +
        count(*) filter (where outcome_lung_left = 'Transplanted') +
        count(*) filter (where outcome_lung_right = 'Transplanted') +
        count(*) filter (where outcome_intestine = 'Transplanted') +
        count(*) filter (where outcome_pancreas = 'Transplanted')
    ) over (order by extract(year from time_referred))
    as running_total
from referrals
group by extract(year from time_referred)
order by transplant_year;
--------------------------------------------------------------------------------------------------------------------
--Q30.How many organ procurements were performed by each OPO, broken down by year and month, and which months had the highest procurement activity?

select opo, procured_year,
to_char(to_date(extract
(month from time_procured)::text,'MM'),
'Month') as month,
count(patientid) procured_count
from referrals
where time_procured is not null 
group by opo,
procured_year, month
order by procured_count desc












































