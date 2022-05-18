#!/usr/bin/env perl

#use lib '~/pythian/perl5/lib';

use warnings;
use strict;
use FileHandle;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
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
use Capture::Tiny ':all';

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
my $saveAlerts=0;
my $DEBUG=0;

# saves sql_id and time alerted
my $alertLogCSV="$scriptPath/poc-plan-flip.csv";

# if alerted for a SQL_ID, do not alert again for this many seconds
my $alertFrequency=86400;

# see planflip.conf
my %emailConfig;

# load any configs in planflip.conf

my $configFile="$scriptPath/planflip.conf";

getConfigs($configFile);


my %alerts=();

getAlertTimes($alertLogCSV,\%alerts);

#print Dumper(\%emailConfig);
# test the alert
#$emailConfig{mailsubject} = "unstable plan for sql_id: asdfas234234s";
#$emailConfig{mailmsg} = "sql_id: asdfas234234s found to be unstable";
#sendAlert(\%emailConfig);

#print Dumper(\%alerts);
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
  	"min-stddev=f" => \$defMinNormStddev,
  	"max-exe-time=f" => \$defMinimumMaxEtime,
	"end-time=s" => \$snapEndTime,
	"csv!" => \$csvOutput,
	"csv-delimiter=s" => \$csvDelimiter,
	"send-alerts!" => \$sendAlerts,
	"save-alerts!" => \$saveAlerts,
	"alert-freq=n" => \$alertFrequency,
	"sysdba!",
	"realtime!" => \$realtime,
	"local-sysdba!",
	"sysoper!",
	"debug!" => \$DEBUG,
	'help!'    => sub { pod2usage( -verbose => 1 ) },
	'man!'     => sub { pod2usage( -verbose => 2 ) },
	#"z|h|help" => \$help 
) or pod2usage( -verbose => 1 );

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
my $resultsReport='';  # if sending alerts, capture the report from write to STDOUT[_TOP|
print "Epoch: $currentTime\n" unless $csvOutput;

# capture the output from write

my ($stdoutDATA, $stderrDATA, @result) = capture {

	while ( $ary = $sth->fetchrow_arrayref ) {
		#print join(' - ',@{$ary}) . "\n";
		my $sqlid = $ary->[0];
		my $planHashValue = $ary->[1];

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
		if ( exists $alerts{$sqlid}->{$planHashValue} ) {
			# determine if the last time reported should be updated

			my $deltaTime = ( $currentTime + 0 ) - ( $alerts{$sqlid}->{$planHashValue} + 0);
			debugWarn( "   current time: " . $currentTime . "\n");
			debugWarn( "  previous time: " . $alerts{$sqlid}->{$planHashValue} . "\n");
			debugWarn( "     delta time: " . $deltaTime . "\n");
			debugWarn( "     alert freq: " . $alertFrequency  . "\n");
			debugWarn( "==============================\n");

			if ( $currentTime - $alerts{$sqlid}->{$planHashValue} > $alertFrequency ) {
				$alerts{$sqlid}->{$planHashValue} = $currentTime;
				$sqlidsToReport{$sqlid}->{$planHashValue} = $currentTime;
			}
		} else {
			$alerts{$sqlid}->{$planHashValue} = $currentTime;
			$sqlidsToReport{$sqlid}->{$planHashValue} = $currentTime;
		}
	}
};

print '@result: ' . Dumper(\@result) . "\n" if defined($result[0]);;
#print '%sqlidsToReport: ' . Dumper(\%sqlidsToReport) . "\n";
# update the list of plan-flips found

saveAlertTimes($alertLogCSV,\%alerts) if $saveAlerts;

# this is the report or csv
print "$stdoutDATA";
warn "\nSTDERR: $stderrDATA\n" if $stderrDATA;

if ($sendAlerts && %sqlidsToReport ) {
	warn "Sending alerts!\n";
	$emailConfig{mailsubject} = "unstable plan report";
	$emailConfig{mailmsg} = '';
	foreach my $sqlid ( keys %sqlidsToReport ) {
		$emailConfig{mailmsg} .= "\nsql_id: $sqlid";
	}
	$emailConfig{mailmsg} .= "$stdoutDATA\n";
	sendAlert(\%emailConfig);
}

