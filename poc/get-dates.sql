select
	to_char(trunc(sysdate,'HH24') - (level/24) ) start_date
	, to_char(trunc(sysdate,'HH24') - (level/24) + (1/24) ) end_date
from dual
connect by level <= 24
order by level desc
/
