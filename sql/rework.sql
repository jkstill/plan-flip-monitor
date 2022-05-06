with
rawdata as
(
	select
		sql_id
		, plan_hash_value
		, sum( nvl( executions_delta, 0 ) ) execs
		,
		(
			sum(elapsed_time_delta) / 
			decode
			( 
				sum( nvl( executions_delta, 0 ) )
				, 0, 1
				, sum( executions_delta ) 
			) / 1000000 
		) avg_etime
		,
		sum ( buffer_gets_delta /
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
		, avg_etime
		--, avg_lio
		, stddev( avg_etime ) over( partition BY sql_id ) stddev_etime
	from
	rawdata
)
, report_data AS
(
	select
	sql_id
		, sum( execs )
		--, avg_lio
		, min( avg_etime )              min_etime
		, max( avg_etime )              max_etime
		, stddev_etime
		, stddev_etime/min( avg_etime ) norm_stddev
	from data
	group by
		sql_id
		, stddev_etime
		--, avg_lio
)
select *
from
   report_data
where
   norm_stddev   > nvl( to_number( '&min_stddev' ), 2 )
   and max_etime > nvl( to_number( '&min_etime' ), .1 )
ORDER BY
   norm_stddev
/
