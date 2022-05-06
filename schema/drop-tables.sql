
-- drop-tables.sql
-- drop tables for plan-flip metadata

-- user/schema is pfmon

set serveroutput on size unlimited

declare
	v_sql varchar2(200);
	e_table_does_not_exist exception;
	pragma exception_init(e_table_does_not_exist,-942);
begin

	dbms_output.enable;

	for tabrec in (
		select rownum id, column_value table_name
		from ( table
			( 
				sys.odcivarchar2list
				(
					'CONFIG'
					,'SCHEMAS'
					,'SQL_STATEMENTS'
					,'SQL_OBJECTS'
					,'SQL_PLANS'
					,'SQL_EXECUTIONS'
					,'SQL_EXE_BASELINES'
					,'SQL_PLAN_STEPS'
					,'SQL_PLAN_ESTIMATES'
					,'SQL_PLAN_STATISTICS' -- only useful if STATISTICS_LEVEL=ALL or gather_plan_statistics hint is used
				)
			)
		)
	)
	loop
		dbms_output.put_line('Table: ' || tabrec.table_name);

		v_sql := 'drop table ' || tabrec.table_name || ' cascade constraints purge';
		begin
			execute immediate v_sql;
			dbms_output.put_line('	removed ' || tabrec.table_name);
		exception
		when e_table_does_not_exist then
			dbms_output.put_line('	' || tabrec.table_name || ' does not exist');
		when others then 
			raise;
		end;
	end loop;

end;
/


