----------------------------------------------------------------------------------------
--
-- File name:   unstable-plans-new.sql
--
-- Purpose:     Attempts to find SQL statements with plan instability.
--
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

col v_snap_start_time noprint new_value v_snap_start_time
col v_snap_end_time noprint new_value v_snap_end_time
-- set the start time to get recent values for baselines
def v_timestamp_format = 'yyyy-mm-dd hh24:mi:ss'
def v_snap_start_time = '2022-01-01 00:00:00'
def v_snap_start_time = '2022-05-04 00:00:00'
def v_snap_end_time = '2022-05-04 23:00:00'

-- for testing, just set these to the most recent day
set feedback off termout off
select to_char(trunc(sysdate),'yyyy-mm-dd hh24:mi:ss') v_snap_start_time from dual;
select to_char(sysdate,'yyyy-mm-dd hh24:mi:ss') v_snap_end_time from dual;
set feedback on termout on

def v_snap_start_time = '2022-05-04 08:00:00'

prompt
prompt min start time: &v_snap_start_time
prompt max end   time: &v_snap_end_time
prompt

--prompt
--prompt Disabling Parallel Query
--prompt
--alter session disable parallel query;


with
min_snap_id as 
(
	select
		min(snap_id) snap_id
	from dba_hist_snapshot
	where begin_interval_time >= to_timestamp('&v_snap_start_time','&v_timestamp_format')
		and con_id = sys_context('userenv','con_id')
),
max_snap_id as
(
	select
		max(snap_id) snap_id
	from dba_hist_snapshot
	where end_interval_time <= to_timestamp('&v_snap_end_time','&v_timestamp_format')
		and con_id = sys_context('userenv','con_id')
),
rawdata as
(
	select /*+ NOPARALLEL */
		sql_id
		, plan_hash_value
		, sum( nvl( executions_delta, 0 ) ) execs
		, (
			sum(elapsed_time_delta) /
			decode
			(
				sum( nvl( executions_delta, 0 ) )
				, 0, 1
				, sum( executions_delta )
			) / 1000000
		) avg_etime
		, sum ( buffer_gets_delta /
			decode
			(
				nvl( buffer_gets_delta, 0 )
				, 0, 1
				, executions_delta
			)
		) avg_lio
		from
		dba_hist_sqlstat  s
			, dba_hist_snapshot ss
		where
			ss.snap_id             = s.snap_id
			and ss.instance_number = s.instance_number
			and ss.snap_id between ( select snap_id from min_snap_id ) and ( select snap_id from max_snap_id )
			and executions_delta   > 0
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


