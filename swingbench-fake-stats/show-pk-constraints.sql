
col table_name format a30
col constraint_name format a30
col column_name format a30

break on table_name skip 1

select 
	c.table_name
	, c.constraint_name 
	, cc.column_name
from user_constraints c
join user_cons_columns cc on cc.owner = c.owner
	and cc.table_name = c.table_name
	and  constraint_type = 'P'
order by 
	table_name
	, constraint_name
	, position
/
