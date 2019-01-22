#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.  
model= # You can specify the model to use
cmd=run.pl
acwt=1.0
lmwt=1.0
prunebeam=0
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 2 ]; then
   echo "Usage: $(basename $0) [options] <lang-dir> <decode-dir>"
   echo "e.g.: $(basename $0) --lmwt 7 --prunebeam 3 data/lang_test exp/tri3/decode_dev"
   echo "Options:"
   echo "--cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
   echo "--model <model>                 # which model to use"
   echo "--prunebeam                     # puning beam (default = 0, no prunning)"
   echo "--acwt                          # acoustic scale used for lattice (default 1.0)"
   echo "--lmwt                          # lm scale used for lattice (default 1.0)"
   exit 1;
fi

lang_dir=$1
decode_dir=$2

srcdir=`dirname $decode_dir`;
model=$srcdir/final.mdl;

if [ -f $srcdir/frame_shift ]; then
  frame_shift_opt="--frame-rate $(cat $srcdir/frame_shift)"
  echo "$srcdir/frame_shift exists, using $frame_shift_opt"
elif [ -f $srcdir/frame_subsampling_factor ]; then
  factor=$(cat $srcdir/frame_subsampling_factor) || exit 1
  frame_shift_opt="--frame-rate 0.0$factor"
  echo "$srcdir/frame_subsampling_factor exists, using $frame_shift_opt"
fi

nj=`cat $decode_dir/num_jobs` || exit 1;

if [ $prunebeam -eq '0' ]; then
$cmd JOB=1:$nj $decode_dir/log/lattice_align.JOB.log \
  lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decode_dir/lat.JOB.gz|" ark:- \| \
  lattice-to-phone-lattice $model ark:- ark,t:- \| \
  int2sym.pl -f 3 $lang_dir/phones.txt \| \
  utils/convert_slf.pl $frame_shift_opt - $decode_dir/lattices_phn_lm_${lmwt}_ali
  
  gunzip $decode_dir/lattices_phn_lm_${lmwt}_ali/*.gz
else 
$cmd JOB=1:$nj $decode_dir/log/lattice_align_words.JOB.log \
  lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decode_dir/lat.JOB.gz|" ark:- \| \
  lattice-prune --beam=$prunebeam ark:- ark:- \| \
  lattice-to-phone-lattice $model ark:- ark,t:- \| \
  int2sym.pl -f 3 $lang_dir/phones.txt \| \
  utils/convert_slf.pl $frame_shift_opt - $decode_dir/lattices_phn_lm_${lmwt}_beam_${prunebeam}_ali
  
  gunzip $decode_dir/lattices_phn_lm_${lmwt}_beam_${prunebeam}_ali/*.gz
fi

exit 0;