$dbh->disconnect;

exit;

#c13sma6rkr27c 234234234234   31,692,872 SOE                        0.0       4        0.0064137        0.0113004       0.0020        0.3187
format STDOUT_TOP = 
                                                                          PLAN
SQL_ID        PLAN HASH           EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
------------- ------------ ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
.

format STDOUT =
@<<<<<<<<<<<< @########### @########### @<<<<<<<<<<<<< @##########.###  @##### @#######.####### @#######.####### @#######.####### @#######.#######
@{$ary}
.


##################################
### end of main                ###
##################################

=head1 SYNOPSIS

 Catch plan flips that have caused a performance degradation

 This script checks calculated the stddev for SQL execution times.

 Detect USER SQL where executions are outside the stddev of execution times
 Currently the values to detect these are hardcoded to a low value.

 By default DBA_HIST views are used to look at historical data. 
 'Historical' can be as recent as the most recent snapshot-1, snapshot.

 The --realtime option will instead look at realtime data in gv\$sqlstats

 The script will report on SQL statements where these criteria are met:

   --min-stddev   normalized stddev of execution time is N.N of stddev - default is 0.001
   --max-exe-time the maximum execution time is N.N seconds or more - default is 0.001

 The defaults will likely catch a few SQL statements.  

 Using the defaults gets a report that may be used to tune the values for --min-stddev and --min-exe-time

 When the stddev of some executions exceeds a threshold, AND the longest execution time passes a threshold,
 the SQL and Plan Hash value are reported.

 Optionally, an email can be sent showing the reports and list of sql_id and plan_hash_value.

 examples:

 This command will look through AWR and find user SQL that exceeds the thresholds

 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --database //rac-scan/swingbench --username somedba --password XXX --begin-time '2022-05-10 00:00:00' --end-time '2022-05-12 23:00:00'  --min-stddev  20
 Major/Minor version 19/0

 running query for unstable-plans-baseline-historic-CONTAINER

  format: yyyy-mm-dd hh24:mi:ss
   start: 2022-05-10 00:00:00
     end: 2022-05-12 23:00:00
 Epoch: 1652827438
                                                                          PLAN
 SQL_ID        PLAN HASH           EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
 ------------- ------------ ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
 56pwkjspvmg3h   1448083145        59561 SOE                    138.569       2        4.7552763        4.7552763      122.1845768       25.6945275
 gkxxkghxubh1a   2220165490        59234 SOE                    139.322       2        4.7165040        4.7165040      199.9986083       42.4039942
 7hk2m2702ua0g   2307454521           11 SOE                    160.964       6        1.1280896        1.1280896       58.5730151       51.9223059
 29qp10usqkqh0   1055577880       119025 SOE                      3.526       3        0.1557687        0.1557687      168.6800624     1082.8879105
 8zz6y2yzdqjp0    574689976       595704 SOE                      0.004       2        0.0169154        0.0169154       31.9432872     1888.4093678
 7hk2m2702ua0g   2048963432       294374 SOE                      0.010       6        0.0280221        0.0280221       58.5730151     2090.2412237
 7ws837zynp1zv   3722429161      2382907 SOE                      0.000       2        0.0050973        0.0050973       20.4907658     4019.9639761
 7t0959msvyt5g    856749079       894670 SOE                      0.003       2        0.0122687        0.0122687       75.2371300     6132.4693216
 1qf3b7a46jm3u   1322380957       894727 SOE                      0.001       2        0.0094323        0.0094323       78.7726617     8351.3943886
 g81cbrq5yamf5   2480532011      3278664 SOE                      0.000       2        0.0062281        0.0062281       55.1291887     8851.6471375


 The previous command used the '--min-stddev 20' argument to limit the SQL found.

 The '-max-exe-time 3' option is now used to show only those SQL statements that at some time in this period had an elapsed time exceeding 3 seconds.

 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --database //rac-scan/swingbench --username somedba --password XXX --begin-time '2022-05-10 00:00:00' --end-time '2022-05-12 23:00:00'  --min-stddev  20 --max-exe-time 3
 Major/Minor version 19/0

  running query for unstable-plans-baseline-historic-CONTAINER

   format: yyyy-mm-dd hh24:mi:ss
    start: 2022-05-10 00:00:00
      end: 2022-05-12 23:00:00
 Epoch: 1652830981
                                                                           PLAN
 SQL_ID        PLAN HASH           EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
 ------------- ------------ ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
 56pwkjspvmg3h   1448083145        59561 SOE                    138.569       2        4.7552763        4.7552763      122.1845768       25.6945275
 gkxxkghxubh1a   2220165490        59234 SOE                    139.322       2        4.7165040        4.7165040      199.9986083       42.4039942
 

 Should you find a period that represents good perfomance, you may use the --save-alerts option.

 Doing so will save the sql_id, plan_hash_value, and the current time to poc-plan-flip.csv file.

 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --database //rac-scan/swingbench --username somedba --password XXX --begin-time '2022-05-10 00:00:00' --end-time '2022-05-12 23:00:00'  --min-stddev  20 --max-exe-time 3
 Major/Minor version 19/0

  running query for unstable-plans-baseline-historic-CONTAINER

   format: yyyy-mm-dd hh24:mi:ss
    start: 2022-05-10 00:00:00
      end: 2022-05-12 23:00:00
 Epoch: 1652831362
                                                                           PLAN
 SQL_ID        PLAN HASH           EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
 ------------- ------------ ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
 56pwkjspvmg3h   1448083145        59561 SOE                    138.569       2        4.7552763        4.7552763      122.1845768       25.6945275
 gkxxkghxubh1a   2220165490        59234 SOE                    139.322       2        4.7165040        4.7165040      199.9986083       42.4039942

 $  cat poc-plan-flip.csv
 56pwkjspvmg3h,1448083145,1652831362
 gkxxkghxubh1a,2220165490,1652831362

 The poc-plan-flip.csv is used when the --send-alerts option is used. 

 If the time recorded in 'poc-plan-flip.csv' is less than the current (epoch) time - 86400, an alert will not be sent.

 The amount of time before sending an alert again can be altered with the '--alert-freq' option.

 The '--realtime' option can now be used to look for SQL statements whose execution time has become excessive.

 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --realtime --database //rac-scan/swingbench --username somedba --password XXX  --min-stddev  20 --max-exe-time 3 --save-alerts --send-alerts 
 
 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --realtime --database //rac-scan/swingbench --username jkstill --password XXX realtime --send-alerts --save-alerts  --min-stddev 0.05
 Major/Minor version 19/0


  running query for unstable-plans-baseline-realtime-CONTAINER
 Epoch: 1652827081
                                                                           PLAN
 SQL_ID        PLAN HASH           EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
 ------------- ------------ ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
 29qp10usqkqh0   3619984409            1 SOE                 436363.000       2      244.2520940      244.2520940       17.5796194        0.0719733
 29qp10usqkqh0    388976350            9 SOE                 123335.605       2      219.3907579      219.3907579       17.5796194        0.0801293
 Sending alerts!

 The next time the script is run, it will not alert:
  
 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --realtime --database //rac-scan/swingbench --username jkstill --password XXX realtime --send-alerts --save-alerts  --min-stddev 0.05
 Major/Minor version 19/0


  running query for unstable-plans-baseline-realtime-CONTAINER
 Epoch: 1652827112


 Alerts can be forced by using '--alert-freq 0'. This also causes the alert time to be updated in the 'poc-plan-flip.csv'.

 $ $ORACLE_HOME/perl/bin/perl ./poc-unstable-plans.pl --alert-freq 0 --realtime --database //rac-scan/swingbench --username jkstill --password XXX realtime --send-alerts --save-alerts  --min-stddev 0.05
 Major/Minor version 19/0


  running query for unstable-plans-baseline-realtime-CONTAINER
 Epoch: 1652827256

                                                                           PLAN
 SQL_ID        PLAN HASH           EXECS USERNAME               AVG_LIO   COUNT        MIN_ETIME        MAX_ETIME     STDDEV_ETIME      NORM_STDDEV
 ------------- ------------ ------------ --------------- -------------- ------- ---------------- ---------------- ---------------- ----------------
 29qp10usqkqh0   3619984409            1 SOE                 436363.000       2      244.2520940      244.2520940       17.5796194        0.0719733
 29qp10usqkqh0    388976350            9 SOE                 123335.605       2      219.3907579      219.3907579       17.5796194        0.0801293
 Sending alerts!


