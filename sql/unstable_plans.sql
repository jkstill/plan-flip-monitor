----------------------------------------------------------------------------------------
--
-- File name:   unstable_plans.sql
--
-- Purpose:     Attempts to find SQL statements with plan instability.
--
-- Author:      Kerry Osborne
--
-- Usage:       This scripts prompts for two values, both of which can be left blank.
--
--              min_stddev: the minimum "normalized" standard deviation between plans 
--                          (the default is 2)
--
--              min_etime:  only include statements that have an avg. etime > this value
--                          (the default is .1 second)
--
-- See http://kerryosborne.oracle-guy.com/2008/10/unstable-plans/ for more info.
---------------------------------------------------------------------------------------

-- jks
-- hard coding min_stddev and min_etime values
def min_stddev=2
def min_etime=0.000500 -- 500 usec - nearly everything

set lines 155
col execs for 999,999,999
col min_etime for 999,999.9999999
col max_etime for 999,999.9999999
col avg_etime for 999,999.9999999
col avg_lio for 999,999,999.9
col norm_stddev for 999,999.9999
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1
break on sql_id skip 1 

SELECT *
FROM
   (
   SELECT
      sql_id
    , SUM( execs )
    --, avg_lio
    , MIN( avg_etime )              min_etime
    , MAX( avg_etime )              max_etime
    , stddev_etime/MIN( avg_etime ) norm_stddev
   FROM
      (
      SELECT
         sql_id
       , plan_hash_value
       , execs
       , avg_etime
       , stddev( avg_etime ) over(
                               PARTITION BY
                                  sql_id ) stddev_etime
       --, avg_lio
      FROM
         (
         SELECT
            sql_id
          , plan_hash_value
          , SUM( NVL( executions_delta, 0 ) ) execs
          ,( SUM( elapsed_time_delta )/DECODE( SUM( NVL( executions_delta, 0 ) )
                                               , 0, 1
                                               , SUM( executions_delta ) )/1000000 ) avg_etime
          --, sum((buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta))) avg_lio
         FROM
            DBA_HIST_SQLSTAT  S
          , DBA_HIST_SNAPSHOT SS
         WHERE
            ss.snap_id             = S.snap_id
            AND ss.instance_number = S.instance_number
            AND executions_delta   > 0
         GROUP BY
            sql_id
          , plan_hash_value
         )
      )
   GROUP BY
      sql_id
    , stddev_etime
    --, avg_lio
   )
WHERE
   norm_stddev   > NVL( to_number( '&min_stddev' ), 2 )
   AND max_etime > NVL( to_number( '&min_etime' ), .1 )
ORDER BY
   norm_stddev
/
