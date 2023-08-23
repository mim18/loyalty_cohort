
-- This can be a table a view  or a query - It contains all the data needed for the MLHO DEMOGRAPHICS
with cte_query as (
-- get the lastest query with that name
select max(q.query_master_id) as query_master_id
from qt_query_master q 
join qt_query_instance i on i.query_master_id = q.query_master_id
join qt_query_result_instance r on r.query_instance_id = i.query_instance_id 
join qt_patient_set_collection ps on ps.result_instance_id = r.result_instance_id -- one-to-many --need to be a query that has a patient_set
where q.name = 'covid+ pcr'
--if multiple patient sets associated with this query name use query_master_id
),
--select * from cte_query;
cte_query_cohort as (
select q.query_master_id, ps.patient_num 
from cte_query q 
join qt_query_instance i on i.query_master_id = q.query_master_id
join qt_query_result_instance r on r.query_instance_id = i.query_instance_id 
join qt_patient_set_collection ps on ps.result_instance_id = r.result_instance_id -- one-to-many --need to be a query that has a patient_set
--if multiple patient sets associated with this query name use query_master_id
)
select query_master_id, 
--demographics
l.patient_num, d.sex_cd, d.race_cd, l.age, d.birth_date, -- what date should the age be tied to
-- loyalty score features
predicted_score, indexdate, 
    l.last_visit,
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
    routine_care_2,

-- charlson comorbidities
    charlson_index,
    trunc(charlson_10yr_survival_prob, 1) as charlson_10yr_survival_prob,
    mi,
    chf,
    cvd,
    pvd,
    dementia,
    copd,
    rheumdis,
    pepulcer,
    mildlivdis,
    diabetes_nocc,
    diabetes_wtcc,
    hemiparapleg,
    renaldis,
    cancer,
    msvlivdis,
    metastatic,
    aidshiv
from cte_query_cohort q
join loyalty_score_by_patient l on l.patient_num = q.patient_num
join loyalty_cohort_charlson c on c.patient_num = l.patient_num
left outer join patient_dimension d on d.patient_num = q.patient_num;