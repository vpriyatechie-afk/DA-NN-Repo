---Q1 Categorize donors into Pediatric vs Adult
--Reason Summarizes donor demographics in one simple table.

CREATE OR REPLACE FUNCTION donor_age_group(age int)
RETURNS text AS $$
BEGIN
    IF age < 18 THEN
        RETURN 'Pediatric';
    ELSE
        RETURN 'Adult';
    END IF;
END;
$$ LANGUAGE plpgsql;

----Select query
SELECT 
    donor_age_group(age) AS age_group,
    COUNT(*) AS total_donors
FROM referrals
GROUP BY donor_age_group(age);
--------------------------------------------------------------------------------------------------------------------
--Q2 Flag whether referral happened on a weekend
--Reason Helps analyze weekend vs weekday referral patterns.

CREATE OR REPLACE FUNCTION is_weekend(ts timestamp)
RETURNS boolean AS $$
BEGIN
    RETURN EXTRACT(DOW FROM ts) IN (0, 6);
END;
$$ LANGUAGE plpgsql;
---Select Query
SELECT 
    is_weekend(time_referred) AS weekend,
    COUNT(*) AS total
FROM referrals
GROUP BY weekend;
--------------------------------------------------------------------------------------------------------------------
--Q3 How many donors fall into each 10 year age range?
--Reason : This query helps visualize the age distribution of your donor population. By grouping donors into 10 year buckets
--it becomes easy to see which age ranges contribute the most referrals
WITH RECURSIVE ages AS (
    SELECT 0 AS age
    UNION ALL
    SELECT age + 1 FROM ages WHERE age < 100
)
SELECT 
    (a.age / 10) * 10 AS age_bucket,
    COUNT(r.patientid) AS total_donors
FROM ages a
LEFT JOIN referrals r
    ON r.age = a.age
GROUP BY (a.age / 10) * 10
ORDER BY age_bucket;
--------------------------------------------------------------------------------------------------------------------
--Q4. Identify High-Performing OPOs Using Composite Score

SELECT * FROM referrals

CREATE OR REPLACE FUNCTION compute_opo_composite_score(
    approached bigINT,
    authorized bigINT,
    procured bigINT,
    transplanted bigINT
)
RETURNS NUMERIC AS $$
DECLARE
    auth_rate NUMERIC;
    proc_rate NUMERIC;
    tx_rate NUMERIC;
BEGIN
    auth_rate := CASE WHEN approached > 0 THEN authorized::NUMERIC / approached ELSE 0 END;
    proc_rate := CASE WHEN authorized > 0 THEN procured::NUMERIC / authorized ELSE 0 END;
    tx_rate   := CASE WHEN procured > 0 THEN transplanted::NUMERIC / procured ELSE 0 END;

    RETURN (0.33 * auth_rate) + (0.33 * proc_rate) + (0.34 * tx_rate);
END;
$$ LANGUAGE plpgsql;
--Select Query
SELECT
    OPO,
    COUNT(*) AS total_cases,
    SUM(approached::INT) AS approached_count,
    SUM(authorized::INT) AS authorized_count,
    SUM(procured::INT) AS procured_count,
    SUM(transplanted::INT) AS transplanted_count,
    ROUND(compute_opo_composite_score(
        SUM(approached::INT),
        SUM(authorized::INT),
        SUM(procured::INT),
        SUM(transplanted::INT)),2
    ) AS composite_score
FROM referrals
GROUP BY OPO
ORDER BY composite_score DESC;


--------------------------------------------------------------------------------------------------------------------

-- Q5.Crosstab: Race vs Authorization Status----

CREATE EXTENSION IF NOT EXISTS tablefunc;
SELECT
    race,
    authorized,
    COUNT(*) AS total
FROM referrals
GROUP BY race, authorized
ORDER BY race, authorized;

SELECT *
FROM crosstab(
    $$
    SELECT
        race,
        authorized,
        COUNT(*) AS total
    FROM referrals
    GROUP BY race, authorized
    ORDER BY race, authorized
    $$,
    $$ SELECT DISTINCT authorized FROM referrals ORDER BY authorized $$
) AS ct (
    race TEXT,
    authorized INT,
    not_authorized INT
);
--------------------------------------------------------------------------------------------------------------------
--Q6.Create a function to calculate total organs transplanted per donor---------UDF

CREATE OR REPLACE FUNCTION total_organs_transplanted(
    heart INT,
    liver INT,
    kidney_left INT,
    kidney_right INT,
    lung_left INT,
    lung_right INT,
    intestine INT,
    pancreas INT
)
RETURNS INT AS $$
BEGIN
    RETURN COALESCE(heart,0)
         + COALESCE(liver,0)
         + COALESCE(kidney_left,0)
         + COALESCE(kidney_right,0)
         + COALESCE(lung_left,0)
         + COALESCE(lung_right,0)
         + COALESCE(intestine,0)
         + COALESCE(pancreas,0);
