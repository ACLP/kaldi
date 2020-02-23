#!/usr/bin/perl
#
# Copyright 2015   David Snyder
# Apache 2.0.
# Usage: ./local_afeka/make_14spk_test.pl  /mnt/share/kaldi/test/audio_hakol-dib_14spkr_130717/ data/
use File::Basename;
use File::Slurp;

if (@ARGV != 3) {
  print STDERR "Usage: $0 <path-to-test-audio-base-path> <path-to-output> <db-short-name> <list-of-test-file-names-with-path-relative-to-input>\n";
  print STDERR "e.g. $0 /mnt/share/kaldi/test/audio_hakol-dib_14spkr_130717/ data 14spk\n";
  exit(1);
}

($db_base, $out_base_dir, $dbname, $testFileNames_relPath) = @ARGV;
$out_dir = "$out_base_dir/".$dbname."_test";

$tmp_dir = "$out_dir/tmp";
if (system("mkdir -p $tmp_dir") != 0) {
  die "Error making directory $tmp_dir"; 
}

# load models
open(WAV_ID, "<", $wav_id_pair_file) or die "cannot open wav_id list";
my @modelsUtterances = read_file($testFileNames_relPath , chomp => 1); # will chomp() each line


my @inTrialsFiles = read_file($testFileNames_relPath , chomp => 1); # will chomp() each line
open(OUT_TRIALS, ">", "$out_dir/trials") or die "cannot open trials list";
open(GNDR,">", "$out_dir/spk2gender") or die "Could not open the output file $out_dir/spk2gender";
open(SPKR,">", "$out_dir/utt2spk") or die "Could not open the output file $out_dir/utt2spk";
open(WAV,">", "$out_dir/wav.scp") or die "Could not open the output file $out_dir/wav.scp";

for my $i (0 .. $#inTrialsFiles)
{	
	$wav=$db_base . "/" . $inTrialsFiles[$i];
	($uttId1, $path, $suffix)=fileparse($wav,'.wav');

	print WAV "$uttId1"," $wav \n";
	print SPKR "$uttId1 $uttId1\n";
	print GNDR "$uttId1 m\n";

	for my $j (0 .. $#modelsUtterances) {
		$uttId2=$modelsUtterances[$j];
		print OUT_TRIALS "${uttId1} ${uttId2} 'nontarget'\n";	
	}
}
close(OUT_TRIALS) || die;
close(GNDR) || die;
close(SPKR) || die;
close(WAV) || die;


if (system(
  "utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk >$out_dir/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir";
}
system("utils/fix_data_dir.sh $out_dir");
if (system("utils/validate_data_dir.sh --no-text --no-feats $out_dir") != 0) {
  die "Error validating directory $out_dir";
}
