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

if [ $# != 2 ]; then
   echo "Usage: $(basename $0) [options] <lang-dir> <decode-dir>"
   echo "e.g.: $(basename $0) --lmwt 10 data/lang_test exp/tri3/decode_dev"
   echo "Options:"
   echo "--cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
   echo "--model                         # which model to use"
   echo "--acwt                          # acoustic scale used for lattice (default 1.0)"
   echo "--lmwt                          # lm scale used for lattice (default 1.0)"
   exit 1;
fi

lang_dir=$1
decode_dir=$2

srcdir=`dirname $decode_dir`;
model=$srcdir/final.mdl;

nj=`cat $decode_dir/num_jobs` || exit 1;

mkdir -p $decode_dir/lm_$lmwt

filtering_cmd="cat"
[ -x local/per_filter ] && filtering_cmd="local/per_filter"

if [ -f $srcdir/frame_shift ]; then
  frame_shift_opt="--frame-shift=$(cat $srcdir/frame_shift)"
  echo "$srcdir/frame_shift exists, using $frame_shift_opt"
elif [ -f $srcdir/frame_subsampling_factor ]; then
  factor=$(cat $srcdir/frame_subsampling_factor) || exit 1
  frame_shift_opt="--frame-shift=0.0$factor"
  echo "$srcdir/frame_subsampling_factor exists, using $frame_shift_opt"
fi

$cmd JOB=1:$nj $decode_dir/log/lattice_align.JOB.log \
  lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decode_dir/lat.JOB.gz|" ark:- \| \
  lattice-to-phone-lattice $model ark:- ark:- \| \
  lattice-best-path ark:- ark,t:- \| \
  int2sym.pl -f 2- $lang_dir/phones.txt \| \
  sed 's/_[BEIS] / /g' '>' $decode_dir/lm_$lmwt/phn.JOB.tra || exit 1;
  
find $decode_dir/lm_$lmwt/phn.*.tra | xargs cat > $decode_dir/lm_$lmwt/phn.tra

cat $decode_dir/lm_$lmwt/phn.tra | $filtering_cmd > $decode_dir/lm_$lmwt/phn.tra.filt || exit 1;

$cmd JOB=1:$nj $decode_dir/log/get_ctm_segments.JOB.log \
  lattice-scale --inv-acoustic-scale=$lmwt --acoustic-scale=$acwt "ark:gunzip -c $decode_dir/lat.JOB.gz|" ark:- \| \
  lattice-align-words $lang_dir/phones/word_boundary.int $model ark:- ark:- \| \
  lattice-to-phone-lattice $model ark:- ark:- \| \
  lattice-align-phones $model ark:- ark:- \| \
  lattice-to-ctm-conf $frame_shift_opt --decode-mbr=false ark:- - \| \
  utils/int2sym.pl -f 5 $lang_dir/phones.txt \| \
  sed 's/_[BEIS] / /g' '>' $decode_dir/lm_$lmwt/phn.JOB.ctm || exit 1;

find $decode_dir/lm_$lmwt/phn.*.ctm | xargs cat > $decode_dir/lm_$lmwt/phn.ctm || exit 1;

i=1
while [ $i -le $nj ] 
do
  rm $decode_dir/lm_$lmwt/phn.$i.tra
  rm $decode_dir/lm_$lmwt/phn.$i.ctm
  i=$(($i+1))
done

exit 0;
