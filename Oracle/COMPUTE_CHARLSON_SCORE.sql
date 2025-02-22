-- ORIGINAL CODE BY DARREN HENDERSON UKY
-- TRANSLATED TO ORACLE BY MICHELE MORRIS UPITT

-- COMPUTE CHARLSON COMORBIDITY SCORE FOR THE SELECTED COHORT 
-- THIS CAN BE USED TO CALCULATE FOR ALL PATIENTS AS WELL 
-- CODE SHOULD BE RUN IN THE CRCDATA SCHEMA

--DROP TABLE LOYALTY_TMP_CHARLSON_VISIT_BASE;
CREATE TABLE  LOYALTY_TMP_CHARLSON_VISIT_BASE AS
WITH CTE_VISIT_BASE AS (
SELECT cohort_name, PATIENT_NUM, SEX, AGE, LAST_VISIT
  , CASE  WHEN AGE < 50 THEN 0
          WHEN AGE BETWEEN 50 AND 59 THEN 1
          WHEN AGE BETWEEN 60 AND 69 THEN 2
          WHEN AGE >= 70 THEN 3 END AS CHARLSON_AGE_BASE
FROM (
SELECT cohort_name, V.PATIENT_NUM
  , SEX
  , V.AGE
  , LAST_VISIT
FROM LOYALTY_TMP_COHORT_IN_PERIOD V 
) VISITS
)
SELECT cohort_name, PATIENT_NUM, SEX, AGE, LAST_VISIT, CHARLSON_AGE_BASE
FROM CTE_VISIT_BASE;

commit;

--SELECT * FROM LOYALTY_COHORT_CHARLSON;
DROP TABLE LOYALTY_COHORT_CHARLSON;
CREATE TABLE LOYALTY_COHORT_CHARLSON AS
SELECT X.site as SITE, 
cohort_name,
PATIENT_NUM
  , LAST_VISIT
  , SEX
  , AGE
  , CAST(case when AGE < 65 then 'Under 65' 
     when age>=65           then 'Over 65' else '-' end AS VARCHAR(20)) AS AGEGRP
  , CHARLSON_INDEX
  , POWER( 0.983
      , POWER(2.71828, (CASE WHEN CHARLSON_INDEX > 7 THEN 7 ELSE CHARLSON_INDEX END) * 0.9)
      ) * 100.0 AS CHARLSON_10YR_SURVIVAL_PROB
  , MI, CHF, CVD, PVD, DEMENTIA, COPD, RHEUMDIS, PEPULCER, MILDLIVDIS, DIABETES_NOCC, DIABETES_WTCC, HEMIPARAPLEG, RENALDIS, CANCER, MSVLIVDIS, METASTATIC, AIDSHIV
