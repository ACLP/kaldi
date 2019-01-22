#!/bin/bash
# Copyright 2012-2014 Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# Modified by Ella Erlich

# begin configuration section.
cmd=run.pl
word_ins_penalty=0.0,0.5,1.0
min_lmwt=7
max_lmwt=17
stats=false
iter=final

#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $(basename $0) [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo "e.g.: $(basename $0) data/dev data/lang_test exp/tri3/decode_dev"
  echo "Options:"
  echo "main options (for others, see top of script file)"
  echo "--cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "--min-lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "--max-lmwt <int>                # maximum LM-weight for lattice rescoring "
  echo "--stats <bool>                  # output wer_details "
  exit 1;
fi

data=$1
lang_or_graph=$2
dir=$3

symtab=$lang_or_graph/words.txt

for f in $symtab $dir/lat.1.gz $data/text; do
  [ ! -f $f ] && echo "score.sh: no such file $f" && exit 1;
done

mkdir -p $dir/scoring_ins_penalty/log

filtering_cmd="cat"
[ -x local/wer_filter ] && filtering_cmd="local/wer_filter"

cp $data/text $dir/scoring_ins_penalty/test
cat $dir/scoring_ins_penalty/test | $filtering_cmd > $dir/scoring_ins_penalty/test_filt.txt || exit 1;

for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  # Get the sequence on the best-path:
  $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_ins_penalty/$wip/log/best_path.LMWT.log \
    lattice-scale --inv-acoustic-scale=LMWT "ark:gunzip -c $dir/lat.*.gz|" ark:- \| \
    lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
    lattice-best-path --word-symbol-table=$symtab ark:- ark,t:- \| \
    utils/int2sym.pl -f 2- $symtab '>' $dir/scoring_ins_penalty/$wip/LMWT.tra || exit 1;

  for LMWT in `seq $min_lmwt $max_lmwt`; do
    cat $dir/scoring_ins_penalty/$wip/$LMWT.tra | $filtering_cmd > $dir/scoring_ins_penalty/$wip/$LMWT.filt || exit 1;
  done

  $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_ins_penalty/$wip/log/score.LMWT.log \
     cat $dir/scoring_ins_penalty/$wip/LMWT.filt \| \
     compute-wer --text --mode=present \
     ark:$dir/scoring_ins_penalty/test_filt.txt ark,p:- ">&" $dir/wer_LMWT_$wip || exit 1;
     #ark:$dir/scoring_ins_penalty/test_filt.txt ark,p:- $dir/scoring_ins_penalty/stats_LMWT ">&" $dir/wer_LMWT || exit 1;
done

for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  for lmwt in $(seq $min_lmwt $max_lmwt); do
    grep WER $dir/wer_${lmwt}_${wip} /dev/null
  done
done | utils/best_wer.sh  >& $dir/scoring_ins_penalty/best_wer || exit 1;

best_wer_file=$(awk '{print $NF}' $dir/scoring_ins_penalty/best_wer)
cat $best_wer_file
best_wip=$(echo $best_wer_file | awk -F_ '{print $NF}')
best_lmwt=$(echo $best_wer_file | awk -F_ '{N=NF-1; print $N}')

if [ -z "$best_lmwt" ]; then
  echo "$0: we could not get the details of the best WER from the file $dir/wer_*.  Probably something went wrong."
  exit 1;
fi

if $stats; then
  mkdir -p $dir/scoring_ins_penalty/wer_details
  echo $best_lmwt > $dir/scoring_ins_penalty/wer_details/lmwt # record best language model weight
  echo $best_wip > $dir/scoring_ins_penalty/wer_details/wip # record best word insertion penalty

  $cmd $dir/scoring_ins_penalty/log/stats1.log \
    cat $dir/scoring_ins_penalty/$best_wip/$best_lmwt.filt \| \
      align-text --special-symbol="'***'" ark:$dir/scoring_ins_penalty/test_filt.txt ark:- ark,t:- \|  \
      utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" \| tee $dir/scoring_ins_penalty/wer_details/per_utt \|\
      utils/scoring/wer_per_spk_details.pl $data/utt2spk \> $dir/scoring_ins_penalty/wer_details/per_spk || exit 1;

  $cmd $dir/scoring_ins_penalty/log/stats2.log \
    cat $dir/scoring_ins_penalty/wer_details/per_utt \| \
      utils/scoring/wer_ops_details.pl --special-symbol "'***'" \| \
      sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 \> $dir/scoring_ins_penalty/wer_details/ops || exit 1;

  $cmd $dir/scoring_ins_penalty/log/wer_bootci.log \
    compute-wer-bootci --mode=present \
      ark:$dir/scoring_ins_penalty/test_filt.txt ark:$dir/scoring_ins_penalty/$best_wip/$best_lmwt.filt \
      '>' $dir/scoring_ins_penalty/wer_details/wer_bootci || exit 1;
fi

exit 0;

