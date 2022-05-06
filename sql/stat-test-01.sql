

set serveroutput on size unlimited

-- normal fit

declare

	n_sigmoid number;
	n_mean number;
	n_stddev number;

begin

	select avg(v1) into n_mean from stddev_test;
	select stddev(v1) into n_stddev from stddev_test;

	DBMS_STAT_FUNCS.NORMAL_DIST_FIT (
   	ownername    => 'JKSTILL',
   	tablename    =>    'STDDEV_TEST',
   	columnname   =>    'V1',
   	--test_type    =>   'CHI_SQUARED',
   	--test_type    =>   'KOLMOGOROV_SMIRNOV',
   	test_type    =>   'ANDERSON_DARLING',
   	--test_type    =>   'SHAPIRO_WILKS',
   	mean         =>   n_mean,
   	stdev        =>    n_stddev,
   	sig          =>   n_sigmoid);

	dbms_output.put_line('sigmoid: ' || to_char(n_sigmoid));

end;
/

