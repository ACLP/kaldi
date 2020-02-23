#!/usr/bin/perl
#
use File::Basename;

if (@ARGV != 2) {
  print STDERR "Usage: $0 <wav_id_pair_file> <score_file> \n";
  exit(1);
}
($wav_id_pair_file, $score_file) = @ARGV;

my $file2spkr;
open(WAV_ID,"<",$wav_id_pair_file) or die "cannot open $wav_id_pair_file \n";
while (<WAV_ID>) {
	chomp;
	#print "WAV_ID__ $_ \n";
	$_ =~ s/\r|\n//g;
	($wav,$spkr)=split(" ", $_);
	($uttId1, $path, $suffix)=fileparse($wav,'.wav');
	$file2spkr{$uttId1}=$spkr;
}

my %tst_spkr2score;
my %maxIndex;
my %maxTrainFile;
open(SCORES,"<",$score_file);
while (<SCORES>) {
	chomp;
 	$_ =~ s/\r|\n//g;
	($trn_file, $tst_file, $score)=split(" ", $_);
	if (defined($file2spkr{$trn_file})) {
		my @tmp=split("_",$tst_file);
		$tst_file=join("_",@tmp[0..$#tmp-1]);
		$tst_file_index=@tmp[$#tmp];
		$spkr=$file2spkr{$trn_file};
		$key=$spkr." ". $tst_file;
		if (not(defined($tst_spkr2score{$key}))) {
			$tst_spkr2score{$key}=$score;
			$maxIndex{$key}=$tst_file_index;
			$maxTrainFile{$key}=$trn_file;
		} else {
			if ($tst_spkr2score{$key}<$score) {
				$tst_spkr2score{$key}=$score;
				$maxIndex{$key}=$tst_file_index;
				$maxTrainFile{$key}=$trn_file;
      }
		}
	}
}
foreach $key (keys %tst_spkr2score) {
	print $key." ".$tst_spkr2score{$key}." ".$maxIndex{$key}. " ". $maxTrainFile{$key} ."\n";
}
