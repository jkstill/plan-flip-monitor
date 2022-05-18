
package SQL;

require Exporter;
our @ISA= qw(Exporter);
our @EXPORT_OK = ( 'getSql');
our $VERSION = '0.01';
use Data::Dumper;

sub getSql{
	my ($sqlName,$dbType) = @_;
	print "SQL NAME: $sqlName\n";
	#print Dumper(\%SQL::sql);

	my $sql =  $SQL::sql{$sqlName};

	if ( $dbType eq 'CONTAINER' ) {
		$sql =~ s/<<CONTAINER-CLAUSE>>/$SQL::sql{'con-id-clause'}/g;
	} else {
		$sql =~ s/<<CONTAINER-CLAUSE>>//g;
	}

	return $sql;
}


our %sql = ();

=head1 bind variables

 unstable-plans-baseline-[historic|realtime]-[CONTAINER|LEGACY]

   :1 low value for norm_stddev
	:2 low value for max_etime

 unstable-plans-baseline-historicrealtime-[CONTAINER|LEGACY]
  
	:3 begin_time
	:4 end_time
	:5 date_format

=cut


%sql = (
	'con-id-clause' => q{and con_id = sys_context('userenv','con_id')},

	'unstable-plans-baseline-historic' => q{with
min_snap_id as
(
	select
		min(snap_id) snap_id
	from dba_hist_snapshot
	where begin_interval_time >=  to_timestamp(:3,:5) <<CONTAINER-CLAUSE>>
),
max_snap_id as
(
	select
		max(snap_id) snap_id
	from dba_hist_snapshot
	where end_interval_time <= to_timestamp(:4,:5) <<CONTAINER-CLAUSE>>
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
			and executions_delta > 0
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
, plan_counts as (
	select distinct
		sql_id
		, count(*) over (partition by sql_id order by sql_id) plan_count
	from rawdata
)
, report_data AS
(
	select
	sql_id, plan_hash_value
		, sum( execs ) execs
		, min( avg_etime )              min_etime
		, max( avg_etime )              max_etime
		, stddev_etime
		, stddev_etime/min( avg_etime ) norm_stddev
	from data
	group by
		sql_id
		, stddev_etime
		, plan_hash_value
),
getuser as (
	select
		r.sql_id
		, r.plan_hash_value
		, r.execs
		, (select max(parsing_schema_name) from gv$sqlarea where sql_id = r.sql_id) username
		, ( select sum(avg_lio) from lios where sql_id = r.sql_id and plan_hash_value = r.plan_hash_value)/ r.execs avg_lio
		, ( select plan_count from plan_counts where sql_id = r.sql_id) plan_count
		, r.min_etime
		, r.max_etime
		, r.stddev_etime
		, r.norm_stddev
	from report_data r
	where
   	r.norm_stddev > :1
   	and r.max_etime > :2
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
order by sql_id, plan_hash_value},
#order by norm_stddev},
# end of unstable-plans-baseline-CONTAINER


	'unstable-plans-baseline-realtime' => q{with
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
      where executions > 0 <<CONTAINER-CLAUSE>>
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
, plan_counts as (
	select distinct
		sql_id
		, count(*) over (partition by sql_id order by sql_id) plan_count
	from rawdata
)
, report_data AS
(
	select
	sql_id, plan_hash_value
		, sum( execs ) execs
		, min( avg_etime )              min_etime
		, max( avg_etime )              max_etime
		, stddev_etime
		, stddev_etime/min( avg_etime ) norm_stddev
	from data
	group by
		sql_id
		, stddev_etime
		, plan_hash_value
),
getuser as (
	select
		r.sql_id
		, r.plan_hash_value
		, r.execs
		, (select max(parsing_schema_name) from gv$sqlarea where sql_id = r.sql_id) username
		, ( select sum(avg_lio) from lios where sql_id = r.sql_id and plan_hash_value = r.plan_hash_value)/ r.execs avg_lio
		, ( select plan_count from plan_counts where sql_id = r.sql_id) plan_count
		, r.min_etime
		, r.max_etime
		, r.stddev_etime
		, r.norm_stddev
	from report_data r
	where
   	r.norm_stddev > :1
   	and r.max_etime > :2
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
order by sql_id, plan_hash_value},
#order by norm_stddev},
# end of unstable-plans-baseline-CONTAINER

);

1;



