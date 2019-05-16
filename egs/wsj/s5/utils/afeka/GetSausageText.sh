#!/bin/bash

# Script for getting saussages from lats.

[ -f ./path.sh ] && . ./path.sh;

# begin configuration section.
cmd=run.pl
lmwt=10
JobNum=1

#end configuration section.

[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 2 ]; then
  echo "Usage: local/GetSausage.sh [--cmd (run.pl|queue.pl...)] <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --lmwt <int>                    # LM-weight for sausages generation "
  echo "    --JobNum <int>                    # LM-weight for sausages generation "
  exit 1;
fi

lang_or_graph=$1
dir=$2

symtab=$lang_or_graph/words.txt

for f in $symtab $dir/lat.1.gz; do
  [ ! -f $f ] && echo "GetSausage.sh: no such file $f" && exit 1;
done

acwt=`perl -e "print (1.0/$lmwt);"`
mkdir -p $dir/sausages

echo "acwt=" $acwt
echo "lat=" $dir/lat.$JobNum.gz


lattice-mbr-decode  --acoustic-scale=$acwt --word-symbol-table=$symtab --one-best-times=false \
      "ark:gunzip -c $dir/lat.$JobNum.gz|" ark:/dev/null ark:/dev/null ark,t:$dir/sausages/${lmwt}_${JobNum}.sau

#cat $dir/sausages/${lmwt}_${JobNum}.sau | \
#	  sed -e 's:\[:\n\[:g'   > $dir/sausages/${lmwt}_${JobNum}.sau.decorated

python DecorateSausages.py $lang_or_graph/words.txt $dir/sausages/${lmwt}_${JobNum}.sau $dir/sausages/${lmwt}_${JobNum}.sau.decorated
	  
#mkdir -p $dir/scoring/log

# We submit the jobs separately, not as an array, because it's hard
# to get the inverse of the LM scales.
#rm $dir/.error 2>/dev/null
#for inv_acwt in `seq $min_lmwt $max_lmwt`; do
#  acwt=`perl -e "print (1.0/$inv_acwt);"`
#  $cmd $dir/scoring/rescore_mbr.${inv_acwt}.log \
#    lattice-mbr-decode  --acoustic-scale=$acwt --word-symbol-table=$symtab \
#      "ark:gunzip -c $dir/lat.*.gz|" ark,t:$dir/scoring/${inv_acwt}.tra \
#    || touch $dir/.error &
#done
#wait;
#[ -f $dir/.error ] && echo "GetSausage.sh: errror getting MBR outout.";
