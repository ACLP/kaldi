#!/bin/bash

# Script for minimum bayes risk decoding.

[ -f ./path.sh ] && . ./path.sh;

# begin configuration section.
cmd=run.pl
min_lmwt=5
max_lmwt=25
#end configuration section.

[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $(basename $0) [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --min_lmwt <int>                # minumum LM-weight for lattice rescoring_mbr_mbr "
  echo "    --max_lmwt <int>                # maximum LM-weight for lattice rescoring_mbr_mbr "
  exit 1;
fi

data=$1
lang_or_graph=$2
dir=$3

symtab=$lang_or_graph/words.txt

for f in $symtab $dir/lat.1.gz $data/text; do
  [ ! -f $f ] && echo "score_mbr.sh: no such file $f" && exit 1;
done

mkdir -p $dir/scoring_mbr_mbr_mbr/log

function filter_text {
  perl -e 'foreach $w (@ARGV) { $bad{$w} = 1; } 
   while(<STDIN>) { @A  = split(" ", $_); $id = shift @A; print "$id ";
     foreach $a (@A) { if (!defined $bad{$a}) { print "$a "; }} print "\n"; }' \
   'SIL' '<silence>' '<v-noise>' '<noise>'
}

word_transform_file=data/local/data/lexicon/mapping.txt
echo "NOTICE! WORD TRANSFOR FILE IS: $word_transform_file"

# Map reference:
cp $data/text $dir/scoring_mbr_mbr/test
filter_text < $dir/scoring_mbr_mbr/test > $dir/scoring_mbr_mbr/test_filt.txt

utils/afeka/apply_word_mapping.pl -f 2- $word_transform_file < $dir/scoring_mbr/test_filt.txt > $dir/scoring_mbr/tmp && mv $dir/scoring_mbr/tmp $dir/scoring_mbr/test_filt_hes.txt || exit 1;

# We submit the jobs separately, not as an array, because it's hard
# to get the inverse of the LM scales.
rm $dir/.error 2>/dev/null
for inv_acwt in `seq $min_lmwt $max_lmwt`; do
  acwt=`perl -e "print (1.0/$inv_acwt);"`
  $cmd $dir/scoring_mbr_mbr/rescore_mbr.${inv_acwt}.log \
    lattice-mbr-decode  --acoustic-scale=$acwt --word-symbol-table=$symtab \
      "ark:gunzip -c $dir/lat.*.gz|" ark,t:$dir/scoring_mbr_mbr/${inv_acwt}.tra \
    || touch $dir/.error &
done
wait;

[ -f $dir/.error ] && echo "score_mbr.sh: errror getting MBR outout.";

$cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_mbr_mbr/log/score.LMWT.log \
   cat $dir/scoring_mbr_mbr/LMWT.tra \| \
    utils/int2sym.pl -f 2- $symtab \| sed 's:\<UNK\>::g' \| \
    compute-wer --text --mode=present \
     ark:$dir/scoring_mbr_mbr/test_filt.txt  ark,p:- ">" $dir/wer_LMWT || exit 1;

for LMWT in `seq $min_lmwt $max_lmwt`; do
  filter_text < $dir/scoring_mbr/$LMWT.tra > $dir/scoring_mbr/$LMWT.filt || exit 1;
  utils/afeka/apply_word_mapping.pl -f 2- $word_transform_file < $dir/scoring_mbr/$LMWT.filt > $dir/scoring_mbr/$LMWT.map || exit 1; 
done

$cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_mbr/log/score.LMWT.log \
   cat $dir/scoring_mbr/LMWT.map \| \
   compute-wer --text --mode=present \
   ark:$dir/scoring_mbr/test_filt_hes.txt ark,p:- $dir/scoring_mbr/stats_LMWT ">&" $dir/wer_LMWT || exit 1;
   
exit 0;
