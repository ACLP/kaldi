#!/bin/bash
# Copyright      2012  Brno University of Technology (Author: Karel Vesely)
#           2013-2014  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# Modified by Ella Erlich based online\nnet2\align.sh

# Computes training alignments using nnet3 DNN.

# Begin configuration section.  
nj=4
cmd=run.pl
# Begin configuration.
scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"

beam=10
retry_beam=40
iter=final
use_gpu=no
frames_per_chunk=50
extra_left_context=0
extra_right_context=0
extra_left_context_initial=-1
extra_right_context_final=-1
online_ivector_dir=
write_per_frame_acoustic_loglikes=""
# End configuration options.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 4 ]; then
   echo "Usage: $0 <data-dir> <lang-dir> <src-dir> <align-dir>"
   echo "e.g.: $0 data/train data/lang exp/nnet4 exp/nnet4_ali"
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --write-per-frame-acoustic-loglikes : Wspecifier for table of vectors containing the acoustic log-likelihoods per frame for each utterance. E.g. ark:foo/per_frame_logprobs.1.ark (string, default = "")"
   exit 1;
fi

data=$1
lang=$2
srcdir=$3
dir=$4

oov=`cat $lang/oov.int` || exit 1;
mkdir -p $dir/log
echo $nj > $dir/num_jobs
sdata=$data/split${nj}utt #!!!
[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh --per-utt $data $nj || exit 1; #!!!

for f in $srcdir/tree $srcdir/${iter}.mdl $data/wav.scp $lang/L.fst $srcdir/conf/online.conf; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

utils/lang/check_phones_compatible.sh $lang/phones.txt $srcdir/phones.txt || exit 1;
cp $lang/phones.txt $dir || exit 1;
cp $srcdir/{tree,${iter}.mdl} $dir || exit 1;

grep -v '^--endpoint' $srcdir/conf/online.conf >$dir/feature.conf || exit 1;

if [ -f $data/segments ]; then
  # note: in the feature extraction, because the program online2-wav-dump-features is sensitive to the
  # previous utterances within a speaker, we do the filtering after extracting the features.
  echo "$0 [info]: segments file exists: using that."
  feats="ark,s,cs:extract-segments scp:$sdata/JOB/wav.scp $sdata/JOB/segments ark:- | online2-wav-dump-features --config=$dir/feature.conf ark:$sdata/JOB/spk2utt ark,s,cs:- ark:- |"
  else
  echo "$0 [info]: no segments file exists, using wav.scp."
  feats="ark,s,cs:online2-wav-dump-features --config=$dir/feature.conf ark:$sdata/JOB/spk2utt scp:$sdata/JOB/wav.scp ark:- |"
fi

echo "$0: aligning data in $data using model from $srcdir, putting alignments in $dir"

tra="ark:utils/sym2int.pl --map-oov $oov -f 2- $lang/words.txt $sdata/JOB/text|";

frame_subsampling_opt=
if [ -f $srcdir/frame_subsampling_factor ]; then
  # e.g. for 'chain' systems
  frame_subsampling_factor=$(cat $srcdir/frame_subsampling_factor)
  frame_subsampling_opt="--frame-subsampling-factor=$frame_subsampling_factor"
  cp $srcdir/frame_subsampling_factor $dir
  if [ "$frame_subsampling_factor" -gt 1 ] && \
     [ "$scale_opts" == "--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1" ]; then
    echo "$0: frame-subsampling-factor is not 1 (so likely a chain system),"
    echo "...  but the scale opts are the defaults.  You probably want"
    echo "--scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0'"
    sleep 1
  fi
fi

$cmd JOB=1:$nj $dir/log/align.JOB.log \
  compile-train-graphs --read-disambig-syms=$lang/phones/disambig.int $dir/tree $srcdir/${iter}.mdl  $lang/L.fst "$tra" ark:- \| \
  nnet3-align-compiled $scale_opts --use-gpu=$use_gpu --beam=$beam --retry-beam=$retry_beam $frame_subsampling_opt \
  --frames-per-chunk=$frames_per_chunk \
  --extra-left-context=$extra_left_context \
  --extra-right-context=$extra_right_context \
  --extra-left-context-initial=$extra_left_context_initial \
  --extra-right-context-final=$extra_right_context_final \
  --write-per-frame-acoustic-loglikes=$write_per_frame_acoustic_loglikes \
  $srcdir/${iter}.mdl ark:- "$feats" "ark:|gzip -c >$dir/ali.JOB.gz" || exit 1;

echo "$0: done aligning data."

