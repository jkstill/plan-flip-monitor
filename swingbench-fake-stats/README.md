
Fake Object Statistics for SwingBench SOE
=========================================

Here are scripts for generating fake and misleading statistics for the SOE SwingBench app.

The reason for doing this is to cause Oracle to create some rather poor plans for SOE SQL statements.

These results are desired for testing execution plan flips that lead to poor performance.

In all cases, `no_invalidate => false` is used when collecting or setting database object statistics, as we want the new plans created and used.

Before doing that however, use the following script to generate statistics, and then back them up for later use.

## Collect Correct Statistics

Use the `gather-stats-normal.sql` script to gather statistics.

The method used leaves it up toe Oracle as to which statistics are gathered.

The only optional directive used is `gather-stats-normal.sql`.

## Backup The Statistics

It takes some time to generate the statistics.

Rather than recollect them everytime the 'normal' statistics are desired, the statistics can be 'exported'.

The reason 'exported' in quotes is that in the context of DBMS_STATS, an 'export' is simply saving statistics to a table.

The statistics can then be 'imported'.

The statistics tables can also be exported and imported by the standard 'exp/imp' utilities as well.

cd to the ~/oracle/dba/statops directory to run the following scripts.

### Create The Statistics Table

The statistics table can be created with the `bin/create_stat_table.sh` script.

```text
./bin/create_stat_table.sh
-o ORACLE_SID      - this is used to set the oracle environment
-d database        - database the stats table will be created in
-u username        - username to logon with
-p password        - the user is prompted for password if not set on the command line
-n owner           - owner of the stats table
-r dryrun          - show VALID_ARGS and exit without running the job
-t table_name      - name of the stats table to create
-s tablespace_name - tablespace name in which to create the stats table
                     defaults to the default tablespace for the owner
```

For example:

```text
$  bin/create_stat_table.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -n soe -t soe_stats
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
Creating STATS_TABLE: soe_stats_export
  Database: rac-scan/swingbench.jks.com
  Schema: jkstill
  Tablespace: NULL

SQL*Plus: Release 12.1.0.2.0 Production on Mon May 9 14:53:39 2022

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

SQL> Connected.
SQL> Statistics Table Owner:
Statistics Table Name:
Tablespace Name:

PL/SQL procedure successfully completed.


```

Check the table:

```text
SQL# desc soe.soe_stats
 Name                    Null?    Type
 ----------------------- -------- ----------------
 STATID                           VARCHAR2(128)
 TYPE                             CHAR(1)
 VERSION                          NUMBER
 FLAGS                            NUMBER
 C1                               VARCHAR2(128)
 C2                               VARCHAR2(128)
 C3                               VARCHAR2(128)
 C4                               VARCHAR2(128)
 C5                               VARCHAR2(128) C6                               VARCHAR2(128)
 N1                               NUMBER
 N2                               NUMBER
 N3                               NUMBER
 N4                               NUMBER
 N5                               NUMBER
 N6                               NUMBER
 N7                               NUMBER
 N8                               NUMBER
 N9                               NUMBER
 N10                              NUMBER
 N11                              NUMBER
 N12                              NUMBER
 N13                              NUMBER
 D1                               DATE
 T1                               TIMESTAMP(6) WIT
                                  H TIME ZONE
 R1                               RAW(1000)
 R2                               RAW(1000)
 R3                               RAW(1000)
 CH1                              VARCHAR2(1000)
 CL1                              CLOB
 BL1                              BLOB
```

### Export Statistics

The `export_statistics.sh` script is used to save current statistics:

