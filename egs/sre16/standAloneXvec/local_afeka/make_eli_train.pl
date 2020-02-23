#!/usr/bin/perl
#
# Copyright 2015   David Snyder
# Apache 2.0.
# Usage: ./local_afeka/make_eli_train.pl  /storage/DB/eli/wavHpfAdoram/ data/
use File::Basename;
 
if (@ARGV != 2) {
  print STDERR "Usage: $0 <path-to-eli-wav> <path-to-output>\n";
  print STDERR "e.g. $0 /storage/DB/eli/wavHpfAdoram/ data\n";
  exit(1);
}

($db_base, $out_base_dir) = @ARGV;
$out_dir = "$out_base_dir/eli_train";

$tmp_dir = "$out_dir/tmp";
if (system("mkdir -p $tmp_dir") != 0) {
  die "Error making directory $tmp_dir"; 
}


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
