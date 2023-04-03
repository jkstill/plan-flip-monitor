#!/usr/bin/env bash

# driver for poc-unstable-plans.pl

# cd to script location
declare relPath=$(dirname $0)
cd $relPath || { echo "could not cd to '$relPath'"; exit 1; }
declare scriptPath=$(pwd)
cd $scriptPath || { echo "could not cd to '$scriptPath'"; exit 2; }

# set Y if running bequeath connection
declare LOCAL_SYSDBA=N

# this does not matter if LOCAL_SYSDBA == Y
declare SYSDBA=N
declare USERNAME=''
declare PASSWORD=''
declare DATABASE=''
declare DBNAME=''

usage () {
cat <<-EOF

 driver for poc-unstable-plans.pl

 Get report of unstable plans for past 24 hrs
 1 report per hour
 1 report for the day

 -Ss    SYSDBA
 -Ll    LOCAL_SYSDBA
 -Uu    Username
 -Pp    Password
 -Dd    database for connect string
 -Nn    database name for log files
 -HhZz  help

 examples:

 ./poc-unstable-plans.sh -u soe -p soe -d someserver/swingbench.yourdomain.com  -n swingbench
 
 ./poc-unstable-plans.sh -s -u sys -p sys -d someserver/swingbench.yourdomain.com  -n swingbench

 ./poc-unstable-plans.sh -L -n swingbench

EOF
}

while getopts U:u:P:p:D:d:N:n:hHzZLlSs arg
do
	case $arg in
		S|s) SYSDBA=Y;;
		L|l) LOCAL_SYSDBA=Y;;
		U|u) USERNAME="$OPTARG";;
		P|p) PASSWORD="$OPTARG";;
		D|d) DATABASE="$OPTARG";;
		N|n) DBNAME="$OPTARG";;
		H|h|Z|z) usage; exit 0;;
		*) echo "unknown option"; usage; exit 2;;
	esac
done

[[ -z "$DBNAME" ]] && { echo "please use the -n option"; exit 1; }
[[ $LOCAL_SYSDBA == 'N' ]] && {
	[[ -z "$DATABASE" ]] && { echo "please use the -d option"; exit 1; } # not required for bequeath
	[[ -z "$USERNAME" ]] && { echo "please use the -u option"; exit 1; } # not require
}

declare perlScript='./poc-unstable-plans.pl'

[[ -z "$ORACLE_HOME" ]] && { echo "ORACLE_HOME must be set"; exit 1; }
[[ -x "$ORACLE_HOME/perl/bin/perl" ]] || { echo "ORACLE_HOME/perl/bin/perl does not exist"; exit 1; }
[[ -r "$perlScript" ]] || { echo "$perlScript does not exist"; exit 1; }

set -u 

# be in the same directory as the script
declare scriptDir=$(dirname $0)
cd "$scriptDir" || { echo "could not cd to '$scriptDir'"; exit 1; }
declare scriptHome=$(pwd)

declare logDir='./logs'
mkdir -p $logDir || { echo "failed to create '$logDir'"; exit 1; }

declare csvDir='./csv'
mkdir -p $csvDir || { echo "failed to create '$csvDir'"; exit 1; }

declare connectString

if [[ $LOCAL_SYSDBA = 'Y' ]]; then
	connectString="/ as sysdba"
else
	connectString="$USERNAME/$PASSWORD@$DATABASE"
fi

if [[ $SYSDBA = 'Y' ]]; then
		connectString="$connectString as sysdba"
fi

#echo "Connect String: $connectString";

declare -a begin_dates
declare -a end_dates

unset SQLPATH ORACLE_PATH

# get some timestamps to run
set +u
while IFS=, read d1 d2
do
	begin_dates[${#begin_dates[@]}]=$d1
	end_dates[${#end_dates[@]}]=$d2
	echo dates:  $d1   $d2
done < <(
 sqlplus -L -silent /nolog <<-EOF
	connect $connectString
	set head off
	set pagesize 0
	set linesize 400 trimspool on

	set echo off pause off feedback off
	set verify off 
	btitle off
	ttitle off

	-- full day
	select 
		to_char(sysdate -1, 'yyyy-mm-dd hh24:mi:ss')
		|| ',' ||  to_char(sysdate, 'yyyy-mm-dd hh24:mi:ss')
	from dual;

	select
		to_char(trunc(sysdate,'HH24') - (level/24), 'yyyy-mm-dd hh24:mi:ss' ) 
		|| ',' || to_char(trunc(sysdate,'HH24') - (level/24) + (1/24) , 'yyyy-mm-dd hh24:mi:ss') 
	from dual
	connect by level <= 24
	order by level desc;

	exit;
EOF
)
set -u

logDbName=$(echo "${DBNAME}" | sed -e 's/\//-/g')
declare logFile="$logDir/poc-unstable-plans-${logDbName}-"$(date +%Y-%m-%d_%H-%M-%S)'.log'
touch $logFile || { echo "could not create '$logFile'"; exit 1; }

connectString=''

if [[ $LOCAL_SYSDBA = 'Y' ]]; then
	connectString=' -local-sysdba '
else
	connectString=" -username $USERNAME -password '$PASSWORD' -database $DATABASE "
fi

if [[ $SYSDBA = 'Y' ]]; then
		connectString="$connectString -sysdba "
fi

#echo $connectString

for el in ${!begin_dates[@]}
do
	csvDate=$(echo ${begin_dates[$el]} | sed -e 's/:/-/g' -e 's/ /_/g')
	echo csvDate: $csvDate

	declare csvFile

	if [[ $el -eq 0 ]]; then # first report is full day
		csvFile="$csvDir/poc-unstable-plans-${DBNAME}-FULL-DAY-${csvDate}.csv"
	else
		csvFile="$csvDir/poc-unstable-plans-${DBNAME}-${csvDate}.csv"
	fi

	touch $csvFile || { echo "could not create '$csvFile'"; exit 1; }

	echo working on date range - begin:  ${begin_dates[$el]}  end: ${end_dates[$el]}
	eval $ORACLE_HOME/perl/bin/perl $perlScript $connectString -csv -begin-time "'${begin_dates[$el]}'" -end-time "'${end_dates[$el]}'"  > $csvFile

done 2>&1 | tee $logFile


cat <<-EOF

 logFile: $logFile

 Please zip up the csv and log directories

EOF









