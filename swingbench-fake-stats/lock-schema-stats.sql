
exec dbms_stats.lock_schema_stats(user)

col table_name format a30
col stattype_locked format a10
col index_name format a30

select table_name , STATTYPE_LOCKED from user_tab_statistics order by table_name;
select index_name , STATTYPE_LOCKED from user_ind_statistics order by index_name;
