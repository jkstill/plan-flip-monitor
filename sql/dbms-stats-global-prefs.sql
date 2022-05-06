
col sname format a30
col spare4 format a30

select sname,spare4
from sys.optstat_hist_control$
where upper(spare4) like '%DBMS_STATS%'
order by 1
/
