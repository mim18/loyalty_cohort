--Compute Loyalty Score
select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;
INSERT INTO LOYALTY_COHORT (PATIENT_NUM, COHORT_NAME, INDEX_DATE)  
SELECT DISTINCT PATIENT_NUM, 'LOYALTY_COHORT_NCATS3_ALL_PTS', X.INDEXDATE 
FROM @CRC_SCHEMA.PATIENT_DIMENSION
CROSS JOIN LOYALTY_CONSTANTS X;
COMMIT;
--LOYALTY WILL NOT BE COMPUTED FOR PATIENTS UNDER 18 DUE TO CODES USED WOULD BIAS AGAINST CHILDREN

--FIND PATIENTS THAT HAVE MORE THAN DEMOGRAPHIC FACTS
--DROP TABLE LOYALTY_TMP_MORE_THAN_DEMO_FACT_PTS;
CREATE TABLE LOYALTY_TMP_MORE_THAN_DEMO_FACT_PTS AS 
SELECT * FROM (
    WITH DEM_FEATURES AS ( 
    select distinct Feature_name, concept_cd, code_type --[ACT_PATH], 
    from LOYALTY_XREF_CODE_PATHS L, CONCEPT_DIMENSION c
    where C.CONCEPT_PATH like L.ACT_PATH||'%'  
    AND code_type = 'DEM' 
    and (act_path <> '**Not Found' and act_path is not null)
    ORDER BY FEATURE_NAME)
SELECT DISTINCT PATIENT_NUM
    FROM @CRC_SCHEMA.OBSERVATION_FACT O
    WHERE CONCEPT_CD NOT IN ( SELECT CONCEPT_CD FROM DEM_FEATURES)
); 
select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;


CREATE INDEX LOYAL_MORE_THAN_DEMO_FACT_PTS ON LOYALTY_TMP_MORE_THAN_DEMO_FACT_PTS(PATIENT_NUM);
--DROP TABLE LOYALTY_TMP_COHORT_FINAL;
CREATE TABLE LOYALTY_TMP_COHORT_FINAL AS SELECT * FROM (
WITH FILTERED_PATIENTS AS (
SELECT PATIENT_NUM FROM LOYALTY_TMP_MORE_THAN_DEMO_FACT_PTS
)
SELECT F.PATIENT_NUM, COHORT_NAME, L.INDEX_DATE INDEXDATE, P.VITAL_STATUS_CD
FROM FILTERED_PATIENTS F
INNER JOIN LOYALTY_COHORT L ON L.PATIENT_NUM = F.PATIENT_NUM
INNER JOIN @CRC_SCHEMA.PATIENT_DIMENSION P ON P.PATIENT_NUM = F.PATIENT_NUM --951095
WHERE P.AGE_IN_YEARS_NUM > 18
);
select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;
--DROP TABLE LOYALTY_TMP_COHORT_IN_PERIOD;
CREATE TABLE LOYALTY_TMP_COHORT_IN_PERIOD AS
WITH COHORT_DEM AS
(
SELECT 
    C.COHORT_NAME, 
    P.PATIENT_NUM, 
    C.INDEXDATE, 
    DECODE(P.SEX_CD,'DEM|SEX:F', 'F', 'DEM|SEX:M', 'M', NULL) SEX,
    TRUNC((C.INDEXDATE - P.BIRTH_DATE)/365) AGE, -- AGE AT INDEX DATE
    C.VITAL_STATUS_CD
FROM LOYALTY_TMP_COHORT_FINAL C
JOIN @CRC_SCHEMA.PATIENT_DIMENSION P ON P.PATIENT_NUM = C.PATIENT_NUM
)
SELECT 
    C.COHORT_NAME, 
    V.PATIENT_NUM, 
    C.INDEXDATE, 
    C.SEX,
    C.AGE,
    MAX(V.START_DATE) LAST_VISIT,
    C.VITAL_STATUS_CD
