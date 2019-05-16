#!/bin/bash
# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# Modified by Ella Erlich

# begin configuration section.
cmd=run.pl
min_lmwt=5
max_lmwt=25
glm=
language=hebrew
#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) [--cmd (run.pl|queue.pl...)] <data-dir> <graph/lang-dir> <model> <decode-dir>"
  echo "e.g.: $(basename $0) data/dev data/lang_test exp/tri3/final.mdl exp/tri3/decode_dev"
  echo "Options:"
  echo "--cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "--min-lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "--max-lmwt <int>                # maximum LM-weight for lattice rescoring "
  echo "--glm                           # option fo glm data (default $data_dir/glm)"
  exit 1;
fi

data_dir=$1
graph=$2
model=$3
decode_dir=$4

hubscr=$KALDI_ROOT/tools/sctk/bin/hubscr.pl
[ ! -f $hubscr ] && echo "Cannot find scoring program at $hubscr" && exit 1;
hubdir=`dirname $hubscr`

if [ -z $glm ] ; then
  glm=$data_dir/glm
else
  echo "using glm file: $glm"
fi

for f in $glm $graph/words.txt $graph/phones/word_boundary.int \
     $model $data_dir/text $data_dir/wav.scp $data_dir/utt2spk $data_dir/segments $data_dir/reco2file_and_channel $decode_dir/lat.1.gz; do
  [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
done

utils/afeka/prepare_stm.pl ${data_dir} || exit 1;

mkdir -p $decode_dir/scoring_sclite/log
score_dir=$decode_dir/scoring_sclite
cp ${data_dir}/stm $score_dir/ref.stm

$cmd LMWT=$min_lmwt:$max_lmwt $score_dir/log/get_ctm.LMWT.log \
   mkdir -p $score_dir/score_LMWT/ '&&' \
   lattice-1best --lm-scale=LMWT "ark:gunzip -c $decode_dir/lat.*.gz|" ark:- \| \
   lattice-align-words $graph/phones/word_boundary.int $model ark:- ark:- \| \
   nbest-to-ctm ark:- - \| \
   utils/int2sym.pl -f 5 $graph/words.txt  \| \
   utils/convert_ctm.pl $data_dir/segments $data_dir/reco2file_and_channel \
   '>' $score_dir/score_LMWT/rec.ctm || exit 1;

# Score the set...
$cmd LMWT=$min_lmwt:$max_lmwt $score_dir/log/score.LMWT.log \
  cp $data_dir/stm $score_dir/score_LMWT/ '&&' \
  $hubscr -p $hubdir -v -l $language -h hub5 -g $glm -r $score_dir/ref.stm $score_dir/score_LMWT/rec.ctm || exit 1;

grep Sum $score_dir/score_*/*.sys | utils/best_wer.sh || exit 1;

exit 0;
