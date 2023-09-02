-- To use this code to roll localcodes up to standard concepts in the ACT ontology you will need either 
-- a clean ACT concept_dimension table or some way to differentiate  local codes from ACT concepts 
-- this code currently uses the prefixes to determine whether the codes are standard or not

--Only set a local prefix  if the code is the same as an ACT Standard code 
--Example change ICD10CM to ICD10 IF ICD10CM:C50 is ICD10:C50 in your fact table
--Do NOT change to a local prefix to reference a local code
with cte_vocab_map AS 
(
select 'DEM|HISP:%' local_prefix, 'Ethnicity' act_domain from dual 
union
select 'DEM|RACE:%' local_prefix, 'Race' act_domain from dual 
union
select 'DEM|SEX:%' local_prefix, 'Gender' act_domain from dual 
union
select 'RXNORM:%' local_prefix, 'RXNORM' act_domain from dual 
union
select 'NDC:%' local_prefix, 'NDC' act_domain from dual 
union
select 'NUI:%' local_prefix, 'NDFRT' act_domain from dual 
union
select 'ICD10CM:%' local_prefix, 'ICD10CM' act_domain from dual 
union
select 'ICD9CM:%' local_prefix, 'ICD9CM' act_domain from dual 
union
select 'ICD10PCS:%' local_prefix, 'ICD10PCS' act_domain from dual 
union
select 'ICD9PROC:%' local_prefix, 'ICD9PROC' act_domain from dual 
union
select 'LOINC:%' local_prefix, 'LOINC' act_domain from dual 
union
select 'CPT4:%' local_prefix, 'CPT4' act_domain from dual 
union
select 'HCPCS:%' local_prefix, 'HCPCS' act_domain from dual 
union
select 'ACT|LOCAL|LAB:%' local_prefix, 'ACTNONSTANDARDLAB' act_domain from dual 
union
select 'ACT|LOCAL|VAX:%' local_prefix, 'ACTNONSTANDARDVAX' act_domain from dual 
union
select 'DEM|VITAL STATUS:%' local_prefix, 'Vital Status' act_domain from dual 
union
select 'MSDRG:%' local_prefix, 'MSDRG' act_domain from dual 
union
--select 'LOCAL:%' local_prefix, 'ACTNONSTANDARD' act_domain from dual 
--union
select 'SNOMED:%' local_prefix, 'SNOMED' act_domain from dual 
union
select 'ACT|LOCAL|DERIVED:%' local_prefix, 'ACTNONSTANDARDDERIVED' act_domain from dual 
union
select 'DRG:%' local_prefix, 'DRG' act_domain from dual 
union
select 'KEGG:%' local_prefix, 'KEGG' act_domain from dual 
union
select 'UNII:%' local_prefix, 'UNII' act_domain from dual 
union
select 'UMLS:%' local_prefix, 'UMLS' act_domain from dual 
union
select 'CVX:%' local_prefix, 'CVX' act_domain from dual 
union
select 'ATC:%' local_prefix, 'ATC' act_domain from dual 
union
select 'ACT_LOCAL_MONOCLONAL:%' local_prefix, 'ACTNONSTANDARDLAB' act_domain from dual 
union
select 'ACT|LOCAL:%' local_prefix, 'ACTNONSTANDARDLAB' act_domain from dual 
order by act_domain
 ),
cte_concept_dimension as 
(
    select * from concept_dimension --test_conc_dim_with_local --@cdmDatabaseSchema.concept_dimension
),
med_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension where concept_path like '\ACT\Medications\%'  and
(concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'RXNORM' and rownum = 1) 
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'NDC' and rownum = 1)
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'NDFRT' and rownum = 1))
order by concept_path
),
med_nonstandard_codes as --local codes
(
select * from cte_concept_dimension where concept_path like '\ACT\Medications\%' 
and (concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'RXNORM' and rownum = 1) 
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'NDC' and rownum = 1)
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'NDFRT' and rownum = 1))
order by concept_path
),
med_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from med_nonstandard_codes
),
med_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    s.concept_path concept_path, 
    p.path_element
