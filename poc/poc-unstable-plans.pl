#!/usr/bin/env perl

#use lib '~/pythian/perl5/lib';

use warnings;
use strict;
use FileHandle;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Time::Local;
use IO::File;
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
use Mail::Simple;

#exit;

# set the start time to get recent values for baselines
my $timestampFormat = 'yyyy-mm-dd hh24:mi:ss';
#my $snapStartTime = '2022-05-01 00:00:00';
#my $snapEndTime = '2022-05-31 00:00:00';
my $snapStartTime='';
my $snapEndTime='';
my $csvOutput=0;
my $csvDelimiter=',';
my $timeScope='historic';
my $realtime=0;
my $defMinNormStddev=0.001;
my $defMinimumMaxEtime=0.001;
my $sendAlerts=0;

# saves sql_id and time alerted
my $alertLogCSV='./poc-plan-flip.csv';

# if alerted for a SQL_ID, do not alert again for this many seconds
my $alertFrequency=86400;

# see planflip.conf
my %emailConfig;

# load any configs in planflip.conf

my $configFile="$scriptPath/planflip.conf";

if ( -r $configFile ) {
	my $fh = IO::File->new($configFile,'r') or die "could not open $configFile = $!";
	my @config=<$fh>;
	my $cmd=join('',@config);
	#print "cmd: $cmd\n";
	eval $cmd;

	if ($@) {
		warn "Error!\n";
		die "error processing configfile: $configFile - $!\n";
	}
	$fh->close;

}

my %alerts=();

if ( -r $alertLogCSV ) {
	my $fh = IO::File->new($alertLogCSV,'r') or die "could not open $alertLogCSV = $!";
	while (<$fh>) {
		chomp;
		my ($sqlid,$alertTime)=split(',');
		$alerts{$sqlid} = $alertTime;
	}
	$fh->close;
}

#print Dumper(\%emailConfig);
# test the alert
#$emailConfig{mailsubject} = "unstable plan for sql_id: asdfas234234s";
#$emailConfig{mailmsg} = "sql_id: asdfas234234s found to be unstable";
#sendAlert(\%emailConfig);

#exit;

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
  	"min-stddev=n" => \$defMinNormStddev,
  	"max-exe-time=n" => \$defMinimumMaxEtime,
	"end-time=s" => \$snapEndTime,
	"csv!" => \$csvOutput,
	"csv-delimiter=s" => \$csvDelimiter,
	"send-alerts!" => \$sendAlerts,
	"alert-freq=n" => \$alertFrequency,
	"sysdba!",
	"realtime!" => \$realtime,
	"local-sysdba!",
	"sysoper!",
	"z|h|help" => \$help );

$localSysdba=$optctl{'local-sysdba'};

if ( $help ){ usage(0); }

