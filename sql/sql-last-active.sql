select sql_id, last_active_time 
from v$sqlstats
where last_active_time is not null
order by sql_id, last_active_time
/