FROM COHORT_DEM C
CROSS JOIN LOYALTY_CONSTANTS X
JOIN @CRC_SCHEMA.OBSERVATION_FACT V ON V.PATIENT_NUM = C.PATIENT_NUM --OR VISIT_DIMENSION
--WHERE V.START_DATE between '01-JAN-2012' and C.INDEXDATE --SQL SERVER SCRIPT
WHERE V.START_DATE between add_months( trunc(C.INDEXDATE), -12*X.LOOKBACKYEARS) and C.INDEXDATE
GROUP BY C.COHORT_NAME, V.PATIENT_NUM, C.INDEXDATE,C.AGE, C.SEX, C.VITAL_STATUS_CD ;
select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;

--SELECT * FROM LOYALTY_TMP_COHORT_IN_PERIOD; 

--commit;
--select * from LOYALTY_TMP_COHORT_IN_PERIOD;
--The cohort is any patient that has had a visit during the time period
--Get patient's last visit during time period
--DROP TABLE LOYALTY_TMP_FEA_CONC_TYPE;
grant read on ACT_VISIT_DETAILS_V4 to covid_crcdata;
CREATE TABLE LOYALTY_TMP_FEA_CONC_TYPE AS SELECT * FROM (
WITH VISIT_ONTOLOGY AS --113S
( 
SELECT * FROM @METADATA_SCHEMA.ACT_VISIT_DETAILS_V4 c -- THIS NEEDS TO POINT TO METADATA SCHEMA
),
--Get codes for observation_fact facts
SIMPLE_FEATURES AS ( 
select distinct Feature_name, concept_cd, code_type --[ACT_PATH], 
from LOYALTY_XREF_CODE_PATHS L, CONCEPT_DIMENSION c
where C.CONCEPT_PATH like L.Act_path||'%'  
--AND FEATURE_NAME = 'PapTest' quick test
AND code_type IN ('DX','PX','LAB','MEDS','SITE','DEM') 
and (act_path <> '**Not Found' and act_path is not null)
ORDER BY FEATURE_NAME),

-- Get codes for visit_dimension facts
VISIT_FEATURES AS ( 
select distinct FEATURE_NAME, C_BASECODE CONCEPT_CD, code_type  
from LOYALTY_XREF_CODE_PATHS L, VISIT_ONTOLOGY C
where C.C_FULLNAME like L.Act_path||'%'  
AND code_type IN ('VISIT') 
and (act_path <> '**Not Found' and act_path is not null)
ORDER BY FEATURE_NAME),-- select * from visit_features;--, 

-- Get codes for visit_dimension facts
MD_VISIT_FEATURES AS ( 
select distinct FEATURE_NAME, CONCEPT_CD, code_type  
from LOYALTY_XREF_CODE_PATHS L, CONCEPT_DIMENSION c -- THIS NEEDS TO POINT TO METADATA SCHEMA
where C.CONCEPT_PATH like L.Act_path||'%'  
AND UPPER(feature_name) in ('MDVISIT_PNAME2', 'MDVISIT_PNAME3')
and (act_path <> '**Not Found' and act_path is not null)
--and (provider_id <> '@' and provider_id is not null)
ORDER BY FEATURE_NAME),-- select * from MD_VISIT_FEATURES;--,

--routine_care_2 is two of any of the following features
--('MedicalExam','Mammography','PSATest','Colonoscopy','FecalOccultTest','FluShot','PneumococcalVaccine','A1C','BMI')
ROUTINE_CARE_codes AS (
select distinct Feature_name, concept_cd, code_type --[ACT_PATH], 
from LOYALTY_XREF_CODE_PATHS L, CONCEPT_DIMENSION c
where C.CONCEPT_PATH like L.Act_path||'%'  
AND feature_name IN ('MedicalExam','Mammography','PSATest','Colonoscopy','FecalOccultTest','FluShot','PneumococcalVaccine','A1C','BMI' ) 
and (act_path <> '**Not Found' and act_path is not null)
ORDER BY FEATURE_NAME
),-- select * from ROUTINE_CARE_codes;
--Create a routine care feature 
ROUTINE_CARE_FEATURES AS
(
select 'Routine_Care_2' feature_name, concept_cd, code_type  from ROUTINE_CARE_codes
),-- select * from ROUTINE_CARE_FEATURES; --,
-- Add routine_care_2 to the list of features
FEATURES AS 
(
select feature_name, concept_cd, code_type  from ROUTINE_CARE_FEATURES
union 
select feature_name, concept_cd, code_type  from SIMPLE_FEATURES
union 
select feature_name, concept_cd, code_type  from VISIT_FEATURES
union 
select feature_name, concept_cd, code_type  from MD_VISIT_FEATURES
)
select * from FEATURES);
select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;

