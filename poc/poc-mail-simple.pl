#!/usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;
use lib './lib';
use Mail::Simple qw(mailit);

my $to = 'jkstill@gmail.com,still@pythian.com';
my $from = 'jkstill@jaredstill.com';
my $subject = 'This is test email sent by Perl Script';
my $message = 'This is where the report would be';

mailit($to,$from,$subject,$message);



