
-- create-tables.sql
-- sql for plan-flip metadata

-- user/schema is pfmon


@@drop-tables

set linesize 80
set pagesize 100

prompt table: CONFIG
create table CONFIG( 
	performance_threshold number(4,2) not null
)
/


prompt table: SCHEMAS
create table SCHEMAS (
	name varchar2(30 ) not null
)
/

prompt table: SQL_STATEMENTS
create table SQL_STATEMENTS (
	sql_id varchar2(13) not null,
	sql_text clob 
)
/


prompt table: SQL_OBJECTS
create table SQL_OBJECTS (
	sql_id varchar2(13) not null,
	plan_hash_value number not null,
	full_plan_hash_value number,
	object_owner varchar2(30) not null,
	object_type varchar2(15) not null,
	object_name varchar2(30) not null
)
/


prompt table: SQL_PLANS
create table SQL_PLANS (
	sql_id varchar2(13) not null,
	plan_hash_value number not null,
	full_plan_hash_value number,
	optimizer varchar2(20),
	operation varchar2(30),
	position number,
	partition_start varchar2(64),
	partition_stop varchar2(64),
	partition_id number,
	qblock_name varchar2(128),
	remarks varchar2(4000),
	access_predicates varchar2(4000),
	filter_predicates varchar2(4000)
)
/

prompt table: SQL_PLAN_STEPS
create table SQL_PLAN_STEPS (
	sql_id varchar2(13) not null,
	plan_hash_value number not null
)
/


-- get baselines from AWR
prompt table: SQL_EXE_BASELINES
create table SQL_EXE_BASELINES (
	sql_id varchar2(13) not null,
	plan_hash_value number not null,
	start_time date not null,
	end_time date not null,
	min_exe_time number,
	max_exe_time number,
	avg_exe_time number
)
/

-- current executions from ASH
prompt table: SQL_EXECUTIONS
create table SQL_EXECUTIONS (
	sql_id varchar2(13) not null,
	plan_hash_value number not null,
	start_time date not null,
	end_time date not null,
	min_exe_time number,
	max_exe_time number,
	avg_exe_time number
)
/


prompt table: SQL_PLAN_ESTIMATES
create table SQL_PLAN_ESTIMATES (
	sql_id varchar2(13) not null,
	plan_hash_value number not null
)
/


prompt table: SQL_PLAN_STATISTICS
create table SQL_PLAN_STATISTICS (
	sql_id varchar2(13) not null,
	plan_hash_value number not null
)
/



