-- THESE TABLES CALCULATE LOYALTY SCORE STATS - THIS IS OPTIONAL - NOT NECESSARY FOR MLHO OR PASC Project
-- ALL PATIENTS
CREATE TABLE LOYALTY_TMP_COHORT_AGEGRP AS 
SELECT
    COHORT_NAME,
    patient_num,
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
    'All Patients' as agegrp,
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
FROM LOYALTY_SCORE_BY_PATIENT;

SELECT COUNT(*) ALL_PATIENTS FROM LOYALTY_TMP_COHORT_AGEGRP; --ALL PATIENTS

--BY AGEGROUP
INSERT INTO LOYALTY_TMP_COHORT_AGEGRP
SELECT
    COHORT_NAME,
    patient_num,
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
FROM LOYALTY_SCORE_BY_PATIENT;
COMMIT;
SELECT COUNT(*) ALL_PATIENTS_AND_AGEGRP FROM LOYALTY_TMP_COHORT_AGEGRP; --4945626


-- Calculate Predictive Score Cutoff by over Agegroups and DECILEs
CREATE TABLE LOYALTY_TMP_AGEGRP_PSC AS SELECT COHORT_NAME, AGEGRP, MIN(PREDICTED_SCORE) PredictiveScoreCutoff
FROM (
SELECT COHORT_NAME, AGEGRP, Predicted_score, NTILE(10) OVER (PARTITION BY COHORT_NAME, AGEGRP ORDER BY PREDICTED_SCORE DESC) AS ScoreRank
FROM(
SELECT COHORT_NAME, AGEGRP, predicted_score
from LOYALTY_TMP_COHORT_AGEGRP
)SCORES
)M
WHERE ScoreRank=1
GROUP BY COHORT_NAME, AGEGRP;
COMMIT;

select COUNT(*) from LOYALTY_TMP_AGEGRP_PSC;

-- Calculate average fact counts over Agegroups 
CREATE TABLE LOYALTY_TMP_AGEGRP_AFC AS 
SELECT COHORT_NAME, CUTOFF_FILTER_YN, AGEGRP, TRUNC(AVG_FACT_COUNT,2) AVG_FACT_CNT
FROM
(
SELECT CAG.COHORT_NAME, CAST('N' AS CHAR(1)) AS CUTOFF_FILTER_YN, cag.AGEGRP, 1.0*count(o.concept_cd)/count(distinct cag.patient_num) as AVG_FACT_COUNT
FROM LOYALTY_TMP_COHORT_AGEGRP cag
CROSS JOIN LOYALTY_CONSTANTS x
  join @CRC_CHEMA.OBSERVATION_FACT O  ON cag.patient_num = O.PATIENT_NUM
WHERE    O.START_DATE between add_months( trunc(CAG.INDEXDATE), -12*X.LOOKBACKYEARS) and CAG.INDEXDATE
group by CAG.COHORT_NAME, cag.AGEGRP
UNION ALL
SELECT CAG.COHORT_NAME, CAST('Y' AS CHAR(1)) AS CUTOFF_FILTER_YN, cag.AGEGRP, 
1.0*count(o.concept_cd)/count(distinct cag.patient_num) as AVG_FACT_COUNT
FROM LOYALTY_TMP_COHORT_AGEGRP cag
CROSS JOIN LOYALTY_CONSTANTS x
  JOIN LOYALTY_TMP_AGEGRP_PSC PSC
    ON cag.AGEGRP = PSC.AGEGRP
      AND cag.Predicted_score >= PSC.PredictiveScoreCutoff
  join @CRC_CHEMA.OBSERVATION_FACT O
    ON cag.patient_num = O.PATIENT_NUM
WHERE    O.START_DATE between add_months( trunc(CAG.INDEXDATE), -12*X.LOOKBACKYEARS) and CAG.INDEXDATE
group by CAG.COHORT_NAME, cag.AGEGRP
)AFC;
COMMIT;

SELECT COUNT(*) FROM LOYALTY_TMP_AGEGRP_AFC;
--***********************************************************************************************************

--TODO: make this conditional
-- create summary table
--Create temp table cohortagg
--select * from LOYALTY_TMP_COHORT_AGEGRP where subjects_nocriteria = 0;
--delete table LOYALTY_COHORT_AGG;
declare
v_sql LONG;
begin

