 -- ==================================================================
 --************************DATA CLEANING*******************************
 -- ====================================================================
-- ===============================================================================
 -- Step 1 Create a back up for original data before data clean up
 -- ==============================================================================

create table public.referrals_backup as
(select * from referrals);


create table public.calc_deaths_backup as
(select * from calc_deaths);


-- ===============================================================================
 -- Step 2 Convert all date fields from text to timestamp
 -- ==============================================================================
ALTER TABLE referrals
ALTER COLUMN time_brain_death TYPE timestamp USING to_timestamp(time_brain_death,'MM/DD/YY HH24:MI');


ALTER TABLE referrals
ALTER COLUMN time_asystole TYPE timestamp USING to_timestamp(time_asystole,'MM/DD/YY HH24:MI');

ALTER TABLE referrals
ALTER COLUMN time_referred TYPE timestamp USING to_timestamp(time_referred,'MM/DD/YY HH24:MI');

ALTER TABLE referrals
ALTER COLUMN time_approached TYPE timestamp USING to_timestamp(time_approached,'MM/DD/YY HH24:MI');

ALTER TABLE referrals
ALTER COLUMN time_authorized TYPE timestamp USING to_timestamp(time_authorized,'MM/DD/YY HH24:MI');

ALTER TABLE referrals
ALTER COLUMN time_procured TYPE timestamp USING to_timestamp(time_procured,'MM/DD/YY HH24:MI');

 -- =========================================================================
 -- Step 3a Convert heightin to NUMERIC(10,2)
 -- ==========================================================================

ALTER TABLE referrals
ALTER COLUMN heightin
TYPE NUMERIC(10,2)
USING heightin::NUMERIC;
 -- =========================================================================
 -- Step 3b Convert weightkg to NUMERIC(10,2)
 -- ==========================================================================

ALTER TABLE referrals
ALTER COLUMN weightkg
TYPE NUMERIC(10,2)
USING weightkg::NUMERIC;


 -- ================================
 -- Step 4 Fill missing gender
 -- ================================
UPDATE referrals 
SET gender = 'Not Disclosed' 
WHERE gender IS NULL;
 -- ================================
 -- Step 5 Fill missing ABO blood type
 -- ================================
UPDATE referrals 
SET abo_bloodtype = 'Not Recorded' 
WHERE abo_bloodtype IS NULL;
 -- ================================
 -- Step 6 Fill missing ABO Rh factor
 -- ================================
UPDATE referrals 
SET abo_rh = 'Not Recorded' 
WHERE abo_rh IS NULL;
 -- ================================
 -- Step 7 Trim trailing spaces in ABO Rh
 -- ================================
UPDATE referrals 
SET abo_rh = RTRIM(abo_rh);


===============================================================================
	--Database design - Creating constraints on table
===============================================================================

ALTER table referrals add constraint patientid_pk
primary key(patientid);


ALTER table calc_deaths 
ALTER column opo set not null;



==========================================================================
	--- Creating Indexes on tables
==========================================================================
CREATE INDEX idx_referrals_hospitalid
ON referrals (hospitalid);


CREATE INDEX idx_referrals_opo_hospital
ON referrals (opo, hospitalid);


CREATE INDEX idx_recovered_organs
ON referrals (hospitalid)
WHERE outcome_heart = 'Transplanted';

CREATE INDEX idx_calcdeaths_opo
ON calc_deaths (opo,year);

=============================================================================
--- Creating Patient Demographics Table
===============================================================================

create table patient_demographics as
(select patientid,age,gender,race,hospitalid,heightin,weightkg,abo_bloodtype,abo_rh,
referral_year from referrals);

ALTER TABLE patient_demographics
ADD CONSTRAINT fk_patient
FOREIGN KEY (patientid)
REFERENCES referrals(patientid);

CREATE INDEX idx_patient
ON patient_demographics (patientid);

 -- ====================================
 --  **********VERIFICATION***********         
 -- ====================================

 
 -- ==========================================================
 -- 1. Verification of all datetime conversions succeeded
 -- ==========================================================

SELECT time_brain_death, time_asystole, time_referred, time_approached, time_authorized, time_procured
FROM referrals
WHERE  time_brain_death IS NULL
    OR time_asystole IS NULL
    OR time_referred IS NULL
    OR time_approached IS NULL
    OR time_authorized IS NULL
    OR time_procured IS NULL;
-- ==========================================================
-- 2. Verification of height and weight converted succeeded
-- ==========================================================

SELECT patientid, heightin, weightkg
FROM referrals
WHERE heightin IS NULL OR weightkg IS NULL;

-- ==========================================================
-- 3. Verification rounding worked
-- ==========================================================
SELECT heightin, weightkg
FROM referrals
LIMIT 20;

-- ==========================================================================================
-- 4. Verification fill missing values updates  for gender,abo_bloodtype,abo_rh
-- ==========================================================================================

SELECT COUNT(*) 
FROM referrals 
WHERE gender IS NULL;

SELECT COUNT(*) 
FROM referrals 
WHERE abo_bloodtype IS NULL;

SELECT COUNT(*) 
FROM referrals 
WHERE abo_rh IS NULL;

-- ==========================================================================================
-- 5. Verification trimming updates  for abo_rh
-- ==========================================================================================

select DISTINCT abo_rh
from referrals
order by abo_rh;
-- ==========================================================================================
-- 6. Verification for negative or unrealistic ages/height 
-- ==========================================================================================
select patientid, age
from referrals
where age < 0 OR age > 120;

select patientid, heightin, weightkg
from referrals
where heightin < 30 OR heightin > 90 OR weightkg < 20 OR weightkg > 300;

-- ==========================================================================================
-- 7. Check for  duplicate patient IDs
-- ==========================================================================================

select patientid, count(*)
from referrals
group by patientid
having count(*) > 1;


