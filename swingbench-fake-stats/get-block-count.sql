with data as
(
select distinct
	dbms_rowid.rowid_object(rowid) object_id
	, dbms_rowid.rowid_relative_fno(rowid) filenum
	, dbms_rowid.rowid_block_number(rowid) blocknum
	--, dbms_rowid.rowid_row_number(rowid) rownumber
from soe.customers 
--where rownum < 20
)
select count(*) from data
/
