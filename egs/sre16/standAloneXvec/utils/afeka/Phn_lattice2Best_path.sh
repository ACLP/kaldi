#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.
model= # You can specify the model to use
cmd=run.pl
acwt=1.0
lmwt=1.0
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 4 ]; then
   echo "Usage: $(basename $0) [options] <data-dir> <lang-dir> <decode-dir> <out-dir>"
   echo "... where <decode-dir> is where you have the lattices, and is assumed to be"
   echo " a sub-directory of the directory where the model is."
   echo "e.g.: $(basename $0) --lmwt 7 data/dev exp/tri3/phone_graph exp/tri3/decode_phn_dev exp/tri3/decode_phn_dev/lm_7"
   echo "Options:"
   echo "--cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "--acwt <float>                                   # acoustic scale used for lattice (default 1.0)"
   echo "--lmwt <float>                                   # lm scale used for lattice (default 1.0)"
   echo "--model <model>                                  # which model to use"
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

for f in $langdir/phones/word_boundary.int $langdir/words.txt $model $decodedir/lat.1.gz; do
  [ ! -f $f ] && echo "Phn_lattice2Best_path.sh: no such file $f" && exit 1;
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

$cmd JOB=1:$nj $outdir/log/get_ctm_segments.JOB.log \
  lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decodedir/lat.JOB.gz|" ark:- \| \
  lattice-align-phones --replace-output-symbols=true $model ark:- ark:- \| \
  lattice-to-ctm-conf $frame_shift_opt --decode-mbr=false ark:- - \| \
  utils/int2sym.pl -f 5 $langdir/words.txt \| \
  sed 's/_[BEIS] / /g' '>' $outdir/phn.JOB.ctm || exit 1;
  
find $outdir/phn.*.ctm | xargs cat > $outdir/phn.ctm

i=1
while [ $i -le $nj ] 
do
  rm $outdir/phn.$i.ctm
  i=$(($i+1))
done

exit 0;