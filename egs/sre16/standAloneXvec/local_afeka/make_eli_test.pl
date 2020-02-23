#!/usr/bin/perl
#
# Copyright 2015   David Snyder
# Apache 2.0.
# Usage: ./local_afeka/make_eli_test.pl  /storage/DB/eli/wavHpfAdoram/ data/
use File::Basename;
 
if (@ARGV != 2) {
  print STDERR "Usage: $0 <path-to-eli-wav> <path-to-output>\n";
  print STDERR "e.g. $0 /storage/DB/eli/wavHpfAdoram/ data\n";
  exit(1);
}

($db_base, $out_base_dir) = @ARGV;
$out_dir = "$out_base_dir/eli_test";

$tmp_dir = "$out_dir/tmp";
if (system("mkdir -p $tmp_dir") != 0) {
  die "Error making directory $tmp_dir"; 
}
open(IN_TRIALS1, "<", "$db_base/../adoram_file_spkr_list.txt") or die "cannot open trials list";
open(OUT_TRIALS, ">", "$out_dir/trials") or die "cannot open trials list";
%trials = ();
while(<IN_TRIALS1>) { #will be used as enrolled speaker
	chomp;
	($uttId1,$spkr1) = split(" ", $_);  #use file name as speaker name - do all vs all
	open(IN_TRIALS2, "<", "$db_base/../adoram_file_spkr_list.txt") or die "cannot open trials list";
	while(<IN_TRIALS2>) {  # will be used as test utterance
		chomp;
		($uttId2,$spkr2) = split(" ", $_);  #use file name as speaker name - do all vs all
		if ($uttId1 ne $uttId2) {
			$is_target='nontarget';
			if ($spkr1==$spkr2) {
				$is_target='target';
			}
			$key = "${uttId1} ${uttId2}"; # Just keep track of the spkr-utterance pairs we want.
			$trials{$key} = 1; # Just keep track of the spkr-utterance pairs we want.
			print OUT_TRIALS "${uttId1} ${uttId2} $is_target\n";
		}
	}
	close(IN_TRIALS2) || die;
}
close(OUT_TRIALS) || die;
close(IN_TRIALS1) || die;


open(WAVLIST, "<", "$db_base/../adoram_file_spkr_list.txt") or die "cannot open wav list";
open(GNDR,">", "$out_dir/spk2gender") or die "Could not open the output file $out_dir/spk2gender";
open(SPKR,">", "$out_dir/utt2spk") or die "Could not open the output file $out_dir/utt2spk";
open(WAV,">", "$out_dir/wav.scp") or die "Could not open the output file $out_dir/wav.scp";

%spk2gender = ();
%utts = ();
while(<WAVLIST>) {
	chomp;
	($uttId, $spkr) = split(" ", $_);
	$wav = "${db_base}/${uttId}.wav";

	#print WAV "$uttId"," sox $wav  -r 8000 -c 1  -t wav - |\n";
	print WAV "$uttId"," $wav \n";
	print SPKR "$uttId $uttId\n";
	print GNDR "$uttId m\n";

  $spk2gender{$spkr} = "m";
}
#foreach $spkr (keys(%spk2gender)) {
#  print GNDR "$spkr $spk2gender{$spkr}\n";
#}
close(GNDR) || die;
close(SPKR) || die;
close(WAV) || die;
close(WAVLIST) || die;

if (system(
  "utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk >$out_dir/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir";
}
system("utils/fix_data_dir.sh $out_dir");
if (system("utils/validate_data_dir.sh --no-text --no-feats $out_dir") != 0) {
  die "Error validating directory $out_dir";
}
