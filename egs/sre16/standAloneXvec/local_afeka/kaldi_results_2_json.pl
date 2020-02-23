#!/usr/bin/perl
# kaldi results to json
if (@ARGV != 2) {
  print STDERR "Usage: $0 <results file> <normalization_file>\n";
  exit(1);
}

($res_file, $normalization_file) = @ARGV;
open(NORM, "<", $normalization_file) or die "cannot open kaldi results file";
while(<NORM>) {
	chomp;
	($mean, $std) = split(" ", $_);
}
close(NORM);

print "{ \n";
open(IN, "<", $res_file) or die "cannot open kaldi results file";
my $start=1;
while(<IN>) {
	chomp;
	if ($start==0) {
		print ", \n";
	}
	$start=0;
	($spkr, $utt, $score) = split(" ", $_);
	$score=($score-$mean)/$std;
	print "\"$spkr $utt\" : \"$score\"";

}
close(IN);
print "\n} \n";
