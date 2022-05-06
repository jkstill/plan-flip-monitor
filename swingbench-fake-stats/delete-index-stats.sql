
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

	for indrec in (select index_name from user_indexes)
	loop
		dbms_output.put_line('Index: ' || indrec.index_name);
		dbms_stats.delete_index_stats (
			ownname => 'SOE',
			indname => indrec.index_name,
			cascade_parts => true,
			no_invalidate => true,
			force => true
		);
	end loop;

end;
/

whenever sqlerror continue