=head1 OPTIONS

=over


=item --database target instance

 set the target instance to connect to

=item --username

 target instance account name


=item --password

 target instance account password


=item --sysdba
	 
 logon as sysdba


=item --csv

 switch to CSV output


=item --begin-time

 earliest time to check AWR, in 'YYYY-MM-DD HH24:MI:SS' format


=item --end-time

 latest time to check AWR, in 'YYYY-MM-DD HH24:MI:SS' format


=item --realtime

 look at realtime data in gv$sqlstats.
 the --begin-time and --end-time arguments are ignored


=item --min-stddev

minimum value of normalized stddev exe times to look for - defaults to 0.001

=item --max-exe-time

minimum value of max execution time to look for  - defaults to 0.001

=item --send-alerts

send alert emails - default is to not send alerts

=item --save-alerts

save alert history - default is to not save alert history
when used with --send-alerts and --alert-freq it is used to control when alerts are sent


=item --alert-freq

 how many seconds until the next alert is sent for a SQL_ID. 
 default is 86400

=item --sysoper

 logon as sysoper

=item --local-sysdba

 logon to local instance as sysdba. ORACLE_SID must be set

 the following options will be ignored:
   --database
   --username
   --password

=back

=head1 Config file 'planflip.conf'

 The optional configuration file is 'planflip.conf'.

 This is really just Perl code that is evaluated at runtime.

 Any values found in the config file will override built-in defaults.

 Values entered via command line option will override defaults as well as the values in the config file.

 Example configfile 'planflip.conf':

   # this is really just perl code that is read at runtime.
   # this is safe in this context, that is, anyone with access to this config file
   # also has access to the perl script

   # call this after the variables have been declared in the main script
   #
   %emailConfig = (

	   mailfrom => 'oracle@yourdomain.com',
	   mailto => 'somedba-01@yourdomain.com,somedba-02@yourdomain.com',
	   mailsubject => 'unstable plans report',
	   mailmsg => 'this is the body of the email and will be replaced programmatically',

   );

   # only change these if necessary, as they will override the defaults
   # the command line options will override the settings below here


   #$csvOutput=1;
   #$csvDelimiter='|';
   #$timeScope='realtime';
   #$realtime=1;
   #$defMinNormStddev=0.010;
   #$defMinimumMaxEtime=0.5;

