#!/bin/bash
# Modified by Ella Erlich

# Copyright 2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# This script takes data prepared in a corpus-dependent way
# in data/local/, and converts it into the "canonical" form,
# in various subdirectories of data/, e.g. data/lang, data/train, etc.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 1 ]; then
  echo "Usage: $(basename $0) <data-list>"
  echo "e.g.: $(basename $0) \"train dev eval\""
  exit 1;
fi

datalist=$1

echo "Preparing data for: $datalist"
srcdir=data/local/data

for x in $datalist; do 
  mkdir -p data/$x
  cp $srcdir/${x}/wav.scp data/$x/wav.scp || exit 1;
  cp $srcdir/$x/spk2utt data/$x/spk2utt || exit 1;
  cp $srcdir/$x/utt2spk data/$x/utt2spk || exit 1;

  if [ -f $srcdir/$x/text ]; then
    cp $srcdir/$x/text data/$x/text || exit 1;
  fi

  if [ -f $srcdir/$x/reco2file_and_channel ]; then
    cp $srcdir/$x/reco2file_and_channel data/$x/reco2file_and_channel || exit 1;
  fi

  if [ -f $srcdir/$x/segments ]; then
    cp $srcdir/$x/segments data/$x/segments || exit 1;
  fi

  if [ -f $srcdir/$x/spk2gender ]; then
    utils/filter_scp.pl data/$x/spk2utt $srcdir/$x/spk2gender > data/$x/spk2gender || exit 1;
  fi

  if [ -f $srcdir/$x/text ]; then
    utils/validate_data_dir.sh --no-feats data/$x || exit 1;
  else
    utils/validate_data_dir.sh --no-feats --no-text data/$x || exit 1;
  fi

  wav-to-duration scp:$srcdir/${x}/wav.scp ark,t:$srcdir/${x}/dur.ark
done

echo ""
echo "Succeeded in formatting data."
echo ""

exit 0;

