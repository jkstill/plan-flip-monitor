
/*
Table: CUSTOMERS   rows:      14,483,995                                                                                                                                                                
Table: ADDRESSES   rows:      22,599,493                                                                                                                                                                
Table: CARD_DETAILS   rows:      15,484,008                                                                                                                                                             
Table: WAREHOUSES   rows:           1,000                                                                                                                                                               
Table: ORDER_ITEMS   rows:     116,145,624                                                                                                                                                              
Table: ORDERS   rows:      36,291,424                                                                                                                                                                   
Table: INVENTORIES   rows:         900,297                                                                                                                                                              
Table: PRODUCT_INFORMATION   rows:           1,000                                                                                                                                                      
Table: LOGON   rows:      51,069,446                                                                                                                                                                    
Table: PRODUCT_DESCRIPTIONS   rows:           1,000                                                                                                                                                     
Table: ORDERENTRY_METADATA   rows:               4                                                                                                                                                      

PL/SQL procedure successfully completed.
*/


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
end;
/

whenever sqlerror continue

declare

	type t_tables_typ 
	is 
	table of number
	index by varchar2(50);

	t_tab_numrows t_tables_typ;
	t_tab_numblks t_tables_typ;
	t_tab_avgrlen t_tables_typ;


begin

	t_tab_numrows('CUSTOMERS')					:= 10;
	t_tab_numrows('ADDRESSES')					:= 10;
	t_tab_numrows('CARD_DETAILS')				:= 10;
	t_tab_numrows('WAREHOUSES')				:= 10;
	t_tab_numrows('ORDER_ITEMS')				:= 10;
	t_tab_numrows('ORDERS')						:= 10;
	t_tab_numrows('INVENTORIES')				:= 10;
	t_tab_numrows('PRODUCT_INFORMATION')	:= 10;
	t_tab_numrows('LOGON')						:= 10;
	t_tab_numrows('PRODUCT_DESCRIPTIONS')	:= 10;
	t_tab_numrows('ORDERENTRY_METADATA')	:= 4;

	t_tab_numblks('CUSTOMERS')					:= 1;
	t_tab_numblks('ADDRESSES')					:= 1;
	t_tab_numblks('CARD_DETAILS')				:= 1;
	t_tab_numblks('WAREHOUSES')				:= 1;
	t_tab_numblks('ORDER_ITEMS')				:= 1;
	t_tab_numblks('ORDERS')						:= 1;
	t_tab_numblks('INVENTORIES')				:= 1;
	t_tab_numblks('PRODUCT_INFORMATION')	:= 1;
	t_tab_numblks('LOGON')						:= 1;
	t_tab_numblks('PRODUCT_DESCRIPTIONS')	:= 1;
	t_tab_numblks('ORDERENTRY_METADATA')	:= 1;

	t_tab_avgrlen('CUSTOMERS')					:= 32;
	t_tab_avgrlen('ADDRESSES')					:= 32;
	t_tab_avgrlen('CARD_DETAILS')				:= 32;
	t_tab_avgrlen('WAREHOUSES')				:= 32;
	t_tab_avgrlen('ORDER_ITEMS')				:= 32;
	t_tab_avgrlen('ORDERS')						:= 32;
	t_tab_avgrlen('INVENTORIES')				:= 32;
	t_tab_avgrlen('PRODUCT_INFORMATION')	:= 32;
	t_tab_avgrlen('LOGON')						:= 32;
	t_tab_avgrlen('PRODUCT_DESCRIPTIONS')	:= 32;
	t_tab_avgrlen('ORDERENTRY_METADATA')	:= 32;


	for tabrec in (
		select table_name
		from user_tables
		where table_name not in ('SOE_STATS')
	)
	loop
		dbms_output.put_line('Table: ' || tabrec.table_name);

		--/*
		dbms_stats.set_table_stats (
			ownname => 'SOE',
			tabname => tabrec.table_name,
			no_invalidate => false,
			force => true,
			numrows => t_tab_numrows(tabrec.table_name),
			numblks => t_tab_numblks(tabrec.table_name),
			avgrlen =>t_tab_avgrlen(tabrec.table_name)
		);
		--*/

	end loop;

end;
/


