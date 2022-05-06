#!/usr/bin/env perl

#use lib '~/pythian/perl5/lib';

use warnings;
use strict;
use FileHandle;
use DBI;
use Getopt::Long;
use Data::Dumper;


# set the start time to get recent values for baselines
my $timestampFormat = 'yyyy-mm-dd hh24:mi:ss';
#my $snapStartTime = '2022-05-01 00:00:00';
#my $snapEndTime = '2022-05-31 00:00:00';
my $snapStartTime;
my $snapEndTime;
my $csvOutput=0;
my $csvDelimiter=',';

my %optctl = ();

my($db, $username, $password, $connectionMode, $localSysdba);
my($adjustCols);
$adjustCols=0;
my $sysdba=0;
my $help=0;

Getopt::Long::GetOptions(
	\%optctl,
	"database=s" => \$db,
	"username=s" => \$username,
	"password=s" => \$password,
	"begin-time=s" => \$snapStartTime,
	"end-time=s" => \$snapEndTime,
	"csv!" => \$csvOutput,
	"csv-delimiter=s" => \$csvDelimiter,
	"sysdba!",
	"local-sysdba!",
	"sysoper!",
	"z|h|help" => \$help );

$localSysdba=$optctl{'local-sysdba'};

if ( $help ){ usage(0); }

if ( ! isDateValid($snapStartTime)) {
	die "invalid date: $snapStartTime\n";
}
if ( ! isDateValid($snapEndTime)) {
	die "invalid date: $snapEndTime\n";
}

if (! $localSysdba) {

	$connectionMode = 0;
	if ( $optctl{sysoper} ) { $connectionMode = 4 }
	if ( $optctl{sysdba} ) { $connectionMode = 2 }

	usage(1) unless ($db and $username and $password);
}


#print qq{
#
#USERNAME: $username
#DATABASE: $db
#PASSWORD: $password
    #MODE: $connectionMode
 #RPT LVL: @rptLevels
#};
#exit;


$|=1; # flush output immediately

sub getOraVersion($$$);

my $dbh ;

if ($localSysdba) {
	$dbh = DBI->connect(
		'dbi:Oracle:',undef,undef,
		{
			RaiseError => 1,
			AutoCommit => 0,
			ora_session_mode => 2
		}
	);
} else {
	$dbh = DBI->connect(
		'dbi:Oracle:' . $db,
		$username, $password,
		{
			RaiseError => 1,
			AutoCommit => 0,
			ora_session_mode => $connectionMode
		}
	);
}

die "Connect to  $db failed \n" unless $dbh;
$dbh->{RowCacheSize} = 100;

# workaround for ORA-12850 that sometimes happens on 19c
# ORA-12850: COULD NOT ALLOCATE SLAVES ON ALL SPECIFIED on 19c (or SPM Baseline not Used) (Doc ID 2846240.1)
$dbh->do('alter session disable parallel query');

# get the major and minor version of the instance
my ($majorOraVersion, $minorOraVersion);
getOraVersion (
		\$dbh,
		\$majorOraVersion,
		\$minorOraVersion,
);

## LEGACY or CONTAINER
my $dbType = getDbType($dbh,$majorOraVersion);

if ( ! $csvOutput ) {
	print "Major/Minor version $majorOraVersion/$minorOraVersion\n";
}
my $dbVersion="${majorOraVersion}.${minorOraVersion}" * 1; # convert to number

my $sql = SQL::getSql('unstable-plans-baseline-' . $dbType);

#print qq(testsql: $sql\n);
my $sth=$dbh->prepare($sql);

if ( ! $csvOutput ) {
	print qq{

 running query for unstable-plans-baseline-$dbType
   start: $snapStartTime
     end: $snapEndTime
  format: $timestampFormat

};
}

$sth->execute($snapStartTime, $snapEndTime, $timestampFormat);

my $decimalPlaces=6;
my $decimalFactor=10**$decimalPlaces;

my $ary;
my $csvHdrPrinted=0;
while ( $ary = $sth->fetchrow_arrayref ) {
	#print join(' - ',@{$ary}) . "\n";
	if ($csvOutput) {
		# should not be any undef or null values in this array
		if ( ! $csvHdrPrinted ) {
			$csvHdrPrinted=1;
			print join(qq/$csvDelimiter/, @{ $sth->{NAME_lc} }) . "\n";
		}
		# it would be nice if there were some global setting to limit decimal places in perl.
		# then just print the array
		# limit to 6 decimal places
		my @data=@{$ary};
		foreach my $el ( 0 .. $#data ) {
			# is it a number?
			my $value = $data[$el];
			if ( $value =~ /^[[:digit:]\.]+$/ ) {
				$value = int($value * $decimalFactor) / $decimalFactor;
				$data[$el] = $value	;
			}
		}

		print join(qq/$csvDelimiter/,@data) . "\n";
	} else {
		write;
	}
}