from med_nonstandard_parents p
inner join med_standard_codes s on s.concept_path = p.parent
),

-- Diagnosis Code Mapping
dx_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension 
where (concept_path like '\ACT\Diagnosis\%' or concept_path like '\Diagnoses\%') and
(concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD10CM' and rownum = 1) 
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1))
order by concept_path
),
dx_nonstandard_codes as --local codes
(
select * from cte_concept_dimension 
where (concept_path like '\ACT\Diagnosis\%' or concept_path like '\Diagnoses\%') and
(concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD10CM' and rownum = 1) 
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1))
order by concept_path
)
--select * from dx_nonstandard_codes; 
,
dx_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from dx_nonstandard_codes
),
dx_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    --s.concept_path concept_path,
    p.concept_path concept_path,
    p.path_element
from dx_nonstandard_parents p
inner join dx_standard_codes s on s.concept_path = p.parent
)
--select * from dx_nonstandard_codes_mapped;
,

-- Lab Code Mapping
lab_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension 
where (concept_path like '\ACT\Labs\%' or concept_path like '\ACT\Lab\%') and
(concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'LOINC' and rownum = 1))
order by concept_path
),
lab_nonstandard_codes as --local codes
(
select * from cte_concept_dimension 
where (concept_path like '\ACT\Labs\%' or concept_path like '\ACT\Lab\%') and
(concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'LOINC' and rownum = 1))
order by concept_path
),
lab_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from lab_nonstandard_codes
),
lab_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    p.concept_path concept_path, 
    p.path_element
from lab_nonstandard_parents p
inner join lab_standard_codes s on s.concept_path = p.parent
),

-- Procedures Code Mapping
px_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension 
where (concept_path like '\ACT\Procedures\%' or concept_path like '\Diagnoses\%') and
    (concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD10PCS' and rownum = 1) 
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD9PROC' and rownum = 1)
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'CPT4' and rownum = 1)
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'HCPCS' and rownum = 1))
order by concept_path
),
px_nonstandard_codes as --local codes
(
select * from cte_concept_dimension 
where (concept_path like '\ACT\Procedures\%' or concept_path like '\Diagnoses\%') and
    (concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD10PCS' and rownum = 1) 
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD9PROC' and rownum = 1)
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'CPT4' and rownum = 1)
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD10CM' and rownum = 1)
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1)
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'HCPCS' and rownum = 1))
order by concept_path
),
px_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from px_nonstandard_codes
),
px_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    p.concept_path concept_path, 
    p.path_element
from px_nonstandard_parents p
inner join px_standard_codes s on s.concept_path = p.parent
),
--NEW
-- Vaccination Code Mapping
dx_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension 
where (concept_path like '\ACT\Diagnosis\%' or concept_path like '\Diagnoses\%') and
(concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD10CM' and rownum = 1) 
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1))
order by concept_path
),
dx_nonstandard_codes as --local codes
(
select * from cte_concept_dimension 
where (concept_path like '\ACT\Diagnosis\%' or concept_path like '\Diagnoses\%') and
(concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD10CM' and rownum = 1) 
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1))
order by concept_path
)
--select * from dx_nonstandard_codes; 
,
dx_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from dx_nonstandard_codes
),
dx_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    --s.concept_path concept_path,
    p.concept_path concept_path,
    p.path_element
