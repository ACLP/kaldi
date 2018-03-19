#!/bin/bash
# Author: Ella Erlich

# begin configuration section.
ExeCmd=
cmd=run.pl
max_jobs_run=1
#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 7 ]; then
   echo "Usage: $(basename $0) [options] <phn-decoder-dir> <fixed-lat-dir> <kws-dict> <kws-threshold> <weights> <reco2file_and_channel> <kws-results>"
   echo "e.g.: $(basename $0) exp/tri3/decode_phn_dev/lm_6 exp/tri3/decode_phn_dev/lattices_phn_lm_6_beam_3_ali_fixed kws.dict kws_TH.txt weights.csv data/dev/reco2file_and_channel exp/tri3/decode_phn_dev/lm_6/KWS_Results"
   echo "Options:"
   echo "--cmd (run.pl|queue.pl...)  # specify how to run the sub-processes."
   echo "--max-jobs-run              # max jobs"
   echo "--ExeCmd                    # ExeCmd mono for linux (string,  default = "")"
   exit 1;
fi

Phn_decoder_dir=$1
Fixed_Phn_LatDir=$2
KWSDict=$3
KW_TH_List=$4
Weights=$5
Rec2File=$6
KWSResDir=$7

nj=$max_jobs_run

ls -d -1 $Fixed_Phn_LatDir/*.lat > ${Fixed_Phn_LatDir}.lis

set +e
split --numeric-suffixes -n l/$nj ${Fixed_Phn_LatDir}.lis ${Fixed_Phn_LatDir}.lis.split 2> /dev/null
ret=$?
set -e
if [ $ret != 0 ]; then
  F=($(wc ${Fixed_Phn_LatDir}.lis))
  N=$((($F / $nj)+1))
  split --numeric-suffixes -l $N ${Fixed_Phn_LatDir}.lis ${Fixed_Phn_LatDir}.lis.split
fi

for i in `seq $(($nj-1)) -1 0`; do
  if [[ $i -lt 10 ]]; then
    mv ${Fixed_Phn_LatDir}.lis.split0$i ${Fixed_Phn_LatDir}.lis.split$(($i+1))
  else
    mv ${Fixed_Phn_LatDir}.lis.split$i ${Fixed_Phn_LatDir}.lis.split$(($i+1))
  fi
done

$cmd JOB=1:$nj $Phn_decoder_dir/log/KeyWordSpotting.JOB.log \
  $ExeCmd utils/phonetic_search/Run.KeyWordSpotting.exe $KWSDict $KW_TH_List ${Fixed_Phn_LatDir}.lis.splitJOB $Rec2File $Weights $KWSResDir.JOB || exit 1;

rm -rf $KWSResDir; mkdir -p $KWSResDir

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
for i in `seq 1 $nj`
do
  echo "processing $KWSResDir.$i"
  FILES=`ls $KWSResDir.$i/`
  for f in $FILES
    do
      file="$(basename "$f")"
      cat "$KWSResDir.$i/$f" >> $KWSResDir/"$file"
    done
  rm -rf $KWSResDir.$i
  rm -rf ${Fixed_Phn_LatDir}.lis.split.0$i
done

IFS=$SAVEIFS
exit 0;
