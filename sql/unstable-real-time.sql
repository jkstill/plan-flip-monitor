----------------------------------------------------------------------------------------
--
-- File name:   unstable-plans-realtime.sql
--
-- Purpose:     Attempts to find SQL statements with plan instability.
--              Use gv views rather than dba_hist
-- Origianal 
-- Author:      Kerry Osborne
--
-- Modified:    Jared Still - show avg_lio, plan_count, rewrote sql via WITH
--
-- Usage:       This scripts prompts for two values, both of which can be left blank.
--
--              min_stddev: the minimum "normalized" standard deviation between plans 
--                          (the default is 2)
--
--              min_etime:  only include statements that have an avg. etime > this value
--                          (the default is .001 second)
--
-- See http://kerryosborne.oracle-guy.com/2008/10/unstable-plans/ for more info.
---------------------------------------------------------------------------------------

-- jks
-- hard coding min_stddev and min_etime values
-- set very low as SOE is rather efficient
-- 

def min_stddev=2
def min_etime=0.000500 -- 500 usec - nearly everything

set lines 155
col execs for 999,999,999
col min_etime for 999,990.9999999
col max_etime for 999,990.9999999
col avg_etime for 999,990.9999999
col avg_lio for 999,999,990.9
col norm_stddev for 999,990.9999
col stddev_etime for 99,990.9999
col begin_interval_time for a30
col node for 99999
col sql_id format a13
col plan_count format 99,999 head 'PLAN|COUNT'
col username format a15

-- break on plan_hash_value on startup_time skip 1

--prompt
--prompt Disabling Parallel Query
--prompt
--alter session disable parallel query;


with
rawdata as
(
   select /*+ NOPARALLEL */
      sql_id
      , plan_hash_value
      , sum( nvl( executions, 0 ) ) execs
      , (
         sum(elapsed_time) /
         decode
         (
            sum( nvl( executions, 0 ) )
            , 0, 1
            , sum( executions )
         ) / 1000000
      ) avg_etime
      , sum ( buffer_gets /
         decode
         (
            nvl( buffer_gets, 0 )
            , 0, 1
            , executions
         )
      ) avg_lio
      from
      gv$sqlstats  s
      where
          executions   > 0
      group by
         sql_id
         , plan_hash_value
)
, data AS
(
	select -- distinct -- seems distinct not needed for this query
		sql_id
		, plan_hash_value
		, execs
		, avg_lio
		, avg_etime
		, stddev( avg_etime ) over( partition BY sql_id ) stddev_etime
	from
	rawdata
)
, lios as (
   select distinct sql_id, avg_lio
   from data
)
, plan_counts as (
	select distinct
		sql_id
		, count(*) over (partition by sql_id order by sql_id) plan_count
	from rawdata
)
, report_data AS
(
	select
	sql_id
		, sum( execs ) execs
		, min( avg_etime )              min_etime
		, max( avg_etime )              max_etime
		, stddev_etime
		, stddev_etime/min( avg_etime ) norm_stddev
	from data
	group by
		sql_id
		, stddev_etime
),
getuser as (
	select
		r.sql_id
		, r.execs
		, (select max(parsing_schema_name) from gv$sqlarea where sql_id = r.sql_id) username
		, ( select sum(avg_lio) from lios where sql_id = r.sql_id)/ r.execs avg_lio
		, ( select plan_count from plan_counts where sql_id = r.sql_id) plan_count
		, r.min_etime
		, r.max_etime
		, r.stddev_etime
		, r.norm_stddev
	from report_data r
	where
   	r.norm_stddev   > .001
   	and r.max_etime > .001
	ORDER BY
   	norm_stddev
)
select *
from getuser
--where username = 'SOE'
where username not in
(
   select name schema_to_exclude
   from system.LOGSTDBY$SKIP_SUPPORT
   where action = 0
)
order by norm_stddev
/


