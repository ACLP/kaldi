#!/bin/bash

# Copyright 2012  Johns Hopkins University (Author: Guoguo Chen)
# Apache 2.0.
# Modified by Ella Erlich

# Begin configuration section.
case_insensitive=true
use_icu=true
icu_transform="Any-Lower"
silence_word=  # Optional silence word to insert (once) between words of the transcript.
kwmapping=
# End configuration section.

echo $0 "$@"

help_message="
   Usage: $(basename $0) <lang-dir> <data-dir> <kws-data-dir>
    e.g.: $(basename $0) data/lang/ data/eval/ data/kws/
   Input is in <kws-data-dir>: kwlist.xml, ecf.xml (rttm file not needed).
   Output is in <kws-data/dir>: keywords.txt, keywords_all.int, kwlist_invocab.xml,
       kwlist_outvocab.xml, keywords.fsts
   Note: most important output is keywords.fsts
   allowed switches:
      --case-sensitive <true|false>      # Shall we be case-sensitive or not?
                                         # Please not the case-sensitivness depends
                                         # on the shell locale!
      --use-uconv <true|false>           # Use the ICU uconv binary to normalize casing
      --icu-transform <string>           # When using ICU, use this transliteration
      --kwmapping                        # use kws mapping for additional results
"

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;