CREATE INDEX LOYALTY_TMP_FEA_CONC_TYPE_INDEX1 ON LOYALTY_TMP_FEA_CONC_TYPE(CONCEPT_CD);
CREATE INDEX LOYALTY_TMP_FEA_CONC_TYPE_INDEX2 ON LOYALTY_TMP_FEA_CONC_TYPE(FEATURE_NAME);
CREATE INDEX LOYALTY_TMP_FEA_CONC_TYPE_INDEX3 ON LOYALTY_TMP_FEA_CONC_TYPE(CODE_TYPE);
--DROP TABLE LOYALTY_TMP_COHORT_LONG;
CREATE TABLE LOYALTY_TMP_COHORT_LONG AS 
SELECT * FROM (
WITH PT_DEM_FEATURE_COUNT_BY_DATE AS ( 
SELECT LC.PATIENT_NUM, FEATURE_NAME,  COUNT(DISTINCT TRUNC(O.START_DATE)) DISTINCT_ENCOUNTERS, COEFF
FROM LOYALTY_TMP_COHORT_IN_PERIOD LC
JOIN @CRC_SCHEMA.OBSERVATION_FACT O ON O.PATIENT_NUM = LC.PATIENT_NUM
JOIN LOYALTY_TMP_FEA_CONC_TYPE F ON F.CONCEPT_CD = O.CONCEPT_CD
JOIN LOYALTY_XREF_CODE_PSCOEFF C ON C.FIELD_NAME = F.FEATURE_NAME
WHERE FEATURE_NAME = 'Demographics' 
GROUP BY LC.PATIENT_NUM, FEATURE_NAME, C.COEFF
ORDER BY LC.PATIENT_NUM, FEATURE_NAME
),
--Get visit counts and the coefficients
PT_VIS_FEATURE_COUNT_BY_DATE AS ( -- VISIT WITHIN TIME FRAME OF INTEREST
SELECT LC.PATIENT_NUM, FEATURE_NAME,  COUNT(DISTINCT TRUNC(V.START_DATE)) DISTINCT_ENCOUNTERS, C.COEFF
FROM LOYALTY_TMP_COHORT_IN_PERIOD LC
JOIN @CRC_SCHEMA.VISIT_DIMENSION V ON V.PATIENT_NUM = LC.PATIENT_NUM
JOIN LOYALTY_TMP_FEA_CONC_TYPE F ON F.CONCEPT_CD = V.INOUT_CD 
JOIN LOYALTY_XREF_CODE_PSCOEFF C ON C.FIELD_NAME = F.FEATURE_NAME
CROSS JOIN LOYALTY_CONSTANTS x
WHERE CODE_TYPE = 'VISIT' AND 
V.START_DATE between add_months( trunc(LC.INDEXDATE), -12*X.LOOKBACKYEARS) and LC.INDEXDATE 
GROUP BY LC.PATIENT_NUM, FEATURE_NAME, C.COEFF
ORDER BY LC.PATIENT_NUM, FEATURE_NAME
),
-- Adjust the outpatient visit coeff. Make it zero if outpatient visits less than 2
ADJ_PT_VIS_FEATURE_COUNT_BY_DATE as (
SELECT PATIENT_NUM, 
FEATURE_NAME, 
DISTINCT_ENCOUNTERS,
CASE 
    WHEN FEATURE_NAME = 'OPT2_Visit' AND DISTINCT_ENCOUNTERS < 2 THEN 0
    ELSE COEFF
END COEFF
FROM PT_VIS_FEATURE_COUNT_BY_DATE
),
--Get the observation_fact feature counts and the coefficients
PT_FEATURE_COUNT_BY_DATE AS (
SELECT LC.PATIENT_NUM, FEATURE_NAME,  COUNT(DISTINCT TRUNC(O.START_DATE)) DISTINCT_ENCOUNTERS, COEFF
FROM LOYALTY_TMP_COHORT_IN_PERIOD LC
CROSS JOIN LOYALTY_CONSTANTS x
JOIN @CRC_SCHEMA.OBSERVATION_FACT O ON O.PATIENT_NUM = LC.PATIENT_NUM
JOIN LOYALTY_TMP_FEA_CONC_TYPE F ON F.CONCEPT_CD = O.CONCEPT_CD
JOIN LOYALTY_XREF_CODE_PSCOEFF C ON C.FIELD_NAME = F.FEATURE_NAME
WHERE TRUNC(O.START_DATE) between add_months( LC.INDEXDATE, -12*X.LOOKBACKYEARS) and LC.INDEXDATE AND F.CODE_TYPE <> 'VISIT'
GROUP BY LC.PATIENT_NUM, FEATURE_NAME, C.COEFF
ORDER BY LC.PATIENT_NUM, FEATURE_NAME
),
--Adjust procedure visits since they need to have 2 or 3 and they require non null providers. 
--If they do not satisfy those conditions the coeff is zero and the feature will be omitted
MD_PX_VISITS_WITH_PROVIDER as (
SELECT PATIENT_NUM, 
FEATURE_NAME, 
DISTINCT_ENCOUNTERS,
CASE 
    WHEN UPPER(FEATURE_NAME) = 'MDVISIT_PNAME2' AND DISTINCT_ENCOUNTERS <> 2  THEN 0
    WHEN UPPER(FEATURE_NAME) = 'MDVISIT_PNAME3' AND DISTINCT_ENCOUNTERS < 3 THEN 0
    ELSE COEFF
END COEFF,
COEFF OLD_COEFF
FROM PT_FEATURE_COUNT_BY_DATE
),
--Adjust the rest of the count based features when condition is not met coeff = 0
-- can this be reordered so all of these are in one block
ADJ_PT_FEATURE_COUNT_BY_DATE as (
SELECT PATIENT_NUM, 
FEATURE_NAME, 
DISTINCT_ENCOUNTERS,
CASE 
    WHEN FEATURE_NAME = 'Routine_Care_2' AND DISTINCT_ENCOUNTERS < 2 THEN 0
    WHEN FEATURE_NAME = 'Num_DX1' AND DISTINCT_ENCOUNTERS > 1 THEN 0
    WHEN FEATURE_NAME = 'MedUse1' AND DISTINCT_ENCOUNTERS > 1 THEN 0
    WHEN FEATURE_NAME = 'Num_DX2' AND DISTINCT_ENCOUNTERS < 2 THEN 0
    WHEN FEATURE_NAME = 'MedUse2' AND DISTINCT_ENCOUNTERS < 2 THEN 0
    ELSE COEFF
END COEFF,
COEFF OLD_COEFF
FROM MD_PX_VISITS_WITH_PROVIDER
),
--merge all features from demographics (always zero coeff) + visit based features + observation_fact based features
ALL_FEATURE_COUNT_BY_DATE AS (
select PATIENT_NUM, FEATURE_NAME, DISTINCT_ENCOUNTERS, COEFF from (
select PATIENT_NUM, FEATURE_NAME, DISTINCT_ENCOUNTERS, COEFF from ADJ_PT_FEATURE_COUNT_BY_DATE
union 
select PATIENT_NUM, FEATURE_NAME, DISTINCT_ENCOUNTERS, COEFF from PT_DEM_FEATURE_COUNT_BY_DATE
union 
select PATIENT_NUM, FEATURE_NAME, DISTINCT_ENCOUNTERS, COEFF from ADJ_PT_VIS_FEATURE_COUNT_BY_DATE
)
--order by patient_num
) 
select * from ALL_FEATURE_COUNT_BY_DATE);

