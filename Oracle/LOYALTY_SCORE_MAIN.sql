-- Create Reference Tables - only need to do this once
--@Build_Loyalty_Reference_Tables.Sql
commit;
--TRUNCATE TABLE LOYALTY_XREF_CHARLSON;
set echo off
@CLEANUP_LOYALTY_TABLES.sql
-- Create Loyalty tables and set run parameters index_date lookback_period SHOW_OUTPUT demographic_start_date site_name gendered_1_0
--@C:\DevTools\NCATS\ACT\Research\Loyalty\LOYALTY_COHORT_SETUP '01-JAN-2018' 5 0 '01-JAN-2004' UPITT 1
--this next line does not seem to work from this script so the params are hardcoded in the script
@LOYALTY_COHORT_SETUP 01-JAN-2018 5 0 01-JAN-2004 UPITT 1
-- Run Loyalty script
@COMPUTE_LOYALTY_SCORE.sql --12276secs
-- Run Charlson script
@COMPUTE_CHARLSON_SCORE.sql
-- Create Summary Stats tables - These tables are optional as they are not used as input LOYALTY SCORE or PASC  R (MLHO) 
@ASSEMBLE_LOYALTY_STATS_OPTIONAL.sql
-- Queries for loyalty score and PASC project output

