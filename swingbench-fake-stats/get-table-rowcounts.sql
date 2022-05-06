

@plsql-init
set serveroutput on size unlimited

-- run only for the SOE 

spool soe-rowcounts.log

declare

	e_wrong_user exception;
	pragma exception_init(e_wrong_user, -20000);

	v_sql clob;

	n_rowcount number;
	n_distinct number;

begin

	for tabrec in (select table_name from user_tables)
	loop
		dbms_output.put('Table: ' || tabrec.table_name || '   rows: ');
		v_sql := 'select count(*) from ' || tabrec.table_name;
		--dbms_output.put_line(v_sql);

		execute immediate v_sql into n_rowcount;
		dbms_output.put_line(to_char(n_rowcount,'99,999,999,999'));
	end loop;

end;
/


spool off