$dbh->disconnect;

exit;

#c13sma6rkr27c   31,692,872 SOE                        0.0       4        0.0064137        0.0113004       0.0020        0.3187
format STDOUT_TOP = 
                                                             PLAN
SQL_ID               EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
------------- ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
.

format STDOUT =
@<<<<<<<<<<<< @########### @<<<<<<<<<<<<< @##########.###  @##### @#######.####### @#######.####### @#######.####### @#######.#######
@{$ary}
.

##################################
### end of main                ###
##################################

sub usage {
	my $exitVal = shift;
	$exitVal = 0 unless defined $exitVal;
	use File::Basename;
	my $basename = basename($0);
	print qq{

usage: $basename

  -database      target instance
  -username      target instance account name
  -password      target instance account password
  -sysdba        logon as sysdba
  -csv           switch to CSV output
  -begin-time    earliest time to check AWR, in 'YYYY-MM-DD HH24:MI:SS' format
  -end-time      latest time to check AWR, in 'YYYY-MM-DD HH24:MI:SS' format
  -sysoper       logon as sysoper
  -local-sysdba  logon to local instance as sysdba. ORACLE_SID must be set
                 the following options will be ignored:
                   -database
                   -username
                   -password

  examples:

  Remote SYSDBA
  \$ORACLE_HOME/perl/bin/perl  $basename  -database someserver/orcl.yourdomain.com -sysdba -username sys -password XXXX -begin-time '2022-05-04 00:00:00' -end-time '2022-05-04 08:00:00'

  Remote DBA
  \$ORACLE_HOME/perl/bin/perl  $basename  -database someserver/orcl.yourdomain.com -sysdba -username dbauser -password XXXX -begin-time '2022-05-04 00:00:00' -end-time '2022-05-04 08:00:00'

  Local SYSDBA
  \$ORACLE_HOME/perl/bin/perl  $basename  -database someserver/orcl.yourdomain.com -local-sysdba  -begin-time '2022-05-04 00:00:00' -end-time '2022-05-04 08:00:00'

};
   exit $exitVal;
};

sub getDbType {
	my ($dbh,$majorOraVersion) = @_;
# this test determines which sql is used
# sql for CDB includes 'con_id = ...'
if ( $majorOraVersion >= 12 ) {
	# check if container database
	my $sql = q{select sys_context('userenv','con_id') con_id from dual};
	#$sql = q{select sys_context('userenv','legacy-testing') con_id from dual};
	my $sth = $dbh->prepare($sql);
	eval {
		local $sth->{PrintError};
		$sth->execute;
	};

	if ($@) {
		# check for invalid userenv parameter
		# not a container database
		unless ( $@ =~ /userenv/i ) {
			$dbh->disconnect;
			die $@ . "\n";
		}
		return 'LEGACY';
	} else {
		my $conID = $sth->fetchrow;
		$sth->finish;	
		#print "conID: $conID\n";
		#$dbType='CONTAINER';
		return 'CONTAINER';
	}

	#$dbh->disconnect;
	#print "DB Type: $dbType\n";
	#exit;
} else {
	return 'LEGACY';
}
}

sub getOraVersion($$$) {
	my ($dbh,$major,$minor) = @_;

	my $sql=q{select
	substr(version,1,instr(version,'.')-1) major_version
	, substr (
		substr(version,instr(version,'.')+1), -- following the first '.'
		1, -- start at the first character
		instr(substr(version,instr(version,'.')+1),'.')-1 -- everything before the first '.'
	) minor_version
from v$instance};

	my $sth = $$dbh->prepare($sql,{ora_check_sql => 0});
	$sth->execute;
	($$major,$$minor) = $sth->fetchrow_array;

}

# not robust, but will catch some errors
sub isDateValid {
	my $date2Chk = $_[0];

	if ( 
		$date2Chk =~ /^
		[[:digit:]]{4}-   # year
		[0-1]{1}          # month
		[[:digit:]]{1}-   # month
		[0-3]{1}          # day
		[[:digit:]]{1}\s+ # day
		[0-2]{1}          # hour
		[[:digit:]]{1}:   # hour
		[[:digit:]]{2}:   # minute
		[0-6]{1}          # seconds
		[[:digit:]]{1}    # seconds
		/x 
	) {
		return 1;
	} else {
		return 0;
	}
}

package SQL;

require Exporter;
our @ISA= qw(Exporter);
our @EXPORT_OK = ( 'getSql');
our $VERSION = '0.01';
use Data::Dumper;

BEGIN {

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

}

1;



