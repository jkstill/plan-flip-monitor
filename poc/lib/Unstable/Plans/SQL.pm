
package SQL;

require Exporter;
our @ISA= qw(Exporter);
our @EXPORT_OK = ( 'getSql');
our $VERSION = '0.01';
use Data::Dumper;

sub getSql{
	my ($sqlName) = @_;
	#print "SQL NAME: $sqlName\n";
	#print Dumper(\%SQL::sql);
	return $SQL::sql{$sqlName};
}


our %sql = ();

%sql = (
	'unstable-plans-baseline-CONTAINER' => q{with
min_snap_id as
(
	select
		min(snap_id) snap_id
	from dba_hist_snapshot
	where begin_interval_time >=  to_timestamp(:1,:3)
		and con_id = sys_context('userenv','con_id')
),
max_snap_id as
(
	select
		max(snap_id) snap_id
	from dba_hist_snapshot
	where end_interval_time <= to_timestamp(:2,:3)
		and con_id = sys_context('userenv','con_id')
),
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
where username not in 
(
   select name schema_to_exclude
   from system.LOGSTDBY$SKIP_SUPPORT
   where action = 0
)
order by norm_stddev},
# end of unstable-plans-baseline-CONTAINER

	'unstable-plans-baseline-LEGACY' => q{with
min_snap_id as
(
	select
		min(snap_id) snap_id
	from dba_hist_snapshot
	where begin_interval_time >=  to_timestamp(:1,:3)
),
max_snap_id as
(
	select
		max(snap_id) snap_id
	from dba_hist_snapshot
	where end_interval_time <= to_timestamp(:2,:3)
),
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
where username not in 
(
   select name schema_to_exclude
   from system.LOGSTDBY$SKIP_SUPPORT
   where action = 0
)
order by norm_stddev},
# end of unstable-plans-baseline-LEGACY

);

1;



