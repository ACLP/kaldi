#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.
model= # You canecify the model to use
cmd=run.pl
acwt=1.0
lmwt=1.0

run_word=true
run_phn=true
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 4 ]; then
   echo "Usage: $(basename $0) [options] <data-dir> <lang-dir> <decode-dir> <out-dir>"
   echo "... where <decode-dir> is where you have the lattices, and is assumed to be"
   echo " a sub-directory of the directory where the model is."
   echo "e.g.: $(basename $0) --lmwt 7 data/dev data/lang_test exp/tri3/decode_dev exp/tri3/decode_dev/lm_7"
   echo "Options:"
   echo "--cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "--acwt <float>                                   # acoustic scale used for lattice (default 1.0)"
   echo "--lmwt <float>                                   # lm scale used for lattice (default 1.0)"
   echo "--model <model>                                  # which model to use"
   echo "--run-phn <bool>                                 # create phoneme ctm (default true)"
   exit 1;
fi

datadir=$1;
langdir=$2;
decodedir=$3;
outdir=$4;

srcdir=`dirname $decodedir`; # The model directory is one level up from decoding directory.

mkdir -p $outdir/log;
mkdir -p $outdir;

nj=`cat $decodedir/num_jobs` || exit 1;

if [ -z "$model" ]; then # if --model <mdl> was notecified on the command line...
  model=$srcdir/final.mdl; 
fi

for f in $langdir/phones/word_boundary.int $langdir/words.txt $langdir/phones.txt $model $decodedir/lat.1.gz; do
  [ ! -f $f ] && echo "Word_lattice2Best_path.sh: no such file $f" && exit 1;
done

echo "Using model: $model"

if [ -f $srcdir/frame_shift ]; then
  frame_shift_opt="--frame-shift=$(cat $srcdir/frame_shift)"
  echo "$srcdir/frame_shift exists, using $frame_shift_opt"
elif [ -f $srcdir/frame_subsampling_factor ]; then
  factor=$(cat $srcdir/frame_subsampling_factor) || exit 1
  frame_shift_opt="--frame-shift=0.0$factor"
  echo "$srcdir/frame_subsampling_factor exists, using $frame_shift_opt"
fi

function if_n_e () {
        read line || return 1
        (echo "$line"; cat) | eval "$@"
}
export -f if_n_e

