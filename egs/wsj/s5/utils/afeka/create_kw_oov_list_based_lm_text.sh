#!/bin/bash
# Author: Ella Erlich

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 2 ]; then
   echo "Usage: $(basename $0) <LVCSR-lang-dir> <kw-data-dir>"
   echo "e.g.: $(basename $0) data/lang_LVCSR data/dev/kw"
   exit 1;
fi

lang_LVCSR=$1
kw_data_dir=$2

LVCSR_lm_data_text=$lang_LVCSR/lm_text
LVCSR_lm_words=$lang_LVCSR/lm_word.counts

keywords=$kw_data_dir/keywords.raw
keywords_count=$kw_data_dir/keywords_word.counts
oov_kw_words_count=$kw_data_dir/keywords_outvocab_word.counts
oov_keywords=$kw_data_dir/keywords_outvocab.raw

# This is just for diagnostics:
#!!!start_index=2!!! with segment_id
cat $LVCSR_lm_data_text | \
  awk '{for (n=2;n<=NF;n++){ count[$n]++; } } END { for(n in count) { print count[n], n; }}' | \
  sort -nr > $LVCSR_lm_words

cat $keywords | \
  awk '{for (n=1;n<=NF;n++){ count[$n]++; } } END { for(n in count) { print count[n], n; }}' | \
  sort -nr > $keywords_count

awk '{print $2}' $LVCSR_lm_words | \
perl -e '($word_counts)=@ARGV;
 open(W, "<$word_counts")||die "opening word-counts $word_counts";
 while(<STDIN>) { chop; $seen{$_}=1; }
 while(<W>) {
   ($c,$w) = split;
   if (!defined $seen{$w}) { print; }
} ' $keywords_count > $oov_kw_words_count

cat $keywords | awk -v lex=$oov_kw_words_count 'BEGIN{while((getline<lex) >0){ seen[$2]=1; } } 
  {for(n=1; n<=NF;n++) {  if (seen[$n]) {printf($_);} break; } printf("\n");}' | \
  sort -nr | uniq > $oov_keywords || exit 1;

exit 0;
