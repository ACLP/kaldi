#!/usr/bin/env perl
# Author: Ella Erlich

if (length(@ARGV) != 1) {
  print STDERR "Usage: create_segments.pl <maximum-duration> < duration-data > segments\n";
  exit(1);
}

$max_dur = shift @ARGV;

$num_done = 0;
while(<>) {
  @A= split(" ", $_);
  # <audio> <duration>
  $reco = shift @A;
  $duration = shift @A;
  
  $b = 0;
  $end = $duration;
  $wbegin_r = sprintf("%.2f", $b);
  
  while ($duration > ($max_dur + 5)) { #create new segment more than 5 sec
    $e = $b + $max_dur;
    $duration -= $max_dur;
    $wbegin_r = sprintf("%.2f", $b);
    $wend_r = sprintf("%.2f", $e);
    $line = "$reco $wbegin_r $wend_r\n";
    print $line; # goes to stdout.
    $b = $e;
  }
  
  $line = "$reco $wbegin_r $end\n";
  print $line; # goes to stdout.
  $num_done++;
}

if ($num_done == 0) { exit 1; } else { exit 0; }