v_sql:='create table LOYALTY_COHORT_AGG
(
    COHORT_NAME varchar2(30) NULL,
    CUTOFF_FILTER_YN char(1) NOT NULL,
    Summary_Description varchar(20) NOT NULL,
	agegrp varchar(20) NULL,
    totalsubjects number NULL,
	Num_DX1 number NULL,
	Num_DX2 number NULL,
	MedUse1 number NULL,
	MedUse2 number NULL,
	Mammography number NULL,
	PapTest number NULL,
    PSATest number NULL,
    Colonoscopy number NULL,
    FecalOccultTest number NULL,
    FluShot number NULL,
    PneumococcalVaccine number NULL,
    BMI number NULL,
    A1C number NULL,
    MedicalExam number NULL,
    INP1_OPT1_Visit number NULL,
    OPT2_Visit number NULL,
    ED_Visit number NULL,
    MDVisit_pname2 number NULL,
    MDVisit_pname3 number NULL,
    Routine_care_2 number NULL,
    Subjects_NoCriteria number NULL,
    TotalSubjectsFemale number NULL,
    TotalSubjectsMale number NULL)';

execute immediate v_sql;

EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -955 THEN
        NULL; -- suppresses ORA-00955 exception
      ELSE
         RAISE;
      END IF;
END;
/    
-- INSERT PATIENT COUNTS FILTERED OVER/UNDER
--TRUNCATE TABLE LOYALTY_COHORT_AGG;
--COMMIT;
--SELECT * FROM LOYALTY_COHORT_AGG ORDER BY SUMMARY_DESCRIPTION, AGEGRP;
insert into LOYALTY_COHORT_AGG
SELECT
CAG.COHORT_NAME,
'Y' AS CUTOFF_FILTER_YN,
'Patient Counts' as Summary_Description,
CAG.AGEGRP agegrp, 
count(distinct patient_num) as TotalSubjects,
sum(Num_DX1) as Num_DX1,
sum(Num_DX2) as Num_DX2,
sum(MedUse1)  as MedUse1,
sum(MedUse2)  as MedUse2,
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN  Mammography  
           WHEN X.GENDERED=0 THEN Mammography ELSE NULL END ) AS Mammography,
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN PapTest 
           WHEN X.GENDERED=0 THEN PapTest ELSE NULL END ) AS PapTest,
sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN PSATEST 
           WHEN X.GENDERED=0 THEN PSATEST ELSE NULL END) AS PSATEST,
sum(Colonoscopy)  as Colonoscopy,
sum(FecalOccultTest)  as FecalOccultTest,
sum(FluShot)  as FluShot,
sum(PneumococcalVaccine)  as PneumococcalVaccine,
sum(BMI)  as BMI,
sum(A1C)  as A1C,
sum(MedicalExam)  as MedicalExam,
sum(INP1_OPT1_Visit)  as INP1_OPT1_Visit,
sum(OPT2_Visit)  as OPT2_Visit,
sum(ED_Visit)  as ED_Visit,
sum(MDVisit_pname2)  as MDVisit_pname2,
sum(MDVisit_pname3)  as MDVisit_pname3,
sum(Routine_Care_2)  as Routine_Care_2,
sum(Subjects_NoCriteria) as Subjects_NoCriteria, 
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN 1 END) AS TotalSubjectsFemale,
sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN 1 END) AS TotalSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG 
CROSS JOIN LOYALTY_CONSTANTS X
JOIN LOYALTY_TMP_AGEGRP_PSC P ON CAG.AGEGRP = P.AGEGRP AND CAG.Predicted_score >= P.PredictiveScoreCutoff
group by CAG.COHORT_NAME, CAG.AGEGRP;
COMMIT;

-- INSERT PATIENT PERCENT FILTERED OVER/UNDER
INSERT INTO LOYALTY_COHORT_AGG
SELECT
CAG.COHORT_NAME,
'Y' AS CUTOFF_FILTER_YN,
'PercentOfSubjects' as Summary_Description,
CAG.AGEGRP, 
count(distinct patient_num) as TotalSubjects,
100*avg(Num_Dx1) as Num_DX1,
100*avg(Num_Dx2) as Num_DX2,
100*avg(MedUse1)  as MedUse1,
100*avg(MedUse2) as MedUse2,
100*avg(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN  Mammography  
           WHEN X.GENDERED=0 THEN Mammography ELSE NULL END ) AS Mammography,
100*avg(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN PapTest 
           WHEN X.GENDERED=0 THEN PapTest ELSE NULL END ) AS PapTest,
100*avg(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN PSATEST 
           WHEN X.GENDERED=0 THEN PSATEST ELSE NULL END) AS PSATEST,
