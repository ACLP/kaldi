#!/bin/bash
# Author: Ella Erlich

[ -f path.sh ] && . ./path.sh

echo "$0 $@"  # Print the command line for loggi

if [ $# -lt 2 ]; then
   echo "Arguments should be the <out-dir> <data-folder1> <data-folder2> .... "; exit 1
fi

outdir=$1
shift

mkdir -p $outdir

while [ $# -ne 0 ]; do
  data=$1
  echo "merging $data"
  for file in reco2file_and_channel segments spk2gender spk2utt text utt2spk wav.scp; do
    if [ -f $data/$file ]; then
      cat $data/$file >> $outdir/$file
    fi
  done
  shift
done

#fix_data_dir.sh $outdir || exit 1;

echo data creation succeeded.

exit 0