FROM (
SELECT cohort_name, PATIENT_NUM, LAST_VISIT, SEX, AGE
  , CHARLSON_AGE_BASE
      + MI + CHF + CVD + PVD + DEMENTIA + COPD + RHEUMDIS + PEPULCER 
      + (CASE WHEN MSVLIVDIS > 0 THEN 0 ELSE MILDLIVDIS END)
      + (CASE WHEN DIABETES_WTCC > 0 THEN 0 ELSE DIABETES_NOCC END)
      + DIABETES_WTCC + HEMIPARAPLEG + RENALDIS + CANCER + MSVLIVDIS + METASTATIC + AIDSHIV AS CHARLSON_INDEX
  , MI, CHF, CVD, PVD, DEMENTIA, COPD, RHEUMDIS, PEPULCER, MILDLIVDIS, DIABETES_NOCC, DIABETES_WTCC, HEMIPARAPLEG, RENALDIS, CANCER, MSVLIVDIS, METASTATIC, AIDSHIV
FROM (
SELECT cohort_name, PATIENT_NUM, SEX, AGE, LAST_VISIT, CHARLSON_AGE_BASE
  , MAX(CASE WHEN CHARLSON_CATGRY = 'MI'            THEN CHARLSON_WT ELSE 0 END) AS MI
  , MAX(CASE WHEN CHARLSON_CATGRY = 'CHF'           THEN CHARLSON_WT ELSE 0 END) AS CHF
  , MAX(CASE WHEN CHARLSON_CATGRY = 'CVD'           THEN CHARLSON_WT ELSE 0 END) AS CVD
  , MAX(CASE WHEN CHARLSON_CATGRY = 'PVD'           THEN CHARLSON_WT ELSE 0 END) AS PVD
  , MAX(CASE WHEN CHARLSON_CATGRY = 'DEMENTIA'      THEN CHARLSON_WT ELSE 0 END) AS DEMENTIA
  , MAX(CASE WHEN CHARLSON_CATGRY = 'COPD'          THEN CHARLSON_WT ELSE 0 END) AS COPD
  , MAX(CASE WHEN CHARLSON_CATGRY = 'RHEUMDIS'      THEN CHARLSON_WT ELSE 0 END) AS RHEUMDIS
  , MAX(CASE WHEN CHARLSON_CATGRY = 'PEPULCER'      THEN CHARLSON_WT ELSE 0 END) AS PEPULCER
  , MAX(CASE WHEN CHARLSON_CATGRY = 'MILDLIVDIS'    THEN CHARLSON_WT ELSE 0 END) AS MILDLIVDIS
  , MAX(CASE WHEN CHARLSON_CATGRY = 'DIABETES_NOCC' THEN CHARLSON_WT ELSE 0 END) AS DIABETES_NOCC
  , MAX(CASE WHEN CHARLSON_CATGRY = 'DIABETES_WTCC' THEN CHARLSON_WT ELSE 0 END) AS DIABETES_WTCC
  , MAX(CASE WHEN CHARLSON_CATGRY = 'HEMIPARAPLEG'  THEN CHARLSON_WT ELSE 0 END) AS HEMIPARAPLEG
  , MAX(CASE WHEN CHARLSON_CATGRY = 'RENALDIS'      THEN CHARLSON_WT ELSE 0 END) AS RENALDIS
  , MAX(CASE WHEN CHARLSON_CATGRY = 'CANCER'        THEN CHARLSON_WT ELSE 0 END) AS CANCER
  , MAX(CASE WHEN CHARLSON_CATGRY = 'MSVLIVDIS'     THEN CHARLSON_WT ELSE 0 END) AS MSVLIVDIS
  , MAX(CASE WHEN CHARLSON_CATGRY = 'METASTATIC'    THEN CHARLSON_WT ELSE 0 END) AS METASTATIC
  , MAX(CASE WHEN CHARLSON_CATGRY = 'AIDSHIV'       THEN CHARLSON_WT ELSE 0 END) AS AIDSHIV
FROM (
  /* FOR EACH VISIT - PULL PREVIOUS YEAR OF DIAGNOSIS FACTS JOINED TO CHARLSON CATEGORIES - EXTRACTING CHARLSON CATGRY/WT */
  SELECT cohort_name, O.PATIENT_NUM, O.SEX, O.AGE, O.LAST_VISIT, O.CHARLSON_AGE_BASE, C.CHARLSON_CATGRY, C.CHARLSON_WT
  FROM (SELECT DISTINCT cohort_name, F.PATIENT_NUM, CONCEPT_CD, V.SEX, V.AGE, V.LAST_VISIT, V.CHARLSON_AGE_BASE 
        FROM OBSERVATION_FACT F 
          JOIN LOYALTY_TMP_CHARLSON_VISIT_BASE V 
            ON F.PATIENT_NUM = V.PATIENT_NUM
            AND F.START_DATE BETWEEN  ADD_MONTHS( TRUNC(V.LAST_VISIT), -12) AND  V.LAST_VISIT
       )O
    JOIN  LOYALTY_XREF_CHARLSON C
      ON O.CONCEPT_CD = C.CONCEPT_CD
  GROUP BY cohort_name, O.PATIENT_NUM, O.SEX, O.AGE, O.LAST_VISIT, O.CHARLSON_AGE_BASE, C.CHARLSON_CATGRY, C.CHARLSON_WT
  UNION /* IF NO CHARLSON DX FOUND IN ABOVE INNER JOINS WE CAN UNION TO JUST THE ENCOUNTER+AGE_BASE RECORD WITH CHARLSON FIELDS NULLED OUT
           THIS IS MORE PERFORMANT (SHORTCUT) THAN A LEFT JOIN IN THE OBSERVATION-CHARLSON JOIN ABOVE - dh*/
  SELECT cohort_name, V2.PATIENT_NUM, V2.SEX, V2.AGE, V2.LAST_VISIT, V2.CHARLSON_AGE_BASE, NULL, NULL
  FROM LOYALTY_TMP_CHARLSON_VISIT_BASE V2
  )DXU
  GROUP BY cohort_name, PATIENT_NUM, SEX, AGE, LAST_VISIT, CHARLSON_AGE_BASE
)cci
)ccisum
CROSS JOIN LOYALTY_CONSTANTS X;

--REVIEW
SELECT count(*) FROM LOYALTY_COHORT_CHARLSON;
