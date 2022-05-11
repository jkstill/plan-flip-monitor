
Plan Flip Monitor
=================

This is a set of scripts designed to help spot plan flips that lead to poor performance.

There are a variety of things that can lead to a plan flip:

* incorrect statistics
* incomplete statistics
* different predicates/bind variables 
* probably more...


Oracle's query optimizer depends on object level statistics in determining the execution plan for a query.

The problem is that the optimizer doesn't always have the correct information required to create the most efficient plan.

Oracle support et al advocates using default statistics settings when gathering object statistics.

Something like this:  `dbms_stats.gather_schema_stats('SCHEMA_NAME')`

Imagine an OLTP schema with the following attributes:

* well designed to at least third normal form
** primary keys
** unique keys
** foreign keys
*** with indexes on the child columns if they are used to query
* little skew in the data
* application uses bind variables 
* SQL is well written - no (partial) cartesian joins
** even better, an API in PL/SQL to return values, cursors and perform updates
* no nested views
* object statistics are regularly updated
* moderate data growth

Such a schema and application are likely to perform very well with default statistics gathering.

Imagine however that the the following are true

* schema design is marginal, or worse
** missing unique keys
** columns used in query predicates are highly skewed
** many nested views

That is it reality in some cases, and it must be dealt with.

Dealing with it is usually left up to the DBAs and/or performance oriented consultants.

Redesigning the app is out of the question in most cases.

In that situation, there are several workarounds commonly employed to try and wring some performance out of the database:

* SQL Profiles
* SQL Plan Management
* SQL Outlines
* SQL Patch, for injecting hints into SQL
* Function Based indexes
* more things I am not remembering right now...

In some cases the amount of incoming data may be quite large each day, sometimes so rapidly that object statistics are frequently stale within a few minutes of collecting them.

The optimizer does not care if the statistics are stale; that only matters to the jobs that collect statistics.

Being 'stale' does not necessarily mean that the statistics are wholly incorrect, but they might be.

At the very least, the statistics for the number of rows will be incorrect.  

If histograms are collected for some columns, those too may now be incorrect.

Invariably, such schemas and applications are fragile from a performance perspective.
That is, there are several things that can cause performance issues.

Sometimes this is due to a new plan being generated based on incoming data, or a different range of date as indicated by the WHERE clause predicates.

In any case, sudden changes in SQL execution plans may lead to performance degradation.

This does not mean that generating new execution plans is a bad thing, as it may lead to better performance.

Sometimes however, a new execution plan causes degraded performance, sometimes severely so.

Another problem occurs with partitioned tables and objects. 

When first created, they have no statistics.  Millions of rows may be inserted, and then operated on with SQL.
Until the time when statistics are generated, Oracle will use dynamic sampling at the default level of '2'.

Dynamic sampling is better than no statistics, but this may lead to unacceptable performance degradation for high throughput OLTP databases.

It may be a good idea in such cases to copy the statistics from the latest full partition, or use a set of 'standard' statistics that fairly represent the data.
It is even possible to generate statistics manually as part of a data load, then used dbms_stats.set_table|index_statistics with the generated data.

The purpose of this monitor is to detect when a plan change leads to degraded performance, and notify responsible parties about it.


## Fake Database Statistics

See `./swingbench-fake-stats/README.md` for instructions on setting fake statistics.

Why fake statistics?  Lying to the optimizer can cause poor execution plans, which is desirable for testing.























