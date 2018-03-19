#!/usr/bin/env perl
# Modified by Ella Erlich

use Getopt::Long;

my $Usage = <<EOU;
  This script reads the keyword idx list and create kwslist.xml file
  Usage: create_kw_xml.pl [options] <kw-idx> <out-kw-xml>\n";
  Allowed options:
  
  --ecf-filename              : ECF file name                               (string,  default = "") 
  --language                  : Language type                               (string,  default = "")
  --version                   : Version                                     (string,  default = "")
  --compareNormalize          : KW normalize                                (string,  default = "lowercase")
  --encoding                  : KW encoding                                 (string,  default = "UTF-8")
EOU

my $ecf_filename = "";
my $language = "";
my $version = "";
my $compareNormalize = "lowercase";
my $encoding = "UTF-8";

GetOptions('ecf-filename=s'     => \$ecf_filename,
  'language=s'         => \$language,
  'version=s'         => \$version,
  'compareNormalize=s'     => \$compareNormalize,
  'language=s'     => \$language,
  'encoding=s' => \$encoding);
  
if (@ARGV != 2) {
  die $Usage;
}

# Get parameters
my $kw_idx = shift @ARGV;
my $kw_xml = shift @ARGV;
  
open(R, "<$kw_idx") || die "open kw-idx file $kw_idx";
while(<R>) {
  @A = split(" ", $_);
  @A == 2 || die "Bad line in kw-idx file: $_";
  ($kwid, $kw) = @A;
  push(@KWS, [$kwid, $kw]);
}
close(R);

# Printing
my $kwslist = PrintKwslist();

open(O, ">$kw_xml");
print O $kwslist;
close(O);


# Function for printing Kwslist.xml
sub PrintKwslist {
  my $kwslist = "";
  # Start printing
  $kwslist .= "<kwlist ecf_filename=\"$ecf_filename\" language=\"$language\" version=\"$version\" compareNormalize=\"$compareNormalize\" encoding=\"$encoding\">\n";
  foreach my $kwentry (@KWS) {
    $kw_id = $kwentry->[0];
    $kw = $kwentry->[1];
    $kwslist .= "  <kw kwid=\"$kw_id\">\n";
    $kwslist .= "    <kwtext>$kw</kwtext>\n";
    $kwslist .= "  </kw>\n";
  }
  $kwslist .= "</kwlist>\n";
  
  return $kwslist;
}