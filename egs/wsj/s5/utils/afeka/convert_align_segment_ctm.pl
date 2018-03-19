#!/usr/bin/env perl

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey).  Apache 2.0.
# Modified by Ella Erlich

# This takes as standard input a ctm file that's "relative to the utterance",
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

if (@ARGV < 1 || @ARGV > 2) {
  print STDERR "Usage: convert_align_segment_ctm.pl <align-text-file> [<utterance-ctm>] > real-ctm\n";
  exit(1);
}

$text = shift @ARGV;

open(S, "<$text") || die "opening align text file $text";
while(<S>) {
  @A = split(" ", $_);
  $utt = shift @A;
  $content{$utt} = [ @A ];
}
close(S);

# Now process the ctm file, which is either the standard input or the third
# command-line argument.
$num_done = 0;
$utt_c = "";
while(<>) {
  @A= split(" ", $_);
  ( @A == 5 || @A == 6 ) || die "Unexpected ctm format: $_";
  # lines look like:
  # <utterance-id> 1 <begin-time> <length> <word> [ confidence ]
  ($utt, $one, $wbegin, $wlen, $w, $conf) = @A;
  if ($utt_c ne $utt) {
    #print STDERR "new utt: $utt, word_0: @{$content{$utt}}[$i]\n";
    $utt_c = $utt;
    $i = 0;
  } else {
    $i = $i + 1;
  }
  $w = @{$content{$utt}}[$i];
  $wbegin = sprintf("%.2f", $wbegin);
  $wlen = sprintf("%.2f", $wlen);
  if (defined $conf) {
    $line = "$utt $one $wbegin $wlen $w $conf\n"; 
  } else {
    $line = "$utt $one $wbegin $wlen $w\n"; 
  }
  print $line; # goes to stdout.
  $num_done++;
}

if ($num_done == 0) { exit 1; } else { exit 0; }

__END__

# Test example [also test it without the 0.5's]
echo utt reco 10.0 20.0 > segments
echo reco file A > reco2file_and_channel
echo utt 1 8.0 1.0 word 0.5 > ctm_in
echo file A 18.00 1.00 word 0.5 > ctm_out
utils/convert_ctm.pl segments reco2file_and_channel ctm_in | cmp - ctm_out || echo error
rm segments reco2file_and_channel ctm_in ctm_out




