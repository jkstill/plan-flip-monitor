
insert into stddev_test
select dbms_random.value(power(10,5),power(10,6)) v1 from dual connect by level <= 10
/

commit;

