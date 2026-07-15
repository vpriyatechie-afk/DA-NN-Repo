
--- Q1 How many donors were brain‑dead vs other organ failures?
--Reason - This helps us understand donor type patterns.
select brain_death, count(*) as total
from referrals
group by brain_death;
--------------------------------------------------------------------------------------------------------------------------------
--Q2 --How many families were approached vs not approached?
--Reason - This will know how many families where approaches if less we can increase the outreach activity to encourage families.
select approached, count(*) as total
from referrals
group by approached;
--------------------------------------------------------------------------------------------------------------------

--Q3  How many donors was led to a transplant?
--Reason Shows the donation  effectiveness

select count(*) filter (where transplanted = true) * 100.0 / count(*) as transplant_rate
	from referrals ;

--------------------------------------------------------------------------------------------------------------------
--Q4-What are the blood type distribution ?
--Reason Shows which blood types are most common.Useful for matching and understanding organ availability.
select abo_bloodtype, count(*) as total
from referrals
group by abo_bloodtype
order by total desc;
--------------------------------------------------------------------------------------------------------------------
--Q5 What are the referrals by year?
--Reason shows donation trends over time.
select referral_year, count(*) as total
from referrals
group by referral_year
order by referral_year;
--------------------------------------------------------------------------------------------------------------------
--Q6  How many donors were authorized but never procured?
--Reason These are lost donors  medically unstable,or family withdrawal.
select count(*) as authorized_not_procured
from referrals
where authorized = true and procured = false;
--------------------------------------------------------------------------------------------------------------------

--Q7 How many donors were procured but not transplanted?
--Reason Shows organs recovered but not used may be  due to quality issues.

select count(*) as procured_not_transplanted
from referrals
where procured = true and transplanted = false;

--------------------------------------------------------------------------------------------------------------------


--Q8.How many hospitals are associated with each OPO

select opo,count(distinct hospitalid) Hospital_count from
referrals where opo = substring(hospitalid,1,4)
group by opo;

--------------------------------------------------------------------------------------------------------------------
--Q9. How many total procurements happened based on race
select race,count(procured) procurement_count from referrals
where procured = true
group by race order by 2 desc;
--------------------------------------------------------------------------------------------------------------------
--Q10. Which year a greater number of patients got the organ for transplantation

select procured_year,count(patientid) Patient_Count from referrals
where procured_year is not null
group by procured_year order by 1;
--------------------------------------------------------------------------------------------------------------------
--Q11. Count of each organ transplanted in each OPO


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
group by opo;

--------------------------------------------------------------------------------------------------------------------
--Q12. Which hospitals had more than 200 transplants?
--Reason Helps identify high-performing hospitals.
select hospitalID,
count(*) as total_transplants
from referrals
where transplanted = true
group by hospitalID
having count(*) > 200
order by total_transplants desc;
--------------------------------------------------------------------------------------------------------------------
--Q13 How many cases where reffered but not approached?
--Reason to find the gap where the families where not approached even though the hospitals reffered
select referral_year,
count(*) as referred_not_approached
from referrals
where approached = false
group by referral_year
order by referral_year;

--------------------------------------------------------------------------------------------------------------------
--Q14 Was there anycases where it was either not authorized or approached but transplanted?
--Reason The purpose of the query is to validate data integrity and identify special case scenarios
select referral_year,
count(*) as not_authorized_orapproached__but_transplanted
from referrals
where authorized = false and approached = false
and transplanted = true
group by referral_year
order by referral_year;
--------------------------------------------------------------------------------------------------------------------
--Q15. Which OPO had the highest median of calculated deaths?
--Reason: Organ Procurement Organizations (OPOs) is necessary to accurately and fairly assess their performance
SELECT opo, Max(calc_deaths) AS MAX_DEATHS 
FROM calc_deaths GROUP BY opo;
--------------------------------------------------------------------------------------------------------------------
--Q16. How many referrals occurred per hospital?
--Reason: Based on the time_referred column from the referrals table, we calculated the number of hospitals has been referred to OPO
SELECT hospitalid, COUNT(hospitalid) 
FROM referrals 
WHERE time_referred IS NOT NULL 
GROUP BY hospitalid;
--------------------------------------------------------------------------------------------------------------------
--Q17. Distribution of patients by age group
--Reason: Segregating based on age helps us identify a donor and a recipient match
SELECT  
	CASE 
	WHEN Age < 18 THEN 'Pediatric' 
	WHEN Age BETWEEN 18 AND 60 THEN 'Adult' 
	WHEN Age > 60 THEN 'Senior Adult' 
	ELSE 'Unknown' 
	END AS AgeGroup, COUNT(patientid) AS PatientCount 
FROM referrals 
GROUP BY AgeGroup, 
	CASE 
	WHEN Age < 18 THEN 'Pediatric' 
	WHEN Age BETWEEN 18 AND 60 THEN 'Adult' 
	WHEN Age > 60 THEN 'Senior Adult' 
	ELSE 'Unknown' 
	END 
ORDER BY AgeGroup;
--------------------------------------------------------------------------------------------------------------------
--Q18. Finding the abnormal height and weight to check the data inconsistencies
--Reason: Finding abnormal height and weight values (outliers) is crucial to ensure data accuracy
select patientid, age, 
	heightin AS abnormal_height, 
	weightkg AS abnormal_weight 
from referrals
where heightin > 110 OR weightkg > 600;

--------------------------------------------------------------------------------------------------------------------
--Q19.List all donors and the year they donated the organs.
--Reason:To see if the organ donations are increasing or decreasing yearly and use this data further for policy and planning future organ campaign drives.
select 
patientid as donor_id,procured_year
from referrals
where procured_year is not null;
--------------------------------------------------------------------------------------------------------------------
--20.Count how many donors each hospital has and order the results by the highest number of donors.
--Reason:To see hospital performance and identifying the success models for organ doantion and help improve the under performing hospitals follow outreach campaigns.
select hospitalid,
count(*) as donor_count
from referrals
where procured_year is not null
group by hospitalid
order by donor_count desc;

--------------------------------------------------------------------------------------------------------------------