# if realtime we do not care about start and stop times
if ( $realtime ) {
	$timeScope='realtime';
} else {
	if ( ! isDateValid($snapStartTime)) {
		warn "invalid date: $snapStartTime\n";
		usage(1);
	}
	if ( ! isDateValid($snapEndTime)) {
		warn "invalid date: $snapEndTime\n";
		usage(1);
	}
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

my $sql='';
my $sqlName="unstable-plans-baseline-${timeScope}-${dbType}";

eval {
	$sql = SQL::getSql($sqlName);
	die unless $sql;
};

if ($@) {
	$dbh->disconnect;
	die "failed to get SQL '$sqlName'\n";
}

#print qq(testsql: $sql\n);
my $sth=$dbh->prepare($sql);

if ( ! $csvOutput ) {

	print qq{

 running query for $sqlName
};
	if ( ! $realtime ) {
		print qq{
  format: $timestampFormat
   start: $snapStartTime
     end: $snapEndTime
};
};
}

if ($realtime) {
	$sth->execute($defMinNormStddev,$defMinimumMaxEtime);
} else {
	$sth->execute($defMinNormStddev,$defMinimumMaxEtime,$snapStartTime, $snapEndTime, $timestampFormat);
}

my $decimalPlaces=6;
my $decimalFactor=10**$decimalPlaces;

my $ary;
my $csvHdrPrinted=0;
my %sqlidsToReport=();
my $currentTime=getEpoch();
print "Epoch: $currentTime\n";

while ( $ary = $sth->fetchrow_arrayref ) {
	#print join(' - ',@{$ary}) . "\n";
	my $sqlid = $ary->[0];

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
			if ( $value =~ /^[[:digit:]\.]+$/ ) { # numeric - assuming at most 1 decimal point
				$value = int($value * $decimalFactor) / $decimalFactor;
				my $tmpVal = sprintf("%9.${decimalPlaces}f", $value); $tmpVal =~ s/\s+//g;
				$data[$el] = $tmpVal;
			}
		}

		print join(qq/$csvDelimiter/,@data) . "\n";
	} else {
		write;
	}

	#warn "SQLID: $sqlid\n";
	if ( exists $alerts{$sqlid} ) {
		# determine if the last time reported should be updated
		if ( $alerts{$sqlid} - $currentTime > $alertFrequency ) {
			$alerts{$sqlid} = $currentTime;
			$sqlidsToReport{$sqlid} = $currentTime;
		}
	} else {
		$alerts{$sqlid} = $currentTime;
		$sqlidsToReport{$sqlid} = $currentTime;
	}

}

#print '%sqlidsToReport: ' . Dumper(\%sqlidsToReport) . "\n";
# update the list of plan-flips found

my $fh = IO::File->new($alertLogCSV,'w') or die "could not open $alertLogCSV = $!";
foreach my $sqlid ( keys %alerts ) {
	print $fh "$sqlid,$alerts{$sqlid}\n";
}
$fh->close;

if ($sendAlerts && %sqlidsToReport ) {
	warn "Sending alerts!\n";
	$emailConfig{mailsubject} = "unstable plan report";
	$emailConfig{mailmsg} = '';
	foreach my $sqlid ( keys %sqlidsToReport ) {
		$emailConfig{mailmsg} .= "\nsql_id: $sqlid";
	}
	sendAlert(\%emailConfig);
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

Detect USER SQL where executions are outside the stddev of execution times
Currently the values to detect these are hardcoded to a low value.

By default DBA_HIST views are used to look at historical data. 
'Historical' can be as recent as the most recent snapshot-1, snapshot.

The --realtime option will instead look at realtime data in gv\$sqlstats

The script will report on SQL statements where these criteria are met:

 normalized stddev of execution time is N.N of stddev - default is 0.001
 the maximum execution time is N.N seconds or more - default is 0.001

The defaults will likely catch a few SQL statements.  

Using the defaults gets a report that may be used to tune the values for --min-stddev and --min-exe-time


  --database      target instance
  --username      target instance account name
  --password      target instance account password
  --sysdba        logon as sysdba
  --csv           switch to CSV output
  --begin-time    earliest time to check AWR, in 'YYYY-MM-DD HH24:MI:SS' format
  --end-time      latest time to check AWR, in 'YYYY-MM-DD HH24:MI:SS' format
  --realtime      look at realtime data in gv\$sqlstats.
                  the --begin-time and --end-time arguments are ignored
  --min-stddev    minimum value of normalized stddev exe times to look for - defaults to 0.001
  --max-exe-time  minimum value of max execution time to look for  - defaults to 0.001
  --send-alerts   send alert emails - default is to not send alerts
  --alert-freq    how many seconds until the next alert is sent for a SQL_ID. default is 86400
  --sysoper       logon as sysoper
  --local-sysdba  logon to local instance as sysdba. ORACLE_SID must be set
                  the following options will be ignored:
                   --database
                   --username
                   --password

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

sub getEpoch {
	return timelocal(localtime);
}

sub sendAlert {
	my %alertInfo = %{$_[0]};
	mailit(
		$alertInfo{mailto},
		$alertInfo{mailfrom},
		$alertInfo{mailsubject},
		$alertInfo{mailmsg},
	);
}