select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;

create index LOYALTY_TMP_COHORT_LONG_index1 on LOYALTY_TMP_COHORT_LONG(patient_num);

-- Sum coefficients per patient for predicted score
--DROP TABLE LOYALTY_TMP_COEFF_SUMS;
create table LOYALTY_TMP_COEFF_SUMS as --5s
select patient_num, 
SUM(COEFF) AS RAW_COEFF, -- used to determine facts that have none of the features coeff exactly zero
-0.010+SUM(COEFF) as sum_of_coeff
from LOYALTY_TMP_COHORT_LONG --ALL_FEATURE_COUNT_BY_DATE
group by patient_num;
select TO_CHAR (sysdate, 'MON DD HH24:MI:SS') from dual;

-- QUICK CHECK
select EXTRACT(YEAR FROM  last_visit) last_visit_year, count(*) cnt 
from LOYALTY_TMP_COHORT_IN_PERIOD
group by EXTRACT(YEAR FROM  last_visit);

select EXTRACT(YEAR FROM  INDEX_DATE) last_visit_year, count(*) cnt 
from LOYALTY_COHORT
group by EXTRACT(YEAR FROM  INDEX_DATE)
order by 1;

--select * from LOYALTY_TMP_COHORT_LONG where patient_num = 2631;
select * from LOYALTY_TMP_COEFF_SUMS where patient_num = 2631;
--select * from COEFF_SUMS where patient_num = 2631;
select * from LOYALTY_SCORE_BY_PATIENT where patient_num = 2631;
select * from LOYALTY_SCORE_BY_PATIENT where SUBJECTS_NOCRITERIA = 1;


