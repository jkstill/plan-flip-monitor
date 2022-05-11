#!/usr/bin/env perl

#use lib '~/pythian/perl5/lib';

use warnings;
use strict;
use FileHandle;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Cwd qw/abs_path/ ;

my $scriptPath;

# this BEGIN block allows setting lib to include the full path for loading Unstable::Plans::SQL
# works regardless which directory the cmd is issued from
BEGIN {

	#print "abs path:" . abs_path($0) . "\n";

	my @scriptPath=split('/',abs_path($0));

	shift @scriptPath; # remove '' resulting from leading /
	my $scriptName = pop @scriptPath; # script name
	$scriptPath='/' . join('/',@scriptPath);

	#print "scriptPath: $scriptPath\n";
	#print Dumper(\@scriptPath);
	#print "script: $scriptName\n";

} 

use lib "$scriptPath/lib";
use Unstable::Plans::SQL;

#exit;

# set the start time to get recent values for baselines
my $timestampFormat = 'yyyy-mm-dd hh24:mi:ss';
#my $snapStartTime = '2022-05-01 00:00:00';
#my $snapEndTime = '2022-05-31 00:00:00';
my $snapStartTime='';
my $snapEndTime='';
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
	warn "invalid date: $snapStartTime\n";
	usage(1);
}
if ( ! isDateValid($snapEndTime)) {
	warn "invalid date: $snapEndTime\n";
	usage(1);
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


