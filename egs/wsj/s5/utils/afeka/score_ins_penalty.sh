#!/bin/bash
# Copyright 2012-2014 Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# Modified by Ella Erlich

# begin configuration section.
cmd=run.pl
word_ins_penalty=0.0,0.5,1.0
min_lmwt=5
max_lmwt=25
ref_text=
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
  echo "--ref-text                      # option fo ref text data (default $data_dir/text)"
  echo "--min-lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "--max-lmwt <int>                # maximum LM-weight for lattice rescoring "
  echo "--stats <bool>                  # output wer_details "
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

mkdir -p $decode_dir/scoring_ins_penalty/log

filtering_cmd="cat"
[ -x local/wer_filter ] && filtering_cmd="local/wer_filter"

cp $ref_text $decode_dir/scoring_ins_penalty/ref_text
cat $decode_dir/scoring_ins_penalty/ref_text | $filtering_cmd > $decode_dir/scoring_ins_penalty/ref_text.filt || exit 1;

filtering_cmd="cat"
[ -x local/wer_filter ] && filtering_cmd="local/wer_filter"

# Get the sequence on the best-path:
for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  $cmd INV_ACWT=$min_lmwt:$max_lmwt $decode_dir/scoring_ins_penalty/$wip/log//rescore_mbr.INV_ACWT.log \
    lattice-add-penalty --word-ins-penalty=$wip "ark:gunzip -c $decode_dir/lat.*.gz|" ark:- \| \
    lattice-mbr-decode --acoustic-scale=\`perl -e \"print 1.0/INV_ACWT\"\` --word-symbol-table=$symtab ark:- ark,t:- \| \
    utils/int2sym.pl -f 2- $symtab '>' $decode_dir/scoring_ins_penalty/$wip/INV_ACWT.tra

  for LMWT in `seq $min_lmwt $max_lmwt`; do
    cat $decode_dir/scoring_ins_penalty/$wip/$LMWT.tra | $filtering_cmd > $decode_dir/scoring_ins_penalty/$wip/$LMWT.filt || exit 1;
  done

  $cmd LMWT=$min_lmwt:$max_lmwt $decode_dir/scoring_ins_penalty/$wip/log/score.LMWT.log \
     cat $decode_dir/scoring_ins_penalty/$wip/LMWT.filt \| \
     compute-wer --text --mode=present \
     ark:$decode_dir/scoring_ins_penalty/ref_text.filt ark,p:- ">&" $decode_dir/wer_LMWT_$wip || exit 1;
     #ark:$decode_dir/scoring_ins_penalty/ref_text.filt ark,p:- $decode_dir/scoring_ins_penalty/stats_LMWT ">&" $decode_dir/wer_LMWT || exit 1;
done

for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  for lmwt in $(seq $min_lmwt $max_lmwt); do
    grep WER $decode_dir/wer_${lmwt}_${wip} /dev/null
  done
done | utils/best_wer.sh >& $decode_dir/scoring_ins_penalty/best_wer || exit 1;

cat $decode_dir/scoring_ins_penalty/best_wer
best_wer_file=$(awk '{print $NF}' $decode_dir/scoring_ins_penalty/best_wer)
best_wip=$(echo $best_wer_file | awk -F_ '{print $NF}')
best_lmwt=$(echo $best_wer_file | awk -F_ '{N=NF-1; print $N}')

if [ -z "$best_lmwt" ]; then
  echo "$0: we could not get the details of the best WER from the file $decode_dir/wer_*.  Probably something went wrong."
  exit 1;
fi

if $stats; then
  mkdir -p $decode_dir/scoring_ins_penalty/wer_details
  echo $best_lmwt > $decode_dir/scoring_ins_penalty/wer_details/lmwt # record best language model weight
  echo $best_wip > $decode_dir/scoring_ins_penalty/wer_details/wip # record best word insertion penalty

  $cmd $decode_dir/scoring_ins_penalty/log/stats1.log \
    cat $decode_dir/scoring_ins_penalty/$best_wip/$best_lmwt.filt \| \
      align-text --special-symbol="'***'" ark:$decode_dir/scoring_ins_penalty/ref_text.filt ark:- ark,t:- \|  \
      utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" \| tee $decode_dir/scoring_ins_penalty/wer_details/per_utt \|\
      utils/scoring/wer_per_spk_details.pl $data/utt2spk \> $decode_dir/scoring_ins_penalty/wer_details/per_spk || exit 1;

  $cmd $decode_dir/scoring_ins_penalty/log/stats2.log \
    cat $decode_dir/scoring_ins_penalty/wer_details/per_utt \| \
      utils/scoring/wer_ops_details.pl --special-symbol "'***'" \| \
      sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 \> $decode_dir/scoring_ins_penalty/wer_details/ops || exit 1;

  $cmd $decode_dir/scoring_ins_penalty/log/wer_bootci.log \
    compute-wer-bootci --mode=present \
      ark:$decode_dir/scoring_ins_penalty/ref_text.filt ark:$decode_dir/scoring_ins_penalty/$best_wip/$best_lmwt.filt \
      '>' $decode_dir/scoring_ins_penalty/wer_details/wer_bootci || exit 1;
fi

exit 0;

