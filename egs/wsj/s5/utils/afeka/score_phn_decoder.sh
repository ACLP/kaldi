#!/bin/bash
# Author: Ella Erlich

# begin configuration section.
cmd=run.pl
stage=0
min_lmwt=1
max_lmwt=10
ref_text=
iter=final
#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $(basename $0) [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo "e.g.: $(basename $0) data/dev exp/tri3/phone_graph exp/tri3/decode_phn_dev"
  echo "Options:"
  echo "--cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "--stage (0|1|2)                 # start scoring script from part-way through."
  echo "--ref-text                      # option fo ref text data"
  echo "--min-lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "--max-lmwt <int>                # maximum LM-weight for lattice rescoring "
  exit 1;
fi

data=$1
lang_or_graph=$2
dir=$3

symtab=$lang_or_graph/words.txt

if [ -z $ref_text ] ; then
  ref_text=$data/phn.align.tra
fi

echo "using $ref_text as reference data"

for f in $symtab $dir/lat.1.gz $ref_text; do
  [ ! -f $f ] && echo "score.sh: no such file $f" && exit 1;
done

mkdir -p $dir/scoring/log

filtering_cmd="cat"
[ -x local/per_filter ] && filtering_cmd="local/per_filter"

cp $ref_text $dir/scoring/test
cat $dir/scoring/test | $filtering_cmd > $dir/scoring/test_filt.txt || exit 1;

# Get the sequence on the best-path:
$cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/best_path.LMWT.log \
  lattice-best-path --lm-scale=LMWT --word-symbol-table=$symtab \
  "ark:gunzip -c $dir/lat.*.gz|" ark,t: \| \
  utils/int2sym.pl -f 2- $symtab \| \
  sed 's/_[BEIS] / /g' '>' $dir/scoring/LMWT.tra || exit 1;

for LMWT in `seq $min_lmwt $max_lmwt`; do
  cat $dir/scoring/$LMWT.tra | $filtering_cmd > $dir/scoring/$LMWT.filt || exit 1;
done

$cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/score.LMWT.log \
   cat $dir/scoring/LMWT.filt \| \
   compute-wer --text --mode=present \
   ark:$dir/scoring/test_filt.txt ark,p:- ">&" $dir/wer_LMWT || exit 1;
   #ark:$dir/scoring/test_filt.txt ark,p:- $dir/scoring/stats_LMWT ">&" $dir/wer_LMWT || exit 1;

grep WER $dir/wer_* | utils/best_wer.sh || exit 1;

exit 0;

