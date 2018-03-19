#!/usr/bin/env perl
# Modified by Ella Erlich

use Getopt::Long;

my $Usage = <<EOU;
  This script reads the wav.dur data and create ecf.xml file
  Usage: create_ecf_xml.pl [options] <wav-dur> <rec2file_and_channel> <out-ecf-xml>\n";
  Allowed options:
  
  --language                  : Language type                               (string,  default = "")
  --version                   : Version                                     (string,  default = "")
EOU

my $language = "";
my $version = "";

GetOptions('language=s'  => \$language,
  'version=s'            => \$version,
  'language=s'           => \$language);
  
if (@ARGV != 3) {
  die $Usage;
}

# Get parameters
my $wav_dur = shift @ARGV;
my $rec2file_and_channel = shift @ARGV;
my $ecf_xml = shift @ARGV;
  
open(R, "<$wav_dur") || die "open wav.dur file $wav_dur";
while(<R>) {
  @A = split(" ", $_);
  @A == 2 || die "Bad line in wav.dur file: $_";
  ($uttID, $dur) = @A;
  push(@Audio, [$uttID, $dur]);
}
close(R);

my %channel_names;
$channel_names{"A"} = 1;
$channel_names{"B"} = 2;
my %channel;
open(R, "<$rec2file_and_channel") || die "open rec2file_and_channel file $rec2file_and_channel";
while(<R>) {
  @A = split(" ", $_);
  @A == 3 || die "Bad line in rec2file_and_channel file: $_";
  ($uttID, $audio, $ch) = @A;
  $channel{$uttID} = $channel_names{$ch}
}
close(R);

# Printing
my $source_duration = SumDuration();
my $ecf_lines = PrintEcfXml();

open(O, ">$ecf_xml");
print O $ecf_lines;
close(O);

# Function for sum durations
sub SumDuration {
  my $duration = "";
  foreach my $audioentry (@Audio) {
    $duration += $audioentry->[1];
  }
  return $duration;
}

# Function for printing ecf.xml
sub PrintEcfXml {
  my $ecflist = "";
  # Start printing
  $ecflist .= "<ecf source_signal_duration=\"$source_duration\" language=\"$language\" version=\"$version\">\n";
  foreach my $audioentry (@Audio) {
    $audio = $audioentry->[0];
    $dur = $audioentry->[1];
    $ch = $channel{$audio};
    $ecflist .= "  <excerpt audio_filename=\"$audio\" channel=\"$ch\" tbeg=\"0.000\" dur=\"$dur\" source_type=\"splitcts\"/>\n";
  }
  $ecflist .= "</ecf>\n";
  return $ecflist;
}