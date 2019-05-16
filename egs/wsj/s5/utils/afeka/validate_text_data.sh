#!/bin/bash
# Author: Ella Erlich

text=data/train/text
src_dict=data/local/dict/lexicon.txt
phn_diagnostics=false

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

if [ -f $text ] ; then
  echo "Diagnostics for $text"

  # Get unigram counts and the counts of the oov words
  echo "Getting unigram counts"
  cut -d' ' -f2- $text | tr -s ' ' '\n' | \
    awk '{count[$1]++} END{for (w in count) { print count[w], w; }}' | \
    sort -nr > $text.unigrams

  cat $text.unigrams | awk -v dict=$src_dict \
    'BEGIN{while(getline<dict) seen[$1]=1;} {if(!seen[$2]){print;}}' \
    > $text.oov.counts

  cat $text.oov.counts | grep -v "-" | grep -v "+" | grep -v "))" | grep -v "((" > $text.oov.counts.filt
  echo "Most frequent unseen unigrams are: "
  head $text.oov.counts.filt

  # echo "Diagnostics for phoneme $text"
  # if [ $phn_diagnostics ]; then
    # awk -f utils/afeka/word2phn.awk -v lex=$src_dict $text > $text.phn
    # cut -d' ' -f2- $text.phn | tr -s ' ' '\n' | \
      # awk '{count[$1]++} END{for (w in count) { print count[w], w; }}' | \
      # sort -nr > $text.phn.unigrams
  # fi
fi

exit 0;