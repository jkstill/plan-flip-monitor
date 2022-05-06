
@plsql-init
set serveroutput on size unlimited

-- run only for the SOE 

whenever sqlerror exit 128

declare

	e_wrong_user exception;
	pragma exception_init(e_wrong_user, -20000);

begin

	if USER != 'SOE' then
		dbms_output.put_line('Will not run for ' || user );
		raise e_wrong_user;
	end if;

	for tabrec in (select table_name from user_tables)
	loop
		dbms_output.put_line('Table: ' || tabrec.table_name);

		-- cascade_indexes => true could be used
		-- leaving that as a separate script
		--/*
		dbms_stats.delete_table_stats (
			ownname => 'SOE',
			tabname => tabrec.table_name,
			cascade_parts => true,
			cascade_columns => true,
			no_invalidate => true,
			force => true
		);
		--*/
	end loop;

end;
/

whenever sqlerror continue

