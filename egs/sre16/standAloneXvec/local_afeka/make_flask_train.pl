#!/usr/bin/perl
#
# Copyright 2015   David Snyder
# Apache 2.0.
# Usage: ./local_afeka/make_eli_train.pl  /storage/DB/eli/wavHpfAdoram/ data/
use File::Basename;
 
if (@ARGV != 4) {
  print STDERR "Usage: $0 <wav_db_base> <path-to-output> <dbname> <wav_id_pair_file>\n";
  print STDERR "e.g. $0 /storage/DB/eli/wavHpfAdoram/ data\n";
  exit(1);
}

($db_base, $out_base_dir, $dbname, $wav_id_pair_file) = @ARGV;
$out_dir = "$out_base_dir/".$dbname."_train";
$tmp_dir = "$out_dir/tmp";
if (system("mkdir -p $tmp_dir") != 0) {
  die "Error making directory $tmp_dir"; 
}

system("cp $wav_id_pair_file $out_dir/original_wav2spkr.txt ");


open(WAV_ID, "<", $wav_id_pair_file) or die "cannot open wav_id list";
open(GNDR,">", "$out_dir/spk2gender") or die "Could not open the output file $out_dir/spk2gender";
open(SPKR,">", "$out_dir/utt2spk") or die "Could not open the output file $out_dir/utt2spk";
open(WAV,">", "$out_dir/wav.scp") or die "Could not open the output file $out_dir/wav.scp";
open(WAV_NEWID,">", "$out_dir/new_uniq_wav2spkr.txt") or die "Could not open the output file $out_dir/new_uniq_wav2spkr.txt";

#%spk2gender = ();
#%utts = ();
while(<WAV_ID>) {
	chomp;
 	$_ =~ s/\r|\n//g;
	($partial_wav, $spkr) = split(" ", $_);
	$wav = "${db_base}/${partial_wav}";
	($uttId1, $path, $suffix)=fileparse($wav,'.wav');
	$spkr=$uttId1;
	$uttId=$spkr . "_" . $uttId1;

	print WAV "$uttId"," sox $wav  -r 8000 -c 1  -t wav - |\n";
	#print WAV "$uttId $wav \n";
	print SPKR "$uttId $spkr \n";
	print GNDR "$spkr m \n";
	print WAV_NEWID "$partial_wav $spkr \n";

	# $spk2gender{$spkr} = "m";
}
#foreach $spkr (keys(%spk2gender)) {
#  print GNDR "$spkr $spk2gender{$spkr}\n";
#}
close(GNDR) || die;
close(SPKR) || die;
close(WAV) || die;
close(WAV_ID) || die;
close(WAV_NEWID) || die;

if (system(
  "utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk >$out_dir/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir";
}
system("utils/fix_data_dir.sh $out_dir");
if (system("utils/validate_data_dir.sh --no-text --no-feats $out_dir") != 0) {
  die "Error validating directory $out_dir";
}
