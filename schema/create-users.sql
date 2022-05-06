
-- plan flip monitor

create user pfmon identified by pfmon;

grant 
	resource
	, connect
	, execute_catalog_role
	, select_catalog_role
to pfmon;


alter user pfmon default tablespace planflip quota unlimited on planflip;


