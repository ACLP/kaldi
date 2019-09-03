#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.
phn_diagnostics=false
start_field=1 # 1 without segment ID, 2 with segment ID
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

if [ $# -ne 2 ]; then
  echo "Usage: $(basename $0) <text-data> <lexicon-file>"
  echo "e.g.: $(basename $0) data/train/text data/local/dict/lexicon.txt"
  echo "Options:"
  echo "--start-field        # text start field ( default 2, with utt ID)"
  exit 1;
fi

text=$1
lexicon=$2

if [ -f $text ] ; then
  echo "Diagnostics for $text"

  # Get unigram counts and the counts of the oov words
  echo "Getting unigram counts"
  cut -d' ' -f $start_field- $text | tr -s ' ' '\n' | \
    awk '{count[$1]++} END{for (w in count) { print count[w], w; }}' | \
    sort -nr > $text.unigrams

  cut -d' ' -f2 $text.unigrams | grep -v [0-9] | grep -v '^|-' | grep -v '$|-' | grep -v "+" | grep -v "))" | grep -v "((" | awk -v dict=$lexicon \
    'BEGIN{while(getline<dict) seen[$1]=1;} {if(!seen[$1]){print;}}' \
    > $text.oov

  cat $text.unigrams | awk -v oov=$text.oov \
    'BEGIN{while(getline<oov) seen[$1]=1;} {if(seen[$2]){print;}}' \
    > $text.oov.counts && rm $text.oov

  # echo "Diagnostics for phoneme $text"
  # if [ $phn_diagnostics ]; then
    # awk -f utils/afeka/word2phn.awk -v lex=$src_dict $text > $text.phn
    # cut -d' ' -f2- $text.phn | tr -s ' ' '\n' | \
      # awk '{count[$1]++} END{for (w in count) { print count[w], w; }}' | \
      # sort -nr > $text.phn.unigrams
  # fi
fi

exit 0;