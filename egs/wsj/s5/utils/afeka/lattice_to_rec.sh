#!/bin/bash

# This script produces outputs files from a decoding directory that has lattices
# present.

# Begin configuration section
nbest=1
lmwt=1
# end configuration sections

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) <data-dir> <lang-dir|graph-dir> <model-dir> <decoder-dir>"
  echo "e.g.: $(basename $0) data/dev/text data/lang_test exp/tri3/decode_dev"
  echo "Options:"
  echo "--nbest <int>   # number of distinct paths"
  echo "--lmwt <int>    # LM-weight for lattice rescoring"
  exit 1;
fi

data_dir=$1
lang_or_graph=$2
model_dir=$3
decode_dir=$4

# end configuration sections

frame_shift_opt= # e.g. for 'chain' systems
factor= # e.g. for 'chain' systems
if [ -f $model_dir/frame_subsampling_factor ]; then
  factor=$(cat $model_dir/frame_subsampling_factor) || exit 1;
  frame_shift_opt="--frame-shift=0.0$factor"
fi

if [ -f $data_dir/segments ]; then
  f=$data_dir/reco2file_and_channel
  [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
  filter_cmd="utils/convert_ctm.pl $data_dir/segments $data_dir/reco2file_and_channel"
else
  filter_cmd=cat
fi

symtab=$lang_or_graph/words.txt

acwt=`perl -e "print (1.0/$lmwt);"`

lattice-mbr-decode --acoustic-scale=$acwt --word-symbol-table=$symtab \
  "ark:gunzip -c $decode_dir/lat.*.gz|" ark,t: | \
  utils/int2sym.pl -f 2- $symtab > $decode_dir/lmwt_$lmwt.tra

lattice-scale --inv-acoustic-scale=$lmwt "ark:gunzip -c $decode_dir/lat.*.gz|" ark:- | \
  lattice-align-words $lang_or_graph/phones/word_boundary.int $model_dir/final.mdl ark:- ark:- | \
  lattice-to-ctm-conf $frame_shift_opt --decode-mbr=true ark:- - | \
  utils/int2sym.pl -f 5 $lang_or_graph/words.txt | $filter_cmd > $decode_dir/lmwt_$lmwt.ctm

lattice-to-nbest --acoustic-scale=$acwt --n=$nbest "ark:gunzip -c $decode_dir/lat.*.gz|" ark:- | \
 nbest-to-linear ark:- ark,t:$decode_dir/nbest.ali ark,t:- | \
 utils/int2sym.pl -f 2- $lang_or_graph/words.txt > $decode_dir/lmwt_$lmwt.${nbest}_nbest
 
rm $decode_dir/nbest.ali

exit 0;