```text
$  bin/export_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -n soe -t soe_stats -s soe -T SCHEMA
NO MATCH
arglist: :JKSTILL:rac-scan/SWINGBENCH.JKS.COM:SOE:SOE_STATS:SOE:SCHEMA:C12:
  REGEX: :[[:alnum:]]{3,}:[[:punct:][:alnum:]]{3,}:[[:alnum:]_$]+:[[:alnum:]_#$]+:(DICTIONARY_STATS|SYSTEM_STATS|FIXED_OBJECTS_STATS):[[:punct:][:alnum:]]{3,}:
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
Exporting Schema Stats for: soe
  Database: rac-scan/swingbench.jks.com
  Table: soe_stats

EXP: bin/../sql/export_schema_stats.sql soe soe soe_stats

SQL*Plus: Release 12.1.0.2.0 Production on Mon May 9 15:08:33 2022

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

SQL> Connected.
SQL> Export Stats for Schema:
Stats Table Owner:
Statistics Table Name:

PL/SQL procedure successfully completed.

SQL> Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

#### List Statistics

Statistics sets may be listed.  The following command is used:

```text
$   bin/list_stats.sh

bin/list_stats.sh

List statistics that have been saved with export_stats.sh
or any utility that exports Data Dictionary Statistics to
a table created via DBMS_STATS.CREATE_STAT_TABLE

-o ORACLE_SID - ORACLE_SID used to set local oracle environment

-d database     - database where stats table is found
-u username     - username to logon with
-p password     - the user is prompted for password if not set on the command line
-n owner        - owner of statistics table
-t table_name   - statistics table to list from
                  as created by dbms_stats.create_stat_table
-e              - detailed report - currently tables/indexes only
-r dryrun       - show VALID_ARGS and exit without running the job

-i              - statid of statistics set - defaults to %
-s schema       - schema name for which to list statistics - defaults to %

-b              - object name to search for - table or index name - defaults to %
                  SQL wild cards allowed
                  quote wild cards if used
                  the only valid object name for levels 1 and 2 is %

-l level        - level of detail to show - defaults to 2
                  MUST be 3 or greater if -s and/or -b are used
                  1=statid only
                  2=statid and owners only
                  3=statid, owners, type and name
                  4=statid, owners, type, name and partition
                  5=statid, owners, type, name and column