100*avg(Colonoscopy) as Colonoscopy,
100*avg(FecalOccultTest) as FecalOccultTest,
100*avg(FluShot) as  FluShot,
100*avg(PneumococcalVaccine) as PneumococcalVaccine,
100*avg(BMI)  as BMI,
100*avg(A1C) as A1C,
100*avg(MedicalExam) as MedicalExam,
100*avg(INP1_OPT1_Visit) as INP1_OPT1_Visit,
100*avg(OPT2_Visit) as OPT2_Visit,
100*avg(ED_Visit)  as ED_Visit,
100*avg(MDVisit_pname2) as MDVisit_pname2,
100*avg(MDVisit_pname3) as MDVisit_pname3,
100*avg(Routine_Care_2) as Routine_care_2,
100*avg(Subjects_NoCriteria) as Subjects_NoCriteria,  
count(CASE WHEN sex_cd='F' THEN  patient_num ELSE NULL END) AS TotalSubjectsFemale,
count(CASE WHEN sex_cd='M' THEN  patient_num ELSE NULL END) AS TotalSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG 
CROSS JOIN LOYALTY_CONSTANTS X
JOIN LOYALTY_TMP_AGEGRP_PSC P ON CAG.AGEGRP = P.AGEGRP AND CAG.Predicted_score >= P.PredictiveScoreCutoff
group by CAG.COHORT_NAME, CAG.AGEGRP;

COMMIT;
--SELECT * FROM LOYALTY_COHORT_AGG;

-- INSERT PATIENT COUNTS UNFILTERED OVER/UNDER

INSERT INTO LOYALTY_COHORT_AGG
--UNFILTERED -- ALL QUINTILES 
SELECT
CAG.COHORT_NAME,
'N' AS CUTOFF_FILTER_YN,
'Patient Counts' as Summary_Description,
CAG.AGEGRP, 
count(distinct patient_num) as TotalSubjects,
sum(Num_Dx1) as Num_DX1,
sum(Num_Dx2) as Num_DX2,
sum(MedUse1)  as MedUse1,
sum(MedUse2) as MedUse2,
SUM(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN Mammography 
           WHEN X.GENDERED=0 THEN Mammography  ELSE NULL END) AS Mammography,
SUM(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN  PapTest 
           WHEN X.GENDERED=0 THEN PapTest ELSE NULL END) AS PapTest,
SUM(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN PSATEST 
           WHEN X.GENDERED=0 THEN PSATEST  ELSE NULL END) AS PSATEST,
sum(Colonoscopy) as Colonoscopy,
sum(FecalOccultTest) as FecalOccultTest,
sum(FluShot) as  FluShot,
sum(PneumococcalVaccine) as PneumococcalVaccine,
sum(BMI)  as BMI,
sum(A1C) as A1C,
sum(MedicalExam) as MedicalExam,
sum(INP1_OPT1_Visit) as INP1_OPT1_Visit,
sum(OPT2_Visit) as OPT2_Visit,
sum(ED_Visit)  as ED_Visit,
sum(MDVisit_pname2) as MDVisit_pname2,
sum(MDVisit_pname3) as MDVisit_pname3,
sum(Routine_Care_2) as Routine_care_2,
SUM(Subjects_NoCriteria) as Subjects_NoCriteria, --inverted bitwise OR of all bit flags 
count(CASE WHEN sex_cd='F' THEN  patient_num ELSE NULL END) AS TotalSubjectsFemale,
count(CASE WHEN sex_cd='M' THEN  patient_num ELSE NULL END) AS TotalSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG
CROSS JOIN LOYALTY_CONSTANTS X
group by CAG.COHORT_NAME, CAG.AGEGRP;
COMMIT;
--SELECT * FROM LOYALTY_COHORT_AGG;
-- INSERT PATIENT PERCENTS FILTERED OVER/UNDER

INSERT INTO LOYALTY_COHORT_AGG
SELECT
CAG.COHORT_NAME,
'N' AS PREDICTIVE_CUTOFF_FILTER_YN,
'PercentOfSubjects' as Summary_Description,
CAG.AGEGRP, 
count(distinct patient_num) as TotalSubjects,
100*avg(Num_Dx1) as Num_DX1,
100*avg(Num_Dx2) as Num_DX2,
100*avg(MedUse1)  as MedUse1,
100*avg(MedUse2) as MedUse2,
100*AVG(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN Mammography 
           WHEN X.GENDERED=0 THEN Mammography  ELSE NULL END) AS Mammography,
100*AVG(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN  PapTest 
           WHEN X.GENDERED=0 THEN PapTest ELSE NULL END) AS PapTest,
100*AVG(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN PSATEST 
           WHEN X.GENDERED=0 THEN PSATEST  ELSE NULL END) AS PSATEST,
