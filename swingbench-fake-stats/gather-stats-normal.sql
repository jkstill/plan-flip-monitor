
@@delete-stats

begin
	dbms_stats.gather_schema_stats(
		ownname => user, 
		no_invalidate => false,
		force => true
	);
end;
/



