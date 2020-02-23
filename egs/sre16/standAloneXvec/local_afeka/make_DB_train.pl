#!/usr/bin/perl
#
# Copyright 2015   David Snyder
# Apache 2.0.
# Usage: ./local_afeka/make_14spk_train.pl /mnt/share/kaldi/test/audio_hakol-dib_15spk/  data/ 15spk
use File::Basename;
 
if (@ARGV != 3) {
  print STDERR "Usage: $0 <path-to-14spk-wav> <path-to-output> <db-short-name>\n";
  print STDERR "e.g. $0 /mnt/share/kaldi/test/audio_hakol-dib_14spkr_130717/  data 14spk\n";
  exit(1);
}

($db_base, $out_base_dir, $dbname) = @ARGV;
$out_dir = "$out_base_dir/".$dbname."_train";

$tmp_dir = "$out_dir/tmp";
if (system("mkdir -p $tmp_dir") != 0) {
  die "Error making directory $tmp_dir"; 
}


open(WAVLIST, "<", "$out_dir/hakol_wav_files_list.txt") or die "cannot open wav list";
open(GNDR,">", "$out_dir/spk2gender") or die "Could not open the output file $out_dir/spk2gender";
open(SPKR,">", "$out_dir/utt2spk") or die "Could not open the output file $out_dir/utt2spk";
open(WAV,">", "$out_dir/wav.scp") or die "Could not open the output file $out_dir/wav.scp";
open(NEWLIST, ">", "$out_dir/newfilelist.txt") or die "Could not open the output file $out_dir/newfilelist.txt";

%spk2gender = ();
%utts = ();
while(<WAVLIST>) {
	chomp;
  $wav=$_;
  ($uttId, $path, $suffix)=fileparse($wav,'.wav');
  ($tmp1,$tmp2,,$tmp3,$spkr) = split("\/", $path);
  #print "$uttId $spkr  \n"; 
	#$wav = "${db_base}/${uttId}.wav";

	#print WAV "$uttId"," sox $wav  -r 8000 -c 1  -t wav - |\n";
	print WAV "$uttId"," $wav \n";
	print SPKR "$uttId $uttId\n";
	print GNDR "$uttId m\n";
  print NEWLIST "$spkr $uttId $wav\n";

  $spk2gender{$spkr} = "m";
}
#foreach $spkr (keys(%spk2gender)) {
#  print GNDR "$spkr $spk2gender{$spkr}\n";
#}
close(GNDR) || die;
close(SPKR) || die;
close(WAV) || die;
close(WAVLIST) || die;
close(NEWLIST) || die;

if (system(
  "utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk >$out_dir/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir";
}
system("utils/fix_data_dir.sh $out_dir");
if (system("utils/validate_data_dir.sh --no-text --no-feats $out_dir") != 0) {
  die "Error validating directory $out_dir";
}