END;
$$ LANGUAGE plpgsql;
--Select Query
SELECT
    patientid,
    (
        outcome_heart,
        outcome_liver,
        outcome_kidney_left,
        outcome_kidney_right,
        outcome_lung_left,
        outcome_lung_right,
        outcome_intestine,
        outcome_pancreas
    ) AS organs_tx
	
FROM referrals
LIMIT 20;
--------------------------------------------------------------------------------------------------------------------
--Q7. Create a trigger whenever update/insert happened in Referrals by logging the user info
create table Log_Referrals_Change
(username text,
modified_time timestamp default now(),
action_occurred text,
opo text,
hospitalid text,
patientid text
);

CREATE OR REPLACE FUNCTION capture_event_on_referrals()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        RAISE NOTICE 'Insert event fired on table %', TG_TABLE_NAME;
		insert into log_referrals_change(username,action_occurred,opo,hospitalid,patientid)
		values (current_user,TG_OP,new.opo,new.hospitalid,new.patientid);
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        RAISE NOTICE 'Update event fired on table %', TG_TABLE_NAME;

        insert into log_referrals_change(username,action_occurred,opo,hospitalid,patientid)
		values (current_user,TG_OP,new.opo,new.hospitalid,new.patientid);
        
        RETURN NEW;

    END IF;

    RETURN NULL;  
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_update
BEFORE INSERT OR UPDATE ON referrals
FOR EACH ROW
EXECUTE FUNCTION capture_event_on_referrals();

update referrals set abo_bloodtype='AB' where patientid='OPO1_P112233';
--Select Query
select * from log_referrals_change;
--------------------------------------------------------------------------------------------------------------------
--Q8. Create a trigger whenever update/insert happened in calc_deaths by logging the user info

create table Log_CalcDeaths_Change
(username text,
modified_time timestamp default now(),
action_occurred text,
opo text,
year integer
);

CREATE OR REPLACE FUNCTION capture_event_on_calcdeaths()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        RAISE NOTICE 'Insert event fired on table %', TG_TABLE_NAME;
		insert into log_calcdeaths_change(username,action_occurred,opo,year)
		values (current_user,TG_OP,new.opo,new.year);
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        RAISE NOTICE 'Update event fired on table %', TG_TABLE_NAME;

        insert into log_calcdeaths_change(username,action_occurred,opo,year)
		values (current_user,TG_OP,new.opo,new.year);
        
        RETURN NEW;

    END IF;

    RETURN NULL;  
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_insert_update_cd
BEFORE INSERT OR UPDATE ON calc_deaths
FOR EACH ROW
EXECUTE FUNCTION capture_event_on_calcdeaths();

update calc_deaths set calc_deaths_lb=1100.00, calc_deaths_ub=1300.00 where year=2026;
--Select Query
select * from Log_CalcDeaths_Change;
--------------------------------------------------------------------------------------------------------------------
-- Q9.Create Materialized view for OPO, patientid,hospitalid, organ Procured, transplanted, authorized status with time information for each organ
 
CREATE MATERIALIZED VIEW mv_organ_activity AS
WITH organ_unpivot AS (
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Heart' AS organ,
        outcome_heart AS procured_status,
        transplanted AS transplanted_status

    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Liver', 
        outcome_liver,
        transplanted
    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Kidney_Left',
        outcome_kidney_left,
        transplanted
    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Kidney_Right',
        outcome_kidney_right,
        transplanted
    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Lung_Left',
        outcome_lung_left,
        transplanted
    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Lung_Right',
        outcome_lung_right,
        transplanted
    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
       'Intestine',
        outcome_intestine,
        transplanted
    FROM referrals

    UNION ALL
    SELECT
        opo,
        patientid,
        hospitalid,
        time_procured,
        time_authorized,
        'Pancreas',
        outcome_pancreas,
        transplanted
    FROM referrals
)
SELECT *
FROM organ_unpivot order by patientid;


REFRESH MATERIALIZED VIEW mv_organ_activity;

select * from mv_organ_activity;


CREATE INDEX idx_mv_organ_activity_patient
ON mv_organ_activity (patientid);


select * from mv_organ_activity;
--------------------------------------------------------------------------------------------------------------------
--Q10. Create a function that returns donor conversion rate for a given OPO
CREATE OR REPLACE FUNCTION get_opo_conversion_rate(target_opo TEXT)
RETURNS NUMERIC AS $$
DECLARE
    conversion_rate NUMERIC;
