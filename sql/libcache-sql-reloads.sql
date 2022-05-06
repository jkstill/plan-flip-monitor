
/*

   INST_ID     CON_ID NAMESPACE                      CURSOR_COUNT    RELOADS RELOADS_PER_CURSOR INVALIDATIONS INVALIDATIONS_PER_CURSOR
---------- ---------- ------------------------------ ------------ ---------- ------------------ ------------- ------------------------
         1          0 SQL AREA                               3619     137581         38.0163028         76814               21.2252003
         2          0 SQL AREA                                781     204338         261.636364         23172               29.6696543

*/

set pagesize 100
set linesize 200 trimspool on

col inst_id format 9999 head 'INST|ID'
col con_id format 999 head 'CON|ID'

col namespace format a30
col cursor_count format 999,999 head 'CURSOR|COUNT'
col reloads format 99,999,999
col reloads_per_cursor format 999,999.0 head 'RELOADS|PER|CURSOR'
col invalidations format 99,999,999
col invalidations_per_cursor format 999,999.0 head 'INVALIDATIONS|PER|CURSOR'

with csr as (
	select inst_id, count(*) cursor_count
	from gv$sql_shared_cursor
	group by inst_id
)
select l.inst_id
	, l.con_id
	, l.namespace
	, c.cursor_count
	, l.reloads
	, l.reloads / c.cursor_count reloads_per_cursor
	, l.invalidations
	, l.invalidations / c.cursor_count invalidations_per_cursor
from GV$LIBRARYCACHE l
	,csr c
where c.inst_id = l.inst_id
	and namespace like 'SQL AREA'
	and (l.reloads + l.invalidations) > 0
order by namespace, inst_id
/
