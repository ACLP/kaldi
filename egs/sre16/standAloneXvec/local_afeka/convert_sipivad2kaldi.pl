#!/usr/bin/perl
#
# Usage: ./local_afeka/convert_sipivad2kaldi.pl sipivad/ eli_vad.scp eli_vad.ark
use File::Basename;
use 5.010;


if (@ARGV != 3) {
  print STDERR "Usage: $0 <path-to-original-vad> <scp-output-file> <ark-output-file>\n";
  print STDERR "e.g. $0 sipivad/ eli_vad.scp eli_vad.ark \n";
  exit(1);
}
my $frame_shift=0.01;  # frame shift
my $frame_len=0.025; 
($original_path, $scp_file, $ark_file) = @ARGV;
open(SCP,">", "$scp_file") or die "Could not open the output file $scp_file";  # file -> pointers to ark
open(ARK,">", "$ark_file") or die "Could not open the output file $ark_file";  # actual vad data

opendir(DIR,"$original_path") or die "Cannot open $original_path\n";
my @files = readdir(DIR);
closedir(DIR);
my $ark_pos=-1;
foreach my $file (@files) {
	next if ($file !~ /\.lbl$/i);
	($mybasename,$path,$suffix) = fileparse($file,".lbl");

	# get wav file size and number of frames:
	my $wavfile = "/storage/DB/eli/wavHpfAdoram/" . $mybasename . ".wav";
	my $wavsize = -s $wavfile;
	my $nFrames = int($wavsize / 160);

	print ARK $mybasename." [ ";
	my $mybasename_len= 3+length $mybasename;
	$ark_pos=$ark_pos+$mybasename_len;
	#print 1+$ark_pos. " \n";
	printf(SCP "%s %s:%d \n",$mybasename,$ark_file,$ark_pos-1);
	
	open(F,"<",$original_path . $file);
	my $previous_vad_end=0;
	while (<F>) {
		chomp;
		($start_sec, $end_sec, $speech) = split(" ", $_);
		#print 100*$start_sec. " " . 100*$end_sec . " ". 100*($start_sec-$previous_vad_end). " ". 100*($end_sec-$start_sec) ."\n";
		# for begining take frames starting in the active speech range
		for (my $i=int(0.5+$previous_vad_end*100); $i < int(0.5+$start_sec*100)-1; $i++) {
			print ARK "0 ";
		}
		my $new_start=int(0.5+$start_sec*100)-1;
		if ($new_start<0) {$new_start =0;}
		for (my $i=$new_start; $i < int(0.5+$end_sec*100); $i++) {
			print ARK "1 ";
		}		
		$previous_vad_end=$end_sec;
	}
	for (my $i=int(0.5+$previous_vad_end*100); $i <$nFrames; $i++) {
			print ARK "0 ";
		}
	# for (my $i=0; $i<$nFrames; $i++) {
		# print ARK "1 ";
	# }

	print ARK "] ";

	$ark_pos=$ark_pos+2*$nFrames+2;  # printed 2 chars (0|1 + " ") per frame + closing bracelet '] '
	#print "$ark_pos ".200*$end_sec+1 . "\n";
	close(F)
}
close(SCP);
close(ARK);