if [ $# -ne 3 ]; then
  printf "FATAL: invalid number of arguments.\n\n"
  printf "$help_message\n"
  exit 1;
fi

set -u
set -e
set -o pipefail

langdir=$1;
datadir=$2;
kwsdatadir=$3;
keywords=$kwsdatadir/kwlist.xml

mkdir -p $kwsdatadir;

cat $keywords | perl -e '
  binmode STDOUT, ":utf8"; 

  use XML::Simple;

  my $data = XMLin(\*STDIN);

  foreach $kwentry (@{$data->{kw}}) {
    print "$kwentry->{kwid}\t$kwentry->{kwtext}\n";
  }' > $kwsdatadir/keywords.txt

if [ ! -z $kwmapping ]; then
  echo "create new list for kwmapping"
  gawk -v mapfile=$kwmapping -f utils/afeka/kws/add_keywords.awk $kwsdatadir/keywords.txt > $kwsdatadir/keywords_fixed.txt
  cp $kwsdatadir/keywords_fixed.txt $kwsdatadir/keywords.txt
  rm $kwsdatadir/keywords_fixed.txt
fi

# Map the keywords to integers; note that we remove the keywords that
# are not in our $langdir/words.txt, as we won't find them anyway...
#cat $kwsdatadir/keywords.txt | babel/filter_keywords.pl $langdir/words.txt - - | \
#  sym2int.pl --map-oov 0 -f 2- $langdir/words.txt | \
if  $case_insensitive && ! $use_icu  ; then
  echo "$0: Running case insensitive processing"
  cat $langdir/words.txt | tr '[:lower:]' '[:upper:]'  > $kwsdatadir/words.txt
  [ `cut -f 1 -d ' ' $kwsdatadir/words.txt | sort -u | wc -l` -ne `cat $kwsdatadir/words.txt | wc -l` ] && \
    echo "$0: Warning, multiple words in dictionary differ only in case: "
    

  cat $kwsdatadir/keywords.txt | tr '[:lower:]' '[:upper:]'  | \
    sym2int.pl --map-oov 0 -f 2- $kwsdatadir/words.txt > $kwsdatadir/keywords_all.int
elif  $case_insensitive && $use_icu ; then
  echo "$0: Running case insensitive processing (using ICU with transform \"$icu_transform\")"
  cat $langdir/words.txt | uconv -f utf8 -t utf8 -x "${icu_transform}"  > $kwsdatadir/words.txt
  [ `cut -f 1 -d ' ' $kwsdatadir/words.txt | sort -u | wc -l` -ne `cat $kwsdatadir/words.txt | wc -l` ] && \
    echo "$0: Warning, multiple words in dictionary differ only in case: "

  paste <(cut -f 1  $kwsdatadir/keywords.txt  ) \
        <(cut -f 2  $kwsdatadir/keywords.txt | uconv -f utf8 -t utf8 -x "${icu_transform}" ) |\
    utils/afeka/kws/kwords2indices.pl --map-oov 0  $kwsdatadir/words.txt > $kwsdatadir/keywords_all.int
else
  cp $langdir/words.txt  $kwsdatadir/words.txt
  cat $kwsdatadir/keywords.txt | \
    sym2int.pl --map-oov 0 -f 2- $kwsdatadir/words.txt > $kwsdatadir/keywords_all.int
fi

(cat $kwsdatadir/keywords_all.int | \
  grep -v " 0 " | grep -v " 0$" > $kwsdatadir/keywords.int ) || true

(cut -f 1 -d ' ' $kwsdatadir/keywords.int | \
  utils/afeka/kws/subset_kwslist.pl $keywords > $kwsdatadir/kwlist_invocab.xml) || true

(cat $kwsdatadir/keywords_all.int | \
  egrep " 0 | 0$" > $kwsdatadir/keywordsֹ_oov.int) || true

(cut -f 1 -d ' ' $kwsdatadir/keywordsֹ_oov.int | \
  utils/afeka/kws/subset_kwslist.pl $keywords > $kwsdatadir/kwlist_outvocab.xml) || true

if [ -s $kwsdatadir/keywords.int ]; then
  cat $kwsdatadir/kwlist_invocab.xml | grep -a "<kwtext>" | sed 's#^.*<kwtext>##' | sed 's#</kwtext>##' > $kwsdatadir/kwlist_invocab.raw
else
  echo > $kwsdatadir/kwlist_invocab.raw
fi
if [ -s $kwsdatadir/keywordsֹ_oov.int ]; then
  cat $kwsdatadir/kwlist_outvocab.xml | grep -a "<kwtext>" | sed 's#^.*<kwtext>##' | sed 's#</kwtext>##' > $kwsdatadir/kwlist_outvocab.raw
else
  echo > $kwsdatadir/kwlist_outvocab.raw
fi

#cat $kwsdatadir/kwlist_invocab.xml | perl -e '
#  binmode STDIN, ":utf8"; 
#  binmode STDOUT, ":utf8"; 
#
#  use XML::Simple;
#
#  my $data = XMLin(\*STDIN);
#
#  foreach $kwentry (@{$data->{kw}}) {
#    print "$kwentry->{kwtext}\n";
#  }' > $kwsdatadir/keywords_invocab.raw
  
#cat $kwsdatadir/kwlist_outvocab.xml | perl -e '
#  binmode STDIN, ":utf8"; 
#  binmode STDOUT, ":utf8"; 

#  use XML::Simple;

#  my $data = XMLin(\*STDIN);

#  foreach $kwentry (@{$data->{kw}}) {
#    print "$kwentry->{kwtext}\n";
#  }' > $kwsdatadir/keywords_outvocab.raw

cat $kwsdatadir/keywords.raw | awk '{ for (i=1; i<=NF; i++) { print $i }}' | sort | uniq > $kwsdatadir/keywords_words.raw
cat $kwsdatadir/kwlist_invocab.raw | awk '{ for (i=1; i<=NF; i++) { print $i }}' | sort | uniq > $kwsdatadir/inv_words.raw
cat $kwsdatadir/kwlist_outvocab.raw | awk '{ for (i=1; i<=NF; i++) { print $i }}' | sort | uniq > $kwsdatadir/oov_words.raw

awk "BEGIN { while ((getline < \"$kwsdatadir/keywords_words.raw\")>0) word[\$1] = 1} { if (\$1 in word) print \$0 }" $langdir/lexicon.txt > $kwsdatadir/inv_words.dict

# Compile keywords into FSTs
if [ -s $kwsdatadir/keywords.int ]; then
  if [ -z $silence_word ]; then
    transcripts-to-fsts ark:$kwsdatadir/keywords.int ark,t:$kwsdatadir/keywords.fsts
  else
    silence_int=`grep -w $silence_word $langdir/words.txt | awk '{print $2}'`
    [ -z $silence_int ] && \
       echo "$0: Error: could not find integer representation of silence word $silence_word" && exit 1;
    transcripts-to-fsts ark:$kwsdatadir/keywords.int ark,t:- | \
      awk -v 'OFS=\t' -v silint=$silence_int '{if (NF == 4 && $1 != 0) { print $1, $1, silint, silint; } print; }' \
      > $kwsdatadir/keywords.fsts
  fi
else
  echo "WARNING: $kwsdatadir/keywords.int is zero-size. That means no keyword"

  echo "WARNING: was found in the dictionary. That might be OK -- or not."
  touch $kwsdatadir/keywords.fsts
fi

# Create utterance id for each utterance
if [ -f $datadir/segments ]; then
  utt_data=$datadir/segments
  # Map utterance to the names that will appear in the rttm file. You have 
  # to modify the commands below accoring to your rttm file
  cat $utt_data | awk '{print $1" "$2}' | sort | uniq > $kwsdatadir/utter_map;
else
  utt_data=$datadir/wav.scp
  cat $utt_data | awk '{print $1" "$1}' | sort | uniq > $kwsdatadir/utter_map;
fi

cat $utt_data | \
  awk '{print $1}' | \
  sort | uniq | perl -e '
  $idx=1;
  while(<>) {
    chomp;
    print "$_ $idx\n";
    $idx++;
  }' > $kwsdatadir/utter_id

echo "$0: Kws data preparation succeeded"