from dx_nonstandard_parents p
inner join dx_standard_codes s on s.concept_path = p.parent
)
--select * from dx_nonstandard_codes_mapped;
,
-- COVID Code Mapping
covid_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension 
where (concept_path like '\ACT\UMLS_C0031437\SNOMED_3947185011\%')  and
(substr(concept_cd,1,instr(concept_cd,':',1)) in (select substr(local_prefix,1,instr(concept_cd,':',1)) from cte_vocab_map ))
--where act_domain = 'ICD10CM' and rownum = 1) 
--     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1))
order by concept_path
),
--cte_VOCAB_MAP
covid_nonstandard_codes as --local codes
(
select * from cte_concept_dimension 
--select substr(concept_cd,1,instr(concept_cd,':',1)) prefix from cte_concept_dimension 
where (concept_path like '\ACT\UMLS_C0031437\SNOMED_3947185011\%') 
and ( (instr(concept_cd,':',1) = 0) or
    (substr(concept_cd,1,instr(concept_cd,':',1))  not in (select substr(local_prefix,1,instr(concept_cd,':',1))
    from cte_vocab_map )))
-- and (concept_cd not in (select local_prefix from cte_vocab_map where act_domain = 'ICD10CM' and rownum = 1) 
--     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'ICD9CM' and rownum = 1))
order by concept_path
)
--select local_prefix from cte_vocab_map;
--select * from covid_nonstandard_codes; 
,
covid_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from covid_nonstandard_codes
),
covid_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    --s.concept_path concept_path,
    p.concept_path concept_path,
    p.path_element
from covid_nonstandard_parents p
inner join covid_standard_codes s on s.concept_path = p.parent
)
--select * from covid_nonstandard_codes_mapped;
,
--END NEW
-- Demographics Code Mapping
dem_standard_codes as 
(
select concept_path, concept_cd, name_char from cte_concept_dimension 
where concept_path like '\ACT\Demographics\%' and
(concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'Race' and rownum = 1) 
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'Gender' and rownum = 1)
     or concept_cd like (select local_prefix from cte_vocab_map where act_domain = 'Ethnicity' and rownum = 1))
order by concept_path
),
dem_nonstandard_codes as --local codes
(
select * from cte_concept_dimension 
where concept_path like '\ACT\Demographics\%' and
    (concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'Race' and rownum = 1) 
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'Gender' and rownum = 1)
     and concept_cd not like (select local_prefix from cte_vocab_map where act_domain = 'Ethnicity' and rownum = 1))
order by concept_path
),
dem_nonstandard_parents as 
(
select 
    concept_cd, 
    name_char, 
    replace(concept_path,regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)||'\','')  parent, 
    regexp_substr(rtrim(concept_path,'\'), '[^\]+$', 1, 1)  path_element, 
    concept_path 
from dem_nonstandard_codes
),
dem_nonstandard_codes_mapped as  
(
select 
    s.concept_cd act_standard_code, 
    p.concept_cd local_concept_cd, 
    p.name_char, 
    p.parent parent_concept_path,
    p.concept_path concept_path, --s.
    p.path_element
from dem_nonstandard_parents p
inner join dem_standard_codes s on s.concept_path = p.parent
),
cte_mapped_nonstandard as (
select * from med_nonstandard_codes_mapped
union
select * from lab_nonstandard_codes_mapped
union
select * from dx_nonstandard_codes_mapped
union
select * from px_nonstandard_codes_mapped
union
select * from dem_nonstandard_codes_mapped
union 
select * from covid_nonstandard_codes_mapped
),
cte_concept_dimension_all as (
select concept_cd, concept_path, name_char from concept_dimension
union 
select local_concept_cd as concept_cd, parent_concept_path as concept_path, name_char from cte_mapped_nonstandard
),
cte_cohort as (
select patient_num
from qt_patient_set_collection ps
where ps.result_instance_id = FILL_IN_PATIENT_SET_RESULT_INSTANCE_ID --9097 who_case, who_control, who pre_control
)
--select * from cte_concept_dimension_all where name_char like '%LOCAL%'; check if local codes are being rolled up to enact ontology paths
--368 seconds for cohort size 3300
select c.patient_num as "patient_num", start_date as "start_date", encounter_num as "encounter_num", 
    f.concept_cd as "concept_cd", d.concept_path as "c_fullname"
from cte_cohort c
join observation_fact f on f.patient_num = c.patient_num
join cte_concept_dimension_all d on d.concept_cd = f.concept_cd
;