BEGIN
    SELECT 
        CASE 
            WHEN COUNT(*) FILTER (WHERE authorized = TRUE) = 0 THEN 0
            ELSE (COUNT(*) FILTER (WHERE transplanted = TRUE AND authorized = TRUE)::NUMERIC / 
                  COUNT(*) FILTER (WHERE authorized = TRUE)::NUMERIC) * 100
        END INTO conversion_rate
    FROM referrals
    WHERE opo = target_opo;
    RETURN ROUND(conversion_rate, 2);
END;
$$ LANGUAGE plpgsql; 
--Test functions
SELECT 'OPO1' as opo_name, get_opo_conversion_rate('OPO1') AS donor_conversion_rate;
--------------------------------------------------------------------------------------------------
--Q11. Create a function that calculates time intervals between two clinical events

CREATE OR REPLACE FUNCTION calculate_clinical_interval(
    patient_id TEXT, 
    start_event TEXT, 
    end_event TEXT
) 
RETURNS INTERVAL AS $$
DECLARE
    start_ts TIMESTAMP;
    end_ts TIMESTAMP;
    result_interval INTERVAL;
BEGIN
    -- Dynamically fetch and cast the text timestamps to actual TIMESTAMP types
    EXECUTE format('SELECT %I::TIMESTAMP, %I::TIMESTAMP FROM public.referrals WHERE patientid = $1', start_event, end_event)
    INTO start_ts, end_ts
    USING patient_id;
    -- Calculate the difference
    result_interval := end_ts - start_ts;
    RETURN result_interval;
END;
$$ LANGUAGE plpgsql;
SELECT calculate_clinical_interval('OPO1_P648384', 'time_brain_death', 'time_procured');
-----------------------------------------------------------------------------------------------------------

