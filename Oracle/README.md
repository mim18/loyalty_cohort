Oracle version to compute the Loyalty Score and the Charlson Comorbidity Index
- The charlson script is a direct translation of Darren Henderson UKY SQLServer script
- The Loyalty script is an adaptation using all path based selection of features and pivoting to a wide table at the very end. The resulting table
is named LOYALTY_SCORE_BY_PATIENT
- The LOYALTY_SCORE_BY_PATIENT and the LOYALTY_COHORT_CHARLSON are joined with patient dimension in the assemble script to create a wide table with
Charlson score, loyalty score, demographhics and flags for each of the loyalty features and charlson features. This script can be used to export
the MLHO Demographics table.
- A MLHO fact table script should be available later this week.

INSTRUCTIONS
- Edit the scripts to replace any @crc_schema or @metadata_schema strings wih schemas in your environment
- Run BUILD_LOYALTY_REFERENCE_TABLES.sql. This script only needs run once. It creates and populates the Charlson facts, the Loyalty features and the feature to ACT c_fullname map.
- Run LOYALTY_SCORE_MAIN.sql This runs the remainder of the scripts except EXPORT_DEMOGRAPHICS.sql and CLEANUP_LOYALTY_TABLES
  -- If you are translating the ASSEMBLE_LOYALTY_STATS_OPTIONAL.sql script is optional as none of the tables included in this script are used as input to MLHO for wither of the experiments. 