--select sum_of_coeff, count(*) freq from coeff_sums group by sum_of_coeff order by count(*) desc;
--CREATE TABLE LOYALTY_TMP_COHORT_BY_AGEGRP AS 
--DROP TABLE LOYALTY_SCORE_BY_PATIENT;
CREATE TABLE LOYALTY_SCORE_BY_PATIENT AS --1MIN
select * from (
--Pivot the rows to columns - make the WIDE table
with CTE_PIVOT_PATIENTS AS 
(
SELECT * FROM 
  ( 
    SELECT patient_num,  feature_name, case when coeff <> 0 then 1 else 0 end coeff -- with coeffs turned to flags
    FROM LOYALTY_TMP_COHORT_LONG --ALL_FEATURE_COUNT_BY_DATE 
  ) 
  PIVOT ( 
    MAX(coeff) 
    FOR feature_name in
        ('Demographics' demographics,
        'MD visit' MD_visit,
        'Num_DX1' Num_DX1,
        'Num_DX2' Num_DX2,
        'MedUse1' MedUse1,
        'MedUse2' MedUse2,
        'MedicalExam' MedicalExam,
        'MDVisit_pname2' MDVisit_pname2,
        'MDVisit_pname3' MDVisit_pname3,
        'Mammography' Mammography,
        'BMI' BMI,
        'FluShot' FluShot,
        'PneumococcalVaccine' PneumococcalVaccine,
        'FecalOccultTest' FecalOccultTest,
        'PapTest' Paptest,
        'Colonoscopy' Colonoscopy,
        'PSATest' PSATest,
        'A1C' A1C,
        'Routine_Care_2' Routine_Care_2,
        'ED_Visit' ED_Visit,
        'INP1_OPT1_Visit' INP1_OPT1_Visit,
        'OPT2_Visit' OPT2_Visit
        ))
),

--Start building the final table
PREDICTIVE_SCORE AS 
(
select 
V.COHORT_NAME,
S.PATIENT_NUM,
V.INDEXDATE,
case when raw_coeff = 0 then 1 else 0 end as Subjects_NoCriteria,
--raw_coeff as Subjects_NoCriteria,  when showing full coeff
nvl(sum_of_coeff,0) AS Predicted_score,
last_visit AS LAST_VISIT,
D.BIRTH_DATE,
TRUNC(NVL(((V.INDEXDATE-TRUNC(D.BIRTH_DATE))/365.25), 0)) AGE,
CASE WHEN TRUNC(NVL(((V.INDEXDATE-TRUNC(D.BIRTH_DATE))/365.25), 0)) < 65 THEN 'Under 65'
     WHEN TRUNC(NVL(((V.INDEXDATE-TRUNC(D.BIRTH_DATE))/365.25), 0)) >= 65 THEN 'Over 65'
     ELSE NULL
     END AGEGRP,
decode(D.SEX_CD,'DEM|SEX:F', 'F', 'DEM|SEX:M', 'M', NULL) SEX_CD,
nvl(Num_Dx1    ,0)          AS Num_Dx1            
,nvl(Num_Dx2    ,0)          AS Num_Dx2            
,nvl(MedUse1    ,0)          AS MedUse1            
,nvl(MedUse2    ,0)          AS MedUse2            
,nvl(Mammography,0)          AS Mammography        
,nvl(PapTest    ,0)          AS PapTest            
,nvl(PSATest    ,0)          AS PSATest            
,nvl(Colonoscopy,0)          AS Colonoscopy        
,nvl(FecalOccultTest,0)      AS FecalOccultTest    
,nvl(FluShot    ,0)          AS FluShot            
,nvl(PneumococcalVaccine,0)  AS PneumococcalVaccine
,nvl(BMI        ,0)          AS BMI                
,nvl(A1C        ,0)          AS A1C                
,nvl(MedicalExam,0)          AS MedicalExam        
,nvl(INP1_OPT1_Visit,0)      AS INP1_OPT1_Visit    
,nvl(OPT2_Visit ,0)          AS OPT2_Visit      
,nvl(ED_Visit   ,0)          AS ED_Visit           
,nvl(MDVisit_pname2,0)       AS MDVisit_pname2     
,nvl(MDVisit_pname3,0)       AS MDVisit_pname3     
,nvl(Routine_Care_2,0)       AS Routine_Care_2     
from @CRC_SCHEMA.LOYALTY_TMP_COHORT_IN_PERIOD V 
LEFT JOIN @CRC_SCHEMA.LOYALTY_TMP_COEFF_SUMS S ON S.PATIENT_NUM = V.PATIENT_NUM
LEFT JOIN @CRC_SCHEMA.PATIENT_DIMENSION D ON D.PATIENT_NUM = S.PATIENT_NUM
LEFT JOIN CTE_PIVOT_PATIENTS P ON P.PATIENT_NUM = S.PATIENT_NUM
), 
-- get patient totals - subjects without any criteria have been filtered out - is this correct? TODO: Check in the meeting
TOTAL_PATIENTS AS 
(
select count(distinct patient_num) TOTAL_PATIENT from PREDICTIVE_SCORE -- where Subjects_NoCriteria = 0
),
TOTAL_PATIENTS_FEMALE AS 
(
select count(distinct patient_num) TOTAL_PATIENT_FEMALE from PREDICTIVE_SCORE where SEX_CD = 'F' --  and Subjects_NoCriteria = 0
),
TOTAL_PATIENTS_MALE AS 
(
select count(distinct patient_num) TOTAL_PATIENT_MALE from PREDICTIVE_SCORE where SEX_CD =  'M' -- and Subjects_NoCriteria = 0
),
TOTAL_NO_CRITERIA AS 
(
select count(distinct patient_num) TOTAL_NO_CRITERIA from PREDICTIVE_SCORE where Subjects_NoCriteria = 1
)
--select *  from PREDICTIVE_SCORE where patient_num = 2631  ;
--Final table
SELECT
    COHORT_NAME,
    p.patient_num,
    INDEXDATE,
    birth_date,
    Subjects_NoCriteria,
    predicted_score,
    TOTAL_NO_CRITERIA,
    TOTAL_PATIENT,
    TOTAL_PATIENT_MALE,
    TOTAL_PATIENT_FEMALE,
    last_visit,
    age,
    agegrp,
    sex_cd,
    num_dx1,
    num_dx2,
    meduse1,
    meduse2,
    mammography,
    paptest,
    psatest,
    colonoscopy,
    fecalocculttest,
    flushot,
    pneumococcalvaccine,
    bmi,
    a1c,
    medicalexam,
    inp1_opt1_visit,
    opt2_visit,
    ed_visit,
    mdvisit_pname2,
    mdvisit_pname3,
    routine_care_2
FROM
    PREDICTIVE_SCORE p
    CROSS JOIN TOTAL_PATIENTS
    CROSS JOIN TOTAL_PATIENTS_MALE
    CROSS JOIN TOTAL_PATIENTS_FEMALE
    CROSS JOIN TOTAL_NO_CRITERIA
); --END CREATE TABLE LOYALTY_SCORE_BY_PATIENT

--SELECT * FROM LOYALTY_SCORE_BY_PATIENT order by patient_num desc; --420199
