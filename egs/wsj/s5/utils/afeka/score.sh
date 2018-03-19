#!/bin/bash
# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# Modified by Ella Erlich

# begin configuration section.
cmd=run.pl
min_lmwt=5
max_lmwt=25
ref_text=
iter=final
#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $(basename $0) [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo "e.g.: $(basename $0) data/dev data/lang_test exp/tri3/decode_dev"
  echo "Options:"
  echo "--cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "--ref-text                      # option fo ref text data"
  echo "--min-lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "--max-lmwt <int>                # maximum LM-weight for lattice rescoring "
  exit 1;
fi

data_dir=$1
lang_or_graph=$2
decode_dir=$3

symtab=$lang_or_graph/words.txt

if [ -z $ref_text ] ; then
  ref_text=$data_dir/text
fi

for f in $symtab $decode_dir/lat.1.gz $ref_text; do
  [ ! -f $f ] && echo "score.sh: no such file $f" && exit 1;
done

echo "using $ref_text as reference data"

mkdir -p $decode_dir/scoring/log

filtering_cmd="cat"
[ -x local/wer_filter ] && filtering_cmd="local/wer_filter"

cp $ref_text $decode_dir/scoring/ref_text
cat $decode_dir/scoring/ref_text | $filtering_cmd > $decode_dir/scoring/ref_text.filt || exit 1;

# # Get the sequence on the best-path:
# $cmd LMWT=$min_lmwt:$max_lmwt $decode_dir/scoring/log/best_path.LMWT.log \
  # lattice-best-path --lm-scale=LMWT --word-symbol-table=$symtab \
  # "ark:gunzip -c $decode_dir/lat.*.gz|" ark,t: \| \
  # utils/int2sym.pl -f 2- $symtab '>' $decode_dir/scoring/LMWT.tra || exit 1;

$cmd INV_ACWT=$min_lmwt:$max_lmwt $decode_dir/scoring/log/rescore_mbr.INV_ACWT.log \
  lattice-mbr-decode --acoustic-scale=\`perl -e \"print 1.0/INV_ACWT\"\` --word-symbol-table=$symtab \
  "ark:gunzip -c $decode_dir/lat.*.gz|" ark,t: \| \
  utils/int2sym.pl -f 2- $symtab '>' $decode_dir/scoring/INV_ACWT.tra

for LMWT in `seq $min_lmwt $max_lmwt`; do
  cat $decode_dir/scoring/$LMWT.tra | $filtering_cmd > $decode_dir/scoring/$LMWT.filt || exit 1;
done

$cmd LMWT=$min_lmwt:$max_lmwt $decode_dir/scoring/log/score.LMWT.log \
   cat $decode_dir/scoring/LMWT.filt \| \
   compute-wer --text --mode=present \
   ark:$decode_dir/scoring/ref_text.filt ark,p:- ">&" $decode_dir/wer_LMWT || exit 1;
   #ark:$dir/scoring/test_filt.txt ark,p:- $decode_dir/scoring/stats_LMWT ">&" $decode_dir/wer_LMWT || exit 1;

grep WER $decode_dir/wer_* | utils/best_wer.sh || exit 1;

exit 0;

