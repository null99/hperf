#!/bin/perl
# This script watches the availability and delivery time of a website. It tries to simulate a native browser 
# and requests all resources a normal browser would request. The webserver is intended to deliver content 
# with a bandwidth more than $limit. If the target BW is underflown a alert will be send. Sendmail needs 
# to be installed and properly configured to send Mails via Terminal for this script to work.
# 16. Feb. 2014 // null9

my $base 	= $ARGV[0] || 'http://example.com/'; # Base URL to test. trailing slash req.
my $limit 	= 500; 			# Alert if less than x KB/s
my $jitter 	= 3;			# After how many failures the admin will be notified
my $interval 	= 60*60; 		# The interval the test should be made. (in secs) 
my $alert_mail 	= 'null9@example.com';	# Admin email for notifications

## Nothing to do below here

use strict;
use POSIX;
use LWP::UserAgent;
use Time::HiRes qw(gettimeofday);

my $err_cnt = 0;

&log ('Going to monitor URL ' . $base);

## mainloop
if(fork==0)
{while(1){
	my ($took, $size) = 0;
	
	my $ua = LWP::UserAgent->new; $ua->timeout(10);
	my $resp = $ua->get($base);

	if ($resp->is_success) {
		my ($r);
		my $t_start = gettimeofday;
		(my $__m=$resp->decoded_content)=~s#\s+src=['"]([a-z].+?)['"]#chomp;
			$r=$ua->get($base.$1); $size+=length($r->content);#eisg;
		$took = (gettimeofday - $t_start);
	} else { 
		# If unreachable, set the req. time to ~Inf
		$took = LONG_MAX; 
	}

	# BW critical?
	((($size/$took)/1024)<$limit)?($err_cnt++):($err_cnt=0);
	
	&log ("Size: $size Bytes, Took: $took secs, Avg. Rate: "
		. (($size/$took)/1024) . " KB/s, ErrCnt: $err_cnt");

	# Notify admin, if needed
	&notify($err_cnt - $jitter) if($err_cnt>=$jitter);

	sleep($interval);
}}
## end mainloop

sub notify {
	my $reminded_count = shift;
	&log ("Alert: Threshold exceeded");
	&log (qx[echo "The configured threshold BW of $limit KB/s has been reached." |mail -s "Service Alert for $base" $alert_mail ]);
}

sub log { print "@_" . "\n" }
