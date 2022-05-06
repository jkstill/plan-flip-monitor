with
rawdata as
(
	select
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
   select distinct sql_id, plan_hash_value, avg_lio
   from data
)
, report_data AS
(
	select
		sql_id
		, plan_hash_value
		, sum( execs ) execs
		, min( avg_etime )              min_etime
		, max( avg_etime )              max_etime
		, stddev_etime
		, stddev_etime/min( avg_etime ) norm_stddev
	from data
	group by
		 sql_id
		, plan_hash_value
		, stddev_etime
)
select
	f.schema_name
	, r.sql_id
	, r.plan_hash_value
	, r.execs
	, ( select sum(avg_lio) from lios where sql_id = r.sql_id and plan_hash_value = r.plan_hash_value)/ r.execs avg_lio
	, r.min_etime
	, r.max_etime
	, r.stddev_etime
	, r.norm_stddev
from report_data r
join (
	select distinct parsing_schema_name schema_name, sql_id, plan_hash_value
	from dba_hist_sqlstat
	where parsing_schema_name in ('SYS','SOE')
) f on f.sql_id = r.sql_id and f.plan_hash_value = r.plan_hash_value
--where
   --r.norm_stddev   > nvl( to_number( '&min_stddev' ), 2 )
   --and r.max_etime > nvl( to_number( '&min_etime' ), .001 )
ORDER BY
   schema_name, sql_id
/
