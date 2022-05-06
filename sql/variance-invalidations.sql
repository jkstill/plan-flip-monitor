with data as (
	select sql_id, sum(invalidations) invalidations
	from gv$sql
	where invalidations > 0
	group by sql_id
)
select variance(invalidations) 
from data
/
