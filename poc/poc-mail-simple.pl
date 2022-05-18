#!/usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;
use lib './lib';
use Mail::Simple qw(mailit);

my $to = 'dba01@somedomain.com,dba02@somedomain.com';
my $from = 'oracle@my-oracle-server.com';
my $subject = 'This is test email sent by Perl Script';
my $message = 'This is where the report would be';

mailit($to,$from,$subject,$message);

