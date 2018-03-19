#!/usr/bin/env perl

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey).  Apache 2.0.
# Modified by Ella Erlich

# This takes as standard input a tra file that's "relative to the utterance",
# i.e. times are measured relative to the beginning of the segments, and it
# uses a "segments" file (format:
# utterance-id recording-id start-time end-time
# ) and a "reco2file_and_channel" file (format:
# recording-id basename-of-file

$skip_unknown=undef;
if ( $ARGV[0] eq "--skip-unknown" ) {
  $skip_unknown=1;
  shift @ARGV;
}

if (@ARGV < 2 || @ARGV > 3) {
  print STDERR "Usage: convert_segmentstext2full.pl <segments-file> <reco2file_and_channel-file> [<utterance-tra>] > real-tra\n";
  exit(1);
}

$segments = shift @ARGV;
$reco2file_and_channel = shift @ARGV;

open(S, "<$segments") || die "failed opening segments file $segments";
while(<S>) {
  @A = split(" ", $_);
  @A == 4 || die "Bad line in segments file: $_";
  ($segmet_id, $utt_id, $begin_time, $end_time) = @A;
  $seg2reco{$segmet_id} = $utt_id;
  $begin{$segmet_id} = $begin_time;
  $end{$segmet_id} = $end_time;
}
close(S);

open(R, "<$reco2file_and_channel") || die "failed opening reco2file_and_channel file $reco2file_and_channel";
while(<R>) {
  @A = split(" ", $_);
  @A == 3 || die "Bad line in reco2file_and_channel file: $_";
  ($utt_id, $file, $channel) = @A;
  $reco2file{$utt_id} = $file;
  $reco2channel{$utt_id} = $channel;
}

# Now process the tra file, which is either the standard input or the third
# command-line argument.
$num_done = 0;
$rec_id = "";
$tra = "";
while(<>) {
  @A= split(" ", $_);
  # lines look like:
  # <utterance-id> word1 word2 word3...
  $segment_id = shift @A;
  $text = join(" ", @A);
  $reco = $seg2reco{$segment_id};

  if (!defined $reco) { 
      next if defined $skip_unknown;
      die "Segment-id $segment_id not defined in segments file $segments"; 
  }
  
  if($rec_id eq "") {
    $tra = "$text";
    $rec_id = $reco;
  } else {
    if($rec_id eq $reco) {
      $tra = "$tra $text";
    } else {
      $rec_id = $reco2file{$rec_id};
      $line = "$rec_id $tra\n";
      print $line; # goes to stdout.
      $tra = "$text";
      $rec_id = $reco;
    }
  }
  $num_done++;
}

$rec_id = $reco2file{$rec_id};
$line = "$rec_id $tra\n";
print $line; # goes to stdout.

if ($num_done == 0) { exit 1; } else { exit 0; }

__END__

# Test example [also test it without the 0.5's]
echo utt reco 10.0 20.0 > segments
echo reco file A > reco2file_and_channel
echo utt 1 8.0 1.0 word 0.5 > ctm_in
echo file A 18.00 1.00 word 0.5 > ctm_out
utils/convert_ctm.pl segments reco2file_and_channel ctm_in | cmp - ctm_out || echo error
rm segments reco2file_and_channel ctm_in ctm_out




