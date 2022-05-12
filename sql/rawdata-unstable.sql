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
		gv$sqlstats	 s
		where 
			executions > 0
			and s.con_id = sys_context('userenv','con_id')
		group by
			sql_id
			, plan_hash_value