100*avg(Colonoscopy) as Colonoscopy,
100*avg(FecalOccultTest) as FecalOccultTest,
100*avg(FluShot) as  FluShot,
100*avg(PneumococcalVaccine) as PneumococcalVaccine,
100*avg(BMI)  as BMI,
100*avg(A1C) as A1C,
100*avg(MedicalExam) as MedicalExam,
100*avg(INP1_OPT1_Visit) as INP1_OPT1_Visit,
100*avg(OPT2_Visit) as OPT2_Visit,
100*avg(ED_Visit)  as ED_Visit,
100*avg(MDVisit_pname2) as MDVisit_pname2,
100*avg(MDVisit_pname3) as MDVisit_pname3,
100*avg(Routine_Care_2) as Routine_care_2,
SUM(Subjects_NoCriteria) as Subjects_NoCriteria,  
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN 1 END) AS TotalSubjectsFemale,
sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN 1 END) AS TotalSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG
CROSS JOIN LOYALTY_CONSTANTS X
group by CAG.COHORT_NAME, CAG.AGEGRP;  -- 4 unioned
COMMIT;
SELECT * FROM LOYALTY_COHORT_AGG;

--TRUNCATE TABLE loyalty_dev_summary;
--TRUNCATE TABLE loyalty_dev_summary_PRELIM;
--  , CASE WHEN COHORTAGG.CUTOFF_FILTER_YN = 'Y' THEN CP.PredictiveScoreCutoff ELSE NULL END AS PredictiveScoreCutoff

-- START BUILDING THE SUMMARY TABLE
insert into loyalty_dev_summary_PRELIM
SELECT 
cag.cohort_name, 
X.SITE,
X.LOOKBACKYEARS,
CASE WHEN X.GENDERED=1 THEN 'Y' ELSE 'N'END AS GENDER_DENOMINATORS_YN,
'Y' AS CUTOFF_FILTER_YN,
'Patient Counts' as Summary_Description,
CAG.AGEGRP as tablename, 
count(patient_num) as TotalSubjects,
sum(cast(Num_Dx1 as int)) as Num_DX1,
sum(cast(Num_Dx2 as int)) as Num_DX2,
sum(cast(MedUse1 as int))  as MedUse1,
sum(cast(MedUse2 as int)) as MedUse2,
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN mammography ELSE 0 END) AS Mammography,
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN paptest ELSE 0 END) AS paptest,
sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN psatest ELSE 0 END) AS psatest,
sum(cast(Colonoscopy as int)) as Colonoscopy,
sum(cast(FecalOccultTest as int)) as FecalOccultTest,
sum(cast(FluShot as int)) as  FluShot,
sum(cast(PneumococcalVaccine as int)) as PneumococcalVaccine,
sum(cast(BMI as int))  as BMI,
sum(cast(A1C as int)) as A1C,
sum(cast(MedicalExam as int)) as MedicalExam,
sum(cast(INP1_OPT1_Visit as int)) as INP1_OPT1_Visit,
sum(cast(OPT2_Visit as int)) as OPT2_Visit,
sum(cast(ED_Visit as int))  as ED_Visit,
sum(cast(MDVisit_pname2 as int)) as MDVisit_pname2,
sum(cast(MDVisit_pname3 as int)) as MDVisit_pname3,
sum(cast(Routine_Care_2 as int)) as Routine_care_2,
SUM(Subjects_NoCriteria) as Subjects_NoCriteria,

SUM(Subjects_NoCriteria) MEAN_10YRPROB, 
SUM(Subjects_NoCriteria) MEDIAN_10YR_SURVIVAL, 
SUM(Subjects_NoCriteria) MODE_10YRPROB, 
SUM(Subjects_NoCriteria)STDEV_10YRPROB, 
sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END) AS TotalSubjectsFemale,
sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END) AS TotalSubjectsMale,
trunc(sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END) / count(patient_num)) AS PercentSubjectsFemale,
trunc(sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END) / count(patient_num)) AS PercentSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG 
CROSS JOIN LOYALTY_CONSTANTS X
JOIN LOYALTY_TMP_AGEGRP_PSC P ON CAG.AGEGRP = P.AGEGRP AND CAG.Predicted_score >= P.PredictiveScoreCutoff AND CAG.cohort_name = P.cohort_name
group by CAG.cohort_name, CAG.AGEGRP, X.SITE, X.LOOKBACKYEARS, X.GENDERED;

commit;

