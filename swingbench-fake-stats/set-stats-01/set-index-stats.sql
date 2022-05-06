
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

	t_tab_numrows('CUSTOMERS')					:= 100000000;
	t_tab_numrows('ADDRESSES')					:= 200000000;
	t_tab_numrows('CARD_DETAILS')				:= 50000000;
	t_tab_numrows('WAREHOUSES')				:= 25000;
	t_tab_numrows('ORDER_ITEMS')				:= 300000000;
	t_tab_numrows('ORDERS')						:= 100000000;
	t_tab_numrows('INVENTORIES')				:= 20000000;
	t_tab_numrows('PRODUCT_INFORMATION')	:= 50000;
	t_tab_numrows('LOGON')						:= 350000000;
	t_tab_numrows('PRODUCT_DESCRIPTIONS')	:= 50000;
	t_tab_numrows('ORDERENTRY_METADATA')	:= 4;

	t_tab_numblks('CUSTOMERS')					:= floor(100000000/4);
	t_tab_numblks('ADDRESSES')					:= floor(200000000/4);
	t_tab_numblks('CARD_DETAILS')				:= floor(50000000/8);
	t_tab_numblks('WAREHOUSES')				:= floor(25000/2);
	t_tab_numblks('ORDER_ITEMS')				:= floor(300000000/8);
	t_tab_numblks('ORDERS')						:= floor(100000000/16);
	t_tab_numblks('INVENTORIES')				:= floor(20000000/12);
	t_tab_numblks('PRODUCT_INFORMATION')	:= floor(50000/2);
	t_tab_numblks('LOGON')						:= floor(350000000/4);
	t_tab_numblks('PRODUCT_DESCRIPTIONS')	:= floor(50000/3);
	t_tab_numblks('ORDERENTRY_METADATA')	:= floor(4/2);

	for indrec in (select table_name, index_name from user_indexes order by table_name, index_name)
	loop
		dbms_output.put_line('Table: ' || indrec.table_name );
		dbms_output.put_line('	Index: ' || indrec.index_name );

		--/*
		dbms_stats.set_index_stats (
			ownname => 'SOE',
			indname => indrec.index_name,
			no_invalidate => false,
			force => true,
			numrows => t_tab_numrows(indrec.table_name),
			numlblks => t_tab_numblks(indrec.table_name),
			numdist => floor(t_tab_numrows(indrec.table_name) / t_tab_numblks(indrec.table_name) ),
			clstfct => t_tab_numblks(indrec.table_name),
			indlevel => 2
		);
		--*/

	end loop;

end;
/


