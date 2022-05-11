
-- plan flip monitor

@@pfmon-config

create user pfmon identified by pfmon;

grant 
	resource
	, connect
	, execute_catalog_role
	, select_catalog_role
to pfmon;



@@save-sqlplus-settings.sql

set verify on
alter user pfmon default tablespace &pfmon_tbs quota unlimited on &pfmon_tbs;

@&sqltempfile