# Get the word sequence on the best-path:
if $run_word ; then
  if [ -f $datadir/segments ]; then
    # echo "Using segments data..."
    # $cmd JOB=1:$nj $outdir/log/get_lattice_best_path.JOB.log \
      # lattice-best-path --lm-scale=$lmwt --word-symbol-table=$langdir/words.txt \
      # "ark:gunzip -c $decodedir/lat.JOB.gz|" ark,t: \| \
      # utils/int2sym.pl -f 2- $langdir/words.txt \| \
      # utils/afeka/convert_tra.pl $datadir/segments $datadir/reco2file_and_channel '>' $outdir/LVCSR.JOB.tra || exit 1;

    $cmd JOB=1:$nj $outdir/log/get_rescore_mbr.JOB.log \
      lattice-mbr-decode --acoustic-scale=\`perl -e \"print 1.0/$lmwt\"\` --word-symbol-table=$langdir/words.txt \
      "ark:gunzip -c $decodedir/lat.JOB.gz|" ark,t: \| \
      utils/int2sym.pl -f 2- $langdir/words.txt \| \
      utils/afeka/convert_tra.pl $datadir/segments $datadir/reco2file_and_channel '>' $outdir/LVCSR.JOB.tra || exit 1;

    find $outdir/LVCSR.*.tra | xargs cat > $outdir/LVCSR.tra

    $cmd JOB=1:$nj $outdir/log/get_word_segments_ctm.JOB.log \
      lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decodedir/lat.JOB.gz|" ark:- \| \
      lattice-align-words $langdir/phones/word_boundary.int $model ark:- ark:- \| \
      lattice-to-ctm-conf $frame_shift_opt --decode-mbr=true ark:- - \| \
      utils/int2sym.pl -f 5 $langdir/words.txt \| tee $outdir/utt.JOB.ctm \| \
      if_n_e utils/convert_ctm.pl $datadir/segments $datadir/reco2file_and_channel '>' $outdir/words.JOB.ctm || exit 1;
  else
    # $cmd JOB=1:$nj $outdir/log/get_lattice_best_path.JOB.log \
      # lattice-best-path --lm-scale=$lmwt --word-symbol-table=$langdir/words.txt \
      # "ark:gunzip -c $decodedir/lat.JOB.gz|" ark,t: \| \
      # utils/int2sym.pl -f 2- $langdir/words.txt \| \
      # utils/afeka/convert_tra_no_segments.pl $datadir/reco2file_and_channel '>' $outdir/LVCSR.JOB.tra || exit 1;

    $cmd JOB=1:$nj $outdir/log/get_rescore_mbr.JOB.log \
      lattice-mbr-decode --acoustic-scale=\`perl -e \"print 1.0/$lmwt\"\` --word-symbol-table=$langdir/words.txt \
      "ark:gunzip -c $decodedir/lat.JOB.gz|" ark,t: \| \
      utils/int2sym.pl -f 2- $langdir/words.txt '>' $outdir/scoring/LVCSR.JOB.tra || exit 1;

    find $outdir/LVCSR.*.tra | xargs cat > $outdir/LVCSR.tra

    $cmd JOB=1:$nj $outdir/log/get_word_segments_ctm.JOB.log \
      lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decodedir/lat.JOB.gz|" ark:- \| \
      lattice-align-words $langdir/phones/word_boundary.int $model ark:- ark:- \| \
      lattice-to-ctm-conf $frame_shift_opt --decode-mbr=true ark:- - \| \
      utils/int2sym.pl -f 5 $langdir/words.txt '>' $outdir/words.JOB.ctm || exit 1;
  fi

  find $outdir/words.*.ctm | xargs cat > $outdir/words.temp.ctm
  gawk -f utils/afeka/sort_ctm.awk -v ctm=$outdir/words.temp.ctm $datadir/reco2file_and_channel > $outdir/words.ctm
fi

# Get the phonemes sequence on the best-path:
if $run_phn ; then
  $cmd JOB=1:$nj $outdir/log/get_phn_segments_ctm.JOB.log \
    lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decodedir/lat.JOB.gz|" ark:- \| \
    lattice-align-words $langdir/phones/word_boundary.int $model ark:- ark:- \| \
    lattice-to-phone-lattice $model ark:- ark:- \| \
    lattice-align-phones $model ark:- ark:- \| \
    lattice-to-ctm-conf $frame_shift_opt --decode-mbr=false ark:- - \| \
    int2sym.pl -f 5 $langdir/phones.txt '>' $outdir/phn.JOB.ctm || exit 1;
  
  find $outdir/phn.*.ctm | xargs cat > $outdir/phn.ctm
  if [ -f $datadir/segments ]; then
    utils/afeka/convert_phn_ctm.pl $datadir/segments $datadir/reco2file_and_channel $outdir/phn.ctm | gawk '{sub(/_[BEIS]$/,"",$5);print}'  > $outdir/phn_final.ctm
  else
    gawk '{sub(/_[BEIS]$/,"",$5);print}' < $outdir/phn.ctm > $outdir/phn_final.ctm
  fi
fi

i=1
while [ $i -le $nj ]
do
  rm $outdir/LVCSR.$i.tra
  rm $outdir/phn.$i.ctm
  rm $outdir/words.$i.ctm
  if [ -f $datadir/segments ]; then
    rm $outdir/utt.$i.ctm
  fi
  i=$(($i+1))
done
rm $outdir/words.temp.ctm
rm $outdir/phn.ctm
exit 0;