select  distinct
	h.inst_id
	, h.sql_id, h.plan_hash_value
	, min(h.first_load_time) first_load_time
	, max(h.last_load_time) last_load_time
from gv$sqlarea_plan_hash h
join gv$sql_plan p 
	on p.inst_id = h.inst_id
	and p.sql_id = h.sql_id
	and p.plan_hash_value = h.plan_hash_value
	and h.parsing_user_id in (select user_id from dba_users where username = 'SOE')
	and p.object_owner = 'SOE'
group by h.inst_id, h.sql_id, h.plan_hash_value
order by first_load_time, sql_id
/