```

Here is a list of the sets available.  

```text
$   bin/list_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -n soe -t soe_stats -l 1
NO MATCH
arglist: :JKSTILL:rac-scan/SWINGBENCH.JKS.COM:SOE:SOE_STATS:1:%:%:C12:
  REGEX: :[[:alnum:]_$]+:[[:punct:][:alnum:]]{3,}:[[:alnum:]_$]+:[[:alnum:]_#$]+:[2-5]{1}:*:*:[[:punct:][:alnum:]]{3,}:
MATCHED
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
Exporting Schema Stats for: %
  Database: rac-scan/swingbench.jks.com
  Table: soe_stats

LIST: bin/../sql/list_stats.sql soe soe_stats 1 %

SQL*Plus: Release 12.1.0.2.0 Production on Mon May 9 15:11:39 2022

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

SQL> Connected.
SQL> Stats Table Owner:
Stats Table Name:

1=statid only
2=statid and owners only
3=statid, owners, type and name
4=statid, owners, type, name and partition
5=statid, owners, type, name and column

Level of Detail?
Schema Name (wildcards OK) ?
Object Name (wildcards OK) ?

PL/SQL procedure successfully completed.

STATID
------------------------------
SOE_CDB_2205051533
SOE_CDB_2205091508

2 rows selected.
```

There are two date stamped sets of statistics.

Now get some detail with level 3

```text
$   bin/list_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -n soe -t soe_stats -l 3 -i SOE_CDB_2205091508
MATCHED
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
Exporting Schema Stats for: %
  Database: rac-scan/swingbench.jks.com
  Table: soe_stats

LIST: bin/../sql/list_stats.sql soe soe_stats 3 % SOE_CDB_2205091508

SQL*Plus: Release 12.1.0.2.0 Production on Mon May 9 15:36:23 2022

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

SQL> Connected.
SQL> Stats Table Owner:
Stats Table Name:

1=statid only
2=statid and owners only
3=statid, owners, type and name
4=statid, owners, type, name and partition
5=statid, owners, type, name and column

Level of Detail?
Schema Name (wildcards OK) ?
Object Name (wildcards OK) ?
Statid?

PL/SQL procedure successfully completed.


STATID                         OWNER                          TYP S=STATUS O=NAME
------------------------------ ------------------------------ --- ------------------------------
SOE_CDB_2205091508             SOE                            I   ADDRESS_CUST_IX
SOE_CDB_2205091508             SOE                            I   ADDRESS_PK
SOE_CDB_2205091508             SOE                            I   CARDDETAILS_CUST_IX
SOE_CDB_2205091508             SOE                            I   CARD_DETAILS_PK
SOE_CDB_2205091508             SOE                            I   CUSTOMERS_PK
SOE_CDB_2205091508             SOE                            I   CUST_ACCOUNT_MANAGER_IX
SOE_CDB_2205091508             SOE                            I   CUST_DOB_IX
SOE_CDB_2205091508             SOE                            I   CUST_EMAIL_IX
SOE_CDB_2205091508             SOE                            I   CUST_FUNC_LOWER_NAME_IX
SOE_CDB_2205091508             SOE                            I   INVENTORY_PK
SOE_CDB_2205091508             SOE                            I   INV_PRODUCT_IX
SOE_CDB_2205091508             SOE                            I   INV_WAREHOUSE_IX
SOE_CDB_2205091508             SOE                            I   ITEM_ORDER_IX
SOE_CDB_2205091508             SOE                            I   ITEM_PRODUCT_IX
SOE_CDB_2205091508             SOE                            I   ORDER_ITEMS_PK
SOE_CDB_2205091508             SOE                            I   ORDER_PK
SOE_CDB_2205091508             SOE                            I   ORD_CUSTOMER_IX
SOE_CDB_2205091508             SOE                            I   ORD_ORDER_DATE_IX
SOE_CDB_2205091508             SOE                            I   ORD_SALES_REP_IX
SOE_CDB_2205091508             SOE                            I   ORD_WAREHOUSE_IX
SOE_CDB_2205091508             SOE                            I   PRD_DESC_PK
SOE_CDB_2205091508             SOE                            I   PRODUCT_INFORMATION_PK
SOE_CDB_2205091508             SOE                            I   PROD_CATEGORY_IX
SOE_CDB_2205091508             SOE                            I   PROD_NAME_IX
SOE_CDB_2205091508             SOE                            I   PROD_SUPPLIER_IX
SOE_CDB_2205091508             SOE                            I   SOE_STATS
SOE_CDB_2205091508             SOE                            I   WAREHOUSES_PK
SOE_CDB_2205091508             SOE                            I   WHS_LOCATION_IX
SOE_CDB_2205091508             SOE                            T   ADDRESSES
SOE_CDB_2205091508             SOE                            T   CARD_DETAILS
SOE_CDB_2205091508             SOE                            T   CUSTOMERS
SOE_CDB_2205091508             SOE                            T   INVENTORIES
SOE_CDB_2205091508             SOE                            T   LOGON
SOE_CDB_2205091508             SOE                            T   ORDERENTRY_METADATA
SOE_CDB_2205091508             SOE                            T   ORDERS
SOE_CDB_2205091508             SOE                            T   ORDER_ITEMS
SOE_CDB_2205091508             SOE                            T   PRODUCT_DESCRIPTIONS
SOE_CDB_2205091508             SOE                            T   PRODUCT_INFORMATION
SOE_CDB_2205091508             SOE                            T   SOE_STATS
SOE_CDB_2205091508             SOE                            T   WAREHOUSES

40 rows selected.

SQL> Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

#### List Statistics Details

```text
$  bin/list_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -t soe_stats -n soe -s soe -e -b ORDERS
MATCHED
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
Listing Schema Stats for: soe
  Database: rac-scan/swingbench.jks.com
  Table: soe_stats

DETAILS LIST: soe soe_stats 2 ORDERS %

SQL*Plus: Release 12.1.0.2.0 Production on Mon May 9 17:26:18 2022

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

SQL> Connected.
SQL> Stats Table Owner:
Stats Table Name:
Schema Name (wildcards OK) ?
Object Name (wildcards OK) ?
Statid?

PL/SQL procedure successfully completed.


                                                                                                                                                                       In Memory
                                                                                                                                                                     Compression In Memory
STATID                         OWNER.TABLE.[partition].[subpart]                                                  NUM ROWS       BLOCKS  AVG ROW LEN     SAMPLE SIZE       Units    Blocks
------------------------------ --------------------------------------------------------------------------- --------------- ------------ ------------ --------------- ----------- ---------
SOE_CDB_2205051533             SOE.ORDERS                                                                       36,872,929      519,599           89      36,872,929
SOE_CDB_2205091508             SOE.ORDERS                                                                       36,872,929      519,599           89      36,872,929

2 rows selected.

SQL> Stats Table Owner:
Stats Table Name:
Schema Name (wildcards OK) ?
Object Name (wildcards OK) ?
Statid?

PL/SQL procedure successfully completed.


                                                                                                                                            DISTINCT     LEAF BLOCKS    DATA BLOCKS      CLUSTERING
STATID                         OWNER.TABLE.INDEX.[partition].[subpart]                                            NUM ROWS  LEAF_BLOCKS         KEYS         PER KEY        PER KEY          FACTOR BLEVEL  SAMPLE SIZE
------------------------------ --------------------------------------------------------------------------- --------------- ------------ ------------ --------------- -------------- --------------- ------ ------------
SOE_CDB_2205051533             SOE.ORDERS.ORDER_PK                                                              36,916,428       98,857   36,916,428               1              1   36,916,426.00      2   36,916,428
SOE_CDB_2205051533             SOE.ORDERS.ORD_CUSTOMER_IX                                                       36,915,779      108,018    1,996,800               1             18   36,915,087.00      2   36,915,779
SOE_CDB_2205051533             SOE.ORDERS.ORD_ORDER_DATE_IX                                                     36,916,062      155,494   34,033,664               1              1   36,911,579.00      2   36,916,062
SOE_CDB_2205051533             SOE.ORDERS.ORD_SALES_REP_IX                                                       2,859,580        5,837          906               6          2,893    2,621,885.00      2    2,859,580
SOE_CDB_2205051533             SOE.ORDERS.ORD_WAREHOUSE_IX                                                      36,916,282      156,274       10,270              15          3,566   36,632,041.00      2   36,916,282
SOE_CDB_2205091508             SOE.ORDERS.ORDER_PK                                                              36,916,428       98,857   36,916,428               1              1   36,916,426.00      2   36,916,428
SOE_CDB_2205091508             SOE.ORDERS.ORD_CUSTOMER_IX                                                       36,915,779      108,018    1,996,800               1             18   36,915,087.00      2   36,915,779
SOE_CDB_2205091508             SOE.ORDERS.ORD_ORDER_DATE_IX                                                     36,916,062      155,494   34,033,664               1              1   36,911,579.00      2   36,916,062
SOE_CDB_2205091508             SOE.ORDERS.ORD_SALES_REP_IX                                                       2,859,580        5,837          906               6          2,893    2,621,885.00      2    2,859,580
SOE_CDB_2205091508             SOE.ORDERS.ORD_WAREHOUSE_IX                                                      36,916,282      156,274       10,270              15          3,566   36,632,041.00      2   36,916,282

10 rows selected.

SQL> Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

### Export Statistics to a DMP file

Use the `bin/exp_stats.sh` script:

```text

$   bin/exp_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -n soe -t soe_stats  -i SOE_CDB_2205091508 -s soe
MATCHED
ALLARGS: :JKSTILL:rac-scan/SWINGBENCH.JKS.COM:SOE:SOE_STATS:SOE_CDB_2205091508:SOE:C12:
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
export STATS_TABLE: soe_stats
  Database: rac-scan/swingbench.jks.com
  Schema: jkstill
NLS_LANG: AMERICAN_AMERICA.AL32UTF8
expLogFile: logs/soe_rac-scan-swingbench.jks.com_stats_SOE_CDB_2205091508_SOE_exp.log
expDmpFile: dmp/soe_rac-scan-swingbench.jks.com_SOE_CDB_2205091508_SOE_stats.dmp

Export: Release 12.1.0.2.0 - Production on Mon May 9 15:46:29 2022

Copyright (c) 1982, 2014, Oracle and/or its affiliates.  All rights reserved.


Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Export done in AL32UTF8 character set and AL16UTF16 NCHAR character set
Note: grants on tables/views/sequences/roles will not be exported
Note: indexes on tables will not be exported
Note: constraints on tables will not be exported

About to export specified tables via Conventional Path ...
Current user changed to SOE
. . exporting table                      SOE_STATS        919 rows exported
Export terminated successfully without warnings.


$  ls -ladtr dmp/*
-rw-rw-r-- 1 jkstill dba 172032 May  9 15:46 dmp/soe_rac-scan-swingbench.jks.com_SOE_CDB_2205091508_SOE_stats.dmp

```

### Import Statistics from a DMP file

Use the `bin/imp_stats.sh` script:

```text

$   bin/imp_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -f dmp/soe_rac-scan-swingbench.jks.com_SOE_CDB_2205091508_SOE_stats.dmp -F soe -T jkstill
MATCHED
ARGS: :JKSTILL:rac-scan/SWINGBENCH.JKS.COM:SOE:JKSTILL:DMP/SOE_rac-scan-SWINGBENCH.JKS.COM_SOE_CDB_2205091508_SOE_STATS.DMP:C12:
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
export STATS_TABLE:
  Database: rac-scan/swingbench.jks.com
  Schema: jkstill

Import: Release 12.1.0.2.0 - Production on Mon May 9 15:49:10 2022

Copyright (c) 1982, 2014, Oracle and/or its affiliates.  All rights reserved.


Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production

Export file created by EXPORT:V12.01.00 via conventional path
import done in UTF8 character set and AL16UTF16 NCHAR character set
import server uses AL32UTF8 character set (possible charset conversion)
export client uses AL32UTF8 character set (possible charset conversion)
. importing SOE's objects into JKSTILL
. . importing table                    "SOE_STATS"        919 rows imported
Import terminated successfully without warnings.

```

Verify:

```text

SQL# show user
USER is "JKSTILL"

SQL# select count(*) from soe_stats;

  COUNT(*)
----------
       919

1 row selected.

```


### Import Statistics

Now the default statistics will be imported to SOE.

```text
$  bin/import_stats.sh -o c12 -d rac-scan/swingbench.jks.com -u jkstill -p XXXX -t soe_stats -n soe -s soe -T schema -v NO -f YES -i SOE_CDB_2205091508
NO MATCH
arglist: :JKSTILL:rac-scan/SWINGBENCH.JKS.COM:SOE:SOE_STATS:SOE:SCHEMA:SOE_CDB_2205091508:NO:YES:C12:
  REGEX: :[[:alnum:]_$]+:[[:punct:][:alnum:]]{3,}:[[:alnum:]_$]+:[[:alnum:]_#$]+::(DICTIONARY_STATS|SYSTEM_STATS|FIXED_OBJECTS_STATS):[[:alnum:][:punct:]]+:([YyNn]|YES|yes|NO|no):([YyNn]|YES|yes|NO|no):[[:punct:][:alnum:]]{3,}:
MATCHED
ORACLE_BASE environment variable is not being set since this
information is not available for the current user ID jkstill.
You can set ORACLE_BASE manually if it is required.
Importing Schema Stats for: soe  statid:
Importing Schema Stats for: SOE_CDB_2205091508  statid:
  Database: rac-scan/swingbench.jks.com
  Table: soe_stats

IMP: bin/../sql/import_schema_stats.sql soe soe_stats SOE_CDB_2205091508

SQL*Plus: Release 12.1.0.2.0 Production on Mon May 9 17:37:36 2022

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

SQL> Connected.
SQL> Import Stats Table Owner:
Statistics Table Name:
Import Stats for Schema:
Import Stats for StatID:
NOINVALIDATE? YES/NO:
FORCE IMPORT? YES/NO:

PL/SQL procedure successfully completed.

SQL> Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

## Generate Fake Statistics