=head1 Sending Mail

 It is assumed the host machine has smtp or ssmtp configured and it is available to the user running this script.

 If that is not the case, then the '--send-alerts' option will not work properly.

=head1 Suggested Strategy

 * find a period that represents decent performance with the --begin-time and --end-time options
 * use the --save-alerts option
 * use cron or a scheduler to run with these options
  --realtime
  --save-alerts
  --send-alerts

=cut

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

sub getConfigs {
	my ($configFile) = @_;

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
}

sub getEpoch {
	return timelocal(localtime);
}

sub saveAlertTimes {
	my ($alertLogName, $alertsHashRef) = @_;
	my $fh = IO::File->new($alertLogCSV,'w') or die "could not open $alertLogCSV for writing - $!\n";
	foreach my $sqlid ( sort keys %alerts ) {
		my %plans = %{$alerts{$sqlid}};
		foreach my $planHash ( sort keys %plans ) {
			print $fh "$sqlid,$planHash,$alerts{$sqlid}->{$planHash}\n";
		}
	}
	$fh->close;
}

sub getAlertTimes {
	my ($alertLogName, $alertsHashRef) = @_;
	if ( -r $alertLogName ) {
		my $fh = IO::File->new($alertLogName,'r') or die "could not open $alertLogName - $!\n";
		while (<$fh>) {
			chomp;
			my ($sqlid,$planHash,$alertTime)=split(',');
			$alertsHashRef->{$sqlid}{$planHash} = $alertTime;
		}
		$fh->close;
	}
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

# send a string
sub debugWarn {
	warn "$_[0]" if $DEBUG;
}

# send a string
sub debugPrint {
	print "$_[0]" if $DEBUG;
}