insert into loyalty_dev_summary_PRELIM
SELECT 
cag.cohort_name, 
X.SITE,
X.LOOKBACKYEARS,
CASE WHEN X.GENDERED=1 THEN 'Y' ELSE 'N'END AS GENDER_DENOMINATORS_YN,
'Y' AS CUTOFF_FILTER_YN,
'Percent Of Subjects' as Summary_Description,
CAG.AGEGRP, 
count(patient_num) as TotalSubjects,
100*(sum(cast(Num_Dx1 as int))/count(patient_num)) as Num_DX1,
100*(sum(cast(Num_Dx2 as int))/count(patient_num)) as Num_DX2,
100*(sum(cast(MedUse1 as int))/count(patient_num))  as MedUse1,
100*(sum(cast(MedUse2 as int))/count(patient_num)) as MedUse2,
100*(sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN mammography ELSE 0 END)/count(patient_num)) AS Mammography,
100*(sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN paptest ELSE 0 END)/count(patient_num)) AS paptest,
100*(sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN psatest ELSE 0 END)/count(patient_num)) AS psatest,
100*(sum(cast(Colonoscopy as int))/count(patient_num)) as Colonoscopy,
100*(sum(cast(FecalOccultTest as int))/count(patient_num)) as FecalOccultTest,
100*(sum(cast(FluShot as int))/count(patient_num)) as  FluShot,
100*(sum(cast(PneumococcalVaccine as int))/count(patient_num)) as PneumococcalVaccine,
100*(sum(cast(BMI as int))/count(patient_num))  as BMI,
100*(sum(cast(A1C as int))/count(patient_num)) as A1C,
100*(sum(cast(MedicalExam as int))/count(patient_num)) as MedicalExam,
100*(sum(cast(INP1_OPT1_Visit as int))/count(patient_num)) as INP1_OPT1_Visit,
100*(sum(cast(OPT2_Visit as int))/count(patient_num)) as OPT2_Visit,
100*(sum(cast(ED_Visit as int))/count(patient_num))  as ED_Visit,
100*(sum(cast(MDVisit_pname2 as int))/count(patient_num)) as MDVisit_pname2,
100*(sum(cast(MDVisit_pname3 as int))/count(patient_num)) as MDVisit_pname3,
100*(sum(cast(Routine_Care_2 as int))/count(patient_num)) as Routine_care_2,
100*(sum(Subjects_NoCriteria)/count(patient_num)) as Subjects_NoCriteria,

SUM(Subjects_NoCriteria) MEAN_10YRPROB, 
SUM(Subjects_NoCriteria) MEDIAN_10YR_SURVIVAL, 
SUM(Subjects_NoCriteria) MODE_10YRPROB, 
SUM(Subjects_NoCriteria)STDEV_10YRPROB, 
TRUNC(100*(sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END)/count(patient_num))) AS TotalSubjectsFemale,
TRUNC(100*(sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END)/count(patient_num))) AS TotalSubjectsMale,
TRUNC(100*(sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END) / count(patient_num))) AS PercentSubjectsFemale,
TRUNC(100*(sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END) / count(patient_num))) AS PercentSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG 
CROSS JOIN LOYALTY_CONSTANTS X
JOIN LOYALTY_TMP_AGEGRP_PSC P ON CAG.AGEGRP = P.AGEGRP AND CAG.Predicted_score >= P.PredictiveScoreCutoff AND CAG.cohort_name = P.cohort_name
group by CAG.cohort_name, CAG.AGEGRP, X.SITE, X.LOOKBACKYEARS, X.GENDERED;
COMMIT;

