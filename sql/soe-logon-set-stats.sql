
-- soe-logon-set-stats.sql
-- cause a trace for troubleshooting

create or replace trigger soe_logon_set_stats_trg
after logon on database 
declare
	v_sid integer;
	v_serial integer;
	v_username varchar2(30);
	v_machine varchar2(50);
begin

	select user into v_username from dual;

	-- put username of your choice here
	-- do not use SYS, as the audsid is 0 and will return
	-- multiple rows in the query for machine

	if v_username in ('SOE') then
		execute immediate 'alter session set statistics_level=ALL';
	end if;
	
end;
/

show errors trigger soe_logon_set_stats_trg 

