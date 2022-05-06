
-- sigmoid-sql-invalidations.sql
/*
  pick a value between .5 and 1 to limit the SQL to look at for invalidation purposes
  
  for a very large busy database, we may want to pick something relatively high.
  say >= .95

  for one that is not so busy, as lower value could be chosen such as .75

*/


with data as (
	select  sql_id, invalidations
		, 1 / ( 1 + power(2.718281828,(-invalidations)))  sigmoid
	from (
		select sql_id, sum(invalidations) invalidations
		from gv$sql
		group by sql_id
	)
)
select
	sql_id
	, invalidations
	, sigmoid
from data
where sigmoid >= .95
order by sigmoid
/