--UNFILTERED
INSERT INTO loyalty_dev_summary_PRELIM
SELECT 
cag.cohort_name, 
X.SITE,
X.LOOKBACKYEARS,
CASE WHEN X.GENDERED=1 THEN 'Y' ELSE 'N'END AS GENDER_DENOMINATORS_YN,
'N' AS CUTOFF_FILTER_YN,
'Patient Counts' as Summary_Description,
CAG.AGEGRP, 
count(patient_num) as TotalSubjects,
sum(cast(Num_Dx1 as int)) as Num_DX1,
sum(cast(Num_Dx2 as int)) as Num_DX2,
sum(cast(MedUse1 as int))  as MedUse1,
sum(cast(MedUse2 as int)) as MedUse2,
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN mammography ELSE 0 END) AS Mammography,
sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN paptest ELSE 0 END) AS paptest,
sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN psatest ELSE 0 END) AS psatest,
sum(cast(Colonoscopy as int)) as Colonoscopy,
sum(cast(FecalOccultTest as int)) as FecalOccultTest,
sum(cast(FluShot as int)) as  FluShot,
sum(cast(PneumococcalVaccine as int)) as PneumococcalVaccine,
sum(cast(BMI as int))  as BMI,
sum(cast(A1C as int)) as A1C,
sum(cast(MedicalExam as int)) as MedicalExam,
sum(cast(INP1_OPT1_Visit as int)) as INP1_OPT1_Visit,
sum(cast(OPT2_Visit as int)) as OPT2_Visit,
sum(cast(ED_Visit as int))  as ED_Visit,
sum(cast(MDVisit_pname2 as int)) as MDVisit_pname2,
sum(cast(MDVisit_pname3 as int)) as MDVisit_pname3,
sum(cast(Routine_Care_2 as int)) as Routine_care_2,
SUM(Subjects_NoCriteria) as Subjects_NoCriteria,
SUM(Subjects_NoCriteria) MEAN_10YRPROB, 
SUM(Subjects_NoCriteria) MEDIAN_10YR_SURVIVAL, 
SUM(Subjects_NoCriteria) MODE_10YRPROB, 
SUM(Subjects_NoCriteria)STDEV_10YRPROB, 
sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END) AS TotalSubjectsFemale,
sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END) AS TotalSubjectsMale,
trunc(sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END) / count(patient_num)) AS PercentSubjectsFemale,
trunc(sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END) / count(patient_num)) AS PercentSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG 
CROSS JOIN LOYALTY_CONSTANTS X
JOIN LOYALTY_TMP_AGEGRP_PSC P ON CAG.AGEGRP = P.AGEGRP  AND CAG.cohort_name = P.cohort_name
group by CAG.cohort_name, CAG.AGEGRP, X.SITE, X.LOOKBACKYEARS, X.GENDERED;
COMMIT;
--SELECT * FROM LOYALTY_DEV_SUMMARY_PRELIM order by summary_description, gender_denominators_yn, cutoff_filter_yn, tablename;


INSERT INTO loyalty_dev_summary_PRELIM
SELECT 
cag.cohort_name, 
X.SITE,
X.LOOKBACKYEARS,
CASE WHEN X.GENDERED=1 THEN 'Y' ELSE 'N'END AS GENDER_DENOMINATORS_YN,
'N' AS CUTOFF_FILTER_YN,
'Percent Of Subjects' as Summary_Description,
CAG.AGEGRP, 
count(patient_num) as TotalSubjects,
100*(sum(cast(Num_Dx1 as int))/count(patient_num)) as Num_DX1,
100*(sum(cast(Num_Dx2 as int))/count(patient_num)) as Num_DX2,
100*(sum(cast(MedUse1 as int))/count(patient_num))  as MedUse1,
100*(sum(cast(MedUse2 as int))/count(patient_num)) as MedUse2,
100*(sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN mammography ELSE 0 END)/count(patient_num)) AS Mammography,
100*(sum(CASE WHEN X.GENDERED=1 and sex_cd='F' THEN paptest ELSE 0 END)/count(patient_num)) AS paptest,
100*(sum(CASE WHEN X.GENDERED=1 and sex_cd='M' THEN psatest ELSE 0 END)/count(patient_num)) AS psatest,
100*(sum(cast(Colonoscopy as int))/count(patient_num)) as Colonoscopy,
100*(sum(cast(FecalOccultTest as int))/count(patient_num)) as FecalOccultTest,
100*(sum(cast(FluShot as int))/count(patient_num)) as  FluShot,
100*(sum(cast(PneumococcalVaccine as int))/count(patient_num)) as PneumococcalVaccine,
100*(sum(cast(BMI as int))/count(patient_num))  as BMI,
100*(sum(cast(A1C as int))/count(patient_num)) as A1C,
100*(sum(cast(MedicalExam as int))/count(patient_num)) as MedicalExam,
100*(sum(cast(INP1_OPT1_Visit as int))/count(patient_num)) as INP1_OPT1_Visit,
100*(sum(cast(OPT2_Visit as int))/count(patient_num)) as OPT2_Visit,
100*(sum(cast(ED_Visit as int))/count(patient_num))  as ED_Visit,
100*(sum(cast(MDVisit_pname2 as int))/count(patient_num)) as MDVisit_pname2,
100*(sum(cast(MDVisit_pname3 as int))/count(patient_num)) as MDVisit_pname3,
100*(sum(cast(Routine_Care_2 as int))/count(patient_num)) as Routine_care_2,
SUM(Subjects_NoCriteria) as Subjects_NoCriteria,
SUM(Subjects_NoCriteria) MEAN_10YRPROB, 
SUM(Subjects_NoCriteria) MEDIAN_10YR_SURVIVAL, 
SUM(Subjects_NoCriteria) MODE_10YRPROB, 
SUM(Subjects_NoCriteria)STDEV_10YRPROB, 
TRUNC(100*(sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END)/count(patient_num))) AS TotalSubjectsFemale,
TRUNC(100*(sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END)/count(patient_num))) AS TotalSubjectsMale,
TRUNC(100*(sum(CASE WHEN sex_cd='F' THEN 1 ELSE 0 END) / count(patient_num))) AS PercentSubjectsFemale,
TRUNC(100*(sum(CASE WHEN sex_cd='M' THEN 1 ELSE 0 END) / count(patient_num))) AS PercentSubjectsMale
from LOYALTY_TMP_COHORT_AGEGRP CAG 
CROSS JOIN LOYALTY_CONSTANTS X
JOIN LOYALTY_TMP_AGEGRP_PSC P ON CAG.AGEGRP = P.AGEGRP  AND CAG.cohort_name = P.cohort_name
group by CAG.cohort_name, CAG.AGEGRP, X.SITE, X.LOOKBACKYEARS, X.GENDERED;
COMMIT;