--Q12. Return total transplants by organ type.(UDF)
--Reason: Helps us find the number of transplants based on each organ type
--creating function
CREATE OR REPLACE FUNCTION get_total_transplants(p_organ TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    total_transplants INTEGER;
BEGIN
    CASE LOWER(p_organ)
        WHEN 'heart' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_heart = 'Transplanted';
        WHEN 'liver' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_liver = 'Transplanted';
        WHEN 'kidney_left' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_kidney_left = 'Transplanted';
        WHEN 'kidney_right' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_kidney_right = 'Transplanted';
        WHEN 'lung_left' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_lung_left = 'Transplanted';
        WHEN 'lung_right' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_lung_right = 'Transplanted';
        WHEN 'pancreas' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_pancreas = 'Transplanted';
        WHEN 'intestine' THEN
            SELECT COUNT(*) INTO total_transplants
            FROM referrals
            WHERE outcome_intestine = 'Transplanted';
        ELSE
            RAISE EXCEPTION 'Invalid organ name';
    END CASE;
    RETURN total_transplants;
END;
$$;
--passing parameters to the function
SELECT get_total_transplants('heart');

SELECT get_total_transplants('liver');
--------------------------------------------------------------------------------------------------------------------
--Q13. Stored block to check the patient with most missing values in demographic and clinical columns(SP)
/*Reason: The query shows us the patient record with the least amount of demographic and clinical data filled 
so that we can identify the data entry gaps.*/
--creating a procedure to fetch least count of record a patien has
CREATE OR REPLACE PROCEDURE get_patient_with_least_demo_clinical_info(INOUT ref refcursor)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN ref FOR
    WITH info_count AS (
        SELECT
            patientid,
            ( -- Demographic
                (CASE WHEN age IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN gender = 'Not Disclosed' OR gender IS NULL THEN 1 ELSE 0 END) +
                (CASE WHEN race IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN heightin IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN weightkg IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN abo_bloodtype = 'Not Recorded' THEN 1 ELSE 0 END) +
                (CASE WHEN abo_rh = 'Not Recorded' THEN 1 ELSE 0 END) +
              -- Clinical
                (CASE WHEN cause_of_death_opo IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN cause_of_death_unos IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN mechanism_of_death IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN circumstances_of_death IS NOT NULL THEN 1 ELSE 0 END) +
                (CASE WHEN brain_death IS NOT NULL THEN 1 ELSE 0 END)
            ) AS total_filled_info
        FROM referrals    )
    SELECT *
    FROM info_count
    WHERE total_filled_info = (
        SELECT MIN(total_filled_info) FROM info_count
    );
END;
$$;

BEGIN;
CALL get_patient_with_least_demo_clinical_info('result_cursor');
FETCH ALL FROM result_cursor;
COMMIT;
--------------------------------------------------------------------------------------------------------------------
--Q14. write a trigger to insert in the audit table for changes in authorized or procured column(Trigger)
/*Reason: Because the consent changes must be traceable,  procurement status changes affect reporting,  
prevent unauthorized data manipulation,  maintain accountability,  and meet compliance standards.*/

--creating a table to record the log/audit chages
CREATE TABLE referrals_audit (
    audit_id        SERIAL,
    patientid       TEXT,
    operation_type  TEXT,              -- INSERT / UPDATE
    column_changed  TEXT,              -- authorized / procured
    old_value       BOOLEAN,
    new_value       BOOLEAN,
    changed_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	PRIMARY KEY(audit_id, patientid, changed_at)
);
--creating a function
CREATE OR REPLACE FUNCTION audit_referrals_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- INSERT LOGGING
    IF TG_OP = 'INSERT' THEN
        -- Log authorized if present
        IF NEW.authorized IS NOT NULL THEN
            INSERT INTO referrals_audit
            (patientid, operation_type, column_changed, old_value, new_value)
            VALUES
            (NEW.patientid, 'INSERT', 'authorized', NULL, NEW.authorized);
        END IF;
        -- Log procured if present
        IF NEW.procured IS NOT NULL THEN
            INSERT INTO referrals_audit
            (patientid, operation_type, column_changed, old_value, new_value)
            VALUES
            (NEW.patientid, 'INSERT', 'procured', NULL, NEW.procured);
        END IF;
    END IF;
    -- UPDATE LOGGING
    IF TG_OP = 'UPDATE' THEN
        -- authorized change
        IF NEW.authorized IS DISTINCT FROM OLD.authorized THEN
            INSERT INTO referrals_audit
            (patientid, operation_type, column_changed, old_value, new_value)
            VALUES
            (OLD.patientid, 'UPDATE', 'authorized', OLD.authorized, NEW.authorized);
        END IF;
        -- procured change
        IF NEW.procured IS DISTINCT FROM OLD.procured THEN
            INSERT INTO referrals_audit
            (patientid, operation_type, column_changed, old_value, new_value)
            VALUES
            (OLD.patientid, 'UPDATE', 'procured', OLD.procured, NEW.procured);
        END IF;

    END IF;

    RETURN NEW;
END;
$$;
--creating the trigger
CREATE TRIGGER trg_referrals_audit
AFTER INSERT OR UPDATE ON referrals
FOR EACH ROW
EXECUTE FUNCTION audit_referrals_changes();
--Updating the record in referrals table

UPDATE referrals
SET authorized = false
WHERE patientid = 'OPO1_P100388';

Select * from referrals_audit
--------------------------------------------------------------------------------------------------------------------
--Q15. Procedure to refresh yearly OPO transplant summary table(SP)
--creating a summary table
CREATE TABLE opo_yearly_transplant_summary (
    opo                 TEXT,
    year                INTEGER,
    total_donors        INTEGER,
    heart_tx            INTEGER,
    liver_tx            INTEGER,
    leftkidney_tx       INTEGER,
	rightkidney_tx      INTEGER,
    leftlung_tx         INTEGER,
	rightlung_tx        INTEGER,
    pancreas_tx         INTEGER,
    intestine_tx        INTEGER,
    last_refreshed      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (opo, year)
);
--creating a refresh procedure
CREATE OR REPLACE PROCEDURE refresh_opo_yearly_summary()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE opo_yearly_transplant_summary; -- Step 1: Clear existing summary
    INSERT INTO opo_yearly_transplant_summary ( -- Step 2: Insert refreshed aggregated data
        opo,
        year,
        total_donors,
        heart_tx,
        liver_tx,
        leftkidney_tx,
		rightkidney_tx,
        leftlung_tx,
		rightlung_tx,
        pancreas_tx,
        intestine_tx,
        last_refreshed
    )
    SELECT
        opo,
        procured_year,
        COUNT(*) FILTER (WHERE procured = TRUE) AS total_donors,
        COUNT(*) FILTER (WHERE outcome_heart = 'Transplanted') AS heart_tx,
        COUNT(*) FILTER (WHERE outcome_liver = 'Transplanted') AS liver_tx,
        COUNT(*) FILTER (WHERE outcome_kidney_left = 'Transplanted') AS leftkidney_tx, 
        COUNT(*) FILTER (WHERE outcome_kidney_right = 'Transplanted') AS rightkidney_tx,
        COUNT(*) FILTER (WHERE outcome_lung_left = 'Transplanted') AS leftlung_tx,
        COUNT(*) FILTER (WHERE outcome_lung_right = 'Transplanted') AS rightlung_tx,
        COUNT(*) FILTER (WHERE outcome_pancreas = 'Transplanted') AS pancreas_tx,
        COUNT(*) FILTER (WHERE outcome_intestine = 'Transplanted') AS intestine_tx,
        CURRENT_TIMESTAMP
    FROM referrals
    WHERE procured_year IS NOT NULL
    GROUP BY opo, procured_year;
END;
$$;

--calling the function
CALL refresh_opo_yearly_summary();

--Viewing the result 
SELECT * FROM opo_yearly_transplant_summary;














