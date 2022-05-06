create table stddev_test
as
select dbms_random.value(1,10000) v1 from dual connect by level <= 10000
/