/* CHARLSON 10YR PROB MEDIAN/MEAN/MODE/STDEV */
/* UNFILTERED BY PSC (PREDICTED LOYALTY SCORE */
DROP TABLE LOYALTY_CHARLSON_STATS;
CREATE TABLE LOYALTY_CHARLSON_STATS AS
WITH CTE_MODE AS (
SELECT cohort_name, NVL(A.AGEGRP,'All Patients') AGEGRP
  , CHARLSON_10YR_SURVIVAL_PROB
  , RANK() OVER (PARTITION BY cohort_name, NVL(A.AGEGRP,'All Patients') ORDER BY N DESC) MR_AG
FROM (
SELECT cohort_name, AGEGRP, CHARLSON_10YR_SURVIVAL_PROB, COUNT(*) N
FROM LOYALTY_COHORT_CHARLSON
GROUP BY GROUPING SETS ((cohort_name, AGEGRP, CHARLSON_10YR_SURVIVAL_PROB),(cohort_name, CHARLSON_10YR_SURVIVAL_PROB))
)A 
GROUP BY cohort_name, NVL(A.AGEGRP,'All Patients'), CHARLSON_10YR_SURVIVAL_PROB, N
)
, CTE_MEAN_STDEV_MODE AS (
SELECT GS.cohort_name, NVL(GS.AGEGRP,'All Patients') AGEGRP, MEAN_10YRPROB, STDEV_10YRPROB
  , AVG(CHARLSON_10YR_SURVIVAL_PROB) AS MODE_10YRPROB /* ONLY MEANINGFUL WHEN THERE IS A TIE FOR MODE */
FROM (
SELECT cohort_name, AGEGRP, AVG(CHARLSON_10YR_SURVIVAL_PROB) MEAN_10YRPROB, STDDEV(CHARLSON_10YR_SURVIVAL_PROB) STDEV_10YRPROB
FROM LOYALTY_COHORT_CHARLSON
GROUP BY GROUPING SETS ((cohort_name, AGEGRP),(cohort_name))
)GS JOIN CTE_MODE M
  ON GS.cohort_name = M.cohort_name
  AND NVL(GS.AGEGRP,'All Patients') = M.AGEGRP
  AND M.MR_AG = 1
GROUP BY GS.cohort_name, NVL(GS.AGEGRP,'All Patients'), MEAN_10YRPROB, STDEV_10YRPROB
)
SELECT MS.cohort_name, MS.AGEGRP
  , CAST('N' AS CHAR(1)) CUTOFF_FILTER_YN
  , MEDIAN_10YR_SURVIVAL
  , S.MEAN_10YRPROB
  , S.STDEV_10YRPROB
  , S.MODE_10YRPROB
FROM (
SELECT cohort_name, AGEGRP, CHARLSON_10YR_SURVIVAL_PROB
  , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CHARLSON_10YR_SURVIVAL_PROB) OVER (PARTITION BY cohort_name, AGEGRP) AS MEDIAN_10YR_SURVIVAL
FROM LOYALTY_COHORT_CHARLSON
WHERE AGEGRP != '-'
UNION ALL
SELECT cohort_name, 'All Patients' as AGEGRP, CHARLSON_10YR_SURVIVAL_PROB
  , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CHARLSON_10YR_SURVIVAL_PROB) OVER (PARTITION BY cohort_name) AS MEDIAN_10YR_SURVIVAL
FROM LOYALTY_COHORT_CHARLSON
WHERE AGEGRP != '-'
)MS JOIN CTE_MEAN_STDEV_MODE S
  ON MS.AGEGRP = S.AGEGRP
  AND MS.cohort_name = S.cohort_name
GROUP BY MS.cohort_name, MS.AGEGRP, MEDIAN_10YR_SURVIVAL, S.MODE_10YRPROB, S.STDEV_10YRPROB, S.MEAN_10YRPROB;

/* FILTERED BY PSC - AGEGRP*/
INSERT INTO LOYALTY_CHARLSON_STATS(cohort_name, AGEGRP,CUTOFF_FILTER_YN,MEDIAN_10YR_SURVIVAL,MEAN_10YRPROB,STDEV_10YRPROB,MODE_10YRPROB)
WITH CTE_MODE AS (
SELECT cohort_name
  , AGEGRP
  , CHARLSON_10YR_SURVIVAL_PROB
  , RANK() OVER (PARTITION BY COHORT_NAME, NVL(A.AGEGRP,'All Patients') ORDER BY N DESC) MR_AG
FROM (
SELECT CC.cohort_name, C.AGEGRP, CHARLSON_10YR_SURVIVAL_PROB, COUNT(*) N
FROM LOYALTY_COHORT_CHARLSON CC
  JOIN LOYALTY_TMP_cohort_agegrp C
    ON CC.PATIENT_NUM = C.patient_num
    AND CC.cohort_name = C.cohort_name
  JOIN LOYALTY_TMP_AGEGRP_PSC PSC
    ON C.AGEGRP = PSC.AGEGRP
    AND C.Predicted_score >= PSC.PredictiveScoreCutoff
    AND C.cohort_name = PSC.cohort_name
GROUP BY CC.cohort_name, C.AGEGRP,CHARLSON_10YR_SURVIVAL_PROB
)A
GROUP BY cohort_name, AGEGRP, CHARLSON_10YR_SURVIVAL_PROB, N
)
, CTE_MEAN_STDEV_MODE AS (
SELECT GS.cohort_name, NVL(GS.AGEGRP,'All Patients') AS AGEGRP, MEAN_10YRPROB, STDEV_10YRPROB
  , AVG(CHARLSON_10YR_SURVIVAL_PROB) AS MODE_10YRPROB
FROM (
SELECT CC.cohort_name, C.AGEGRP, AVG(CHARLSON_10YR_SURVIVAL_PROB) MEAN_10YRPROB, STDDEV(CHARLSON_10YR_SURVIVAL_PROB) STDEV_10YRPROB
FROM LOYALTY_COHORT_CHARLSON CC
  JOIN LOYALTY_TMP_cohort_agegrp C
    ON CC.PATIENT_NUM = C.patient_num
    AND CC.cohort_name = C.cohort_name
  JOIN LOYALTY_TMP_AGEGRP_PSC PSC
    ON C.AGEGRP = PSC.AGEGRP
    AND C.Predicted_score >= PSC.PredictiveScoreCutoff
    AND C.cohort_name = C.cohort_name
GROUP BY CC.cohort_name, C.AGEGRP
)GS JOIN CTE_MODE M
  ON GS.cohort_name = M.cohort_name
  AND NVL(GS.AGEGRP,'All Patients') = M.AGEGRP
  AND M.MR_AG = 1
GROUP BY GS.cohort_name, NVL(GS.AGEGRP,'All Patients'), MEAN_10YRPROB, STDEV_10YRPROB
)
SELECT MS.COHORT_NAME, MS.AGEGRP
  , CAST('Y' AS CHAR(1)) AS CUTOFF_FILTER_YN
  , MEDIAN_10YR_SURVIVAL
  , S.MEAN_10YRPROB
  , S.STDEV_10YRPROB
  , S.MODE_10YRPROB
FROM (
SELECT CC.cohort_name, C.AGEGRP, CHARLSON_10YR_SURVIVAL_PROB
  , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CHARLSON_10YR_SURVIVAL_PROB) OVER (PARTITION BY CC.COHORT_NAME, C.AGEGRP) AS MEDIAN_10YR_SURVIVAL
FROM LOYALTY_COHORT_CHARLSON CC
  JOIN LOYALTY_TMP_cohort_agegrp C
    ON CC.PATIENT_NUM = C.patient_num
      AND CC.cohort_name = C.cohort_name
  JOIN LOYALTY_TMP_AGEGRP_PSC PSC
    ON C.AGEGRP = PSC.AGEGRP
    AND C.Predicted_score >= PSC.PredictiveScoreCutoff
    AND CC.cohort_name = PSC.cohort_name
WHERE CC.AGEGRP != '-'
)MS JOIN CTE_MEAN_STDEV_MODE S
  ON MS.AGEGRP = S.AGEGRP
  AND MS.cohort_name = S.cohort_name
GROUP BY MS.cohort_name, MS.AGEGRP, MEDIAN_10YR_SURVIVAL, S.MODE_10YRPROB, S.STDEV_10YRPROB, S.MEAN_10YRPROB;
COMMIT;

--SELECT * FROM LOYALTY_CHARLSON_STATS;
