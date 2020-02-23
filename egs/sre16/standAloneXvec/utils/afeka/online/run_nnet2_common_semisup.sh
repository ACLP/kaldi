#!/bin/bash

# Make the features, build the iVector extractor
# need only to create: 
# 1. features for sup + ivectors in sup-dir
# 2. features for unsup + ivectors in unsusup-dir

[ -f ./path.sh ] && . ./path.sh

[ ! -f ./conf/main.conf ] && echo "File configuration does not exist!" && exit 1
. ./conf/main.conf || exit 1;

# begin configuration section.
cmd=run.pl
stage=1
#end configuration section.

. parse_options.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $0 <sup-dataset> <unsup-dataset> <nnet-dir> <sup-ivector-extractor-dir>"
  echo "e.g.: $0 gale lev exp/nnet2_online exp/nnet2_online/extractor"
  exit 1;
fi

sup_dataset=$1
unsup_dataset=$2
nnet_dir=$3
sup_ivector_extractor_dir=$4

exp_dir=`dirname $nnet_dir`

if [ $stage -le 1 ]; then
  # this shows how you can split across multiple file-systems.  we'll split the
  # MFCC dir across multiple locations.  You might want to be careful here, if you
  # have multiple copies of Kaldi checked out and run the same recipe, not to let
  # them overwrite each other.
 
  echo "<<< Preparing supervised data: $sup_dataset >>>"
  utils/copy_data_dir.sh data/$sup_dataset data/${sup_dataset}_hires
  
  echo "<<< Feature extraction for supervised data: $sup_dataset >>>"
  mfccdir=mfcc_hires
  
  steps/make_mfcc.sh --cmd "$train_cmd" --nj "$train_nj" --mfcc-config conf/mfcc_hires.conf \
    data/${sup_dataset}_hires $exp_dir/make_hires/$sup_dataset $mfccdir || exit 1;
  steps/compute_cmvn_stats.sh data/${sup_dataset}_hires $exp_dir/make_hires/$sup_dataset $mfccdir || exit 1;
  utils/fix_data_dir.sh data/${sup_dataset}_hires || exit 1;
fi

if [ $stage -le 2 ]; then
  # this shows how you can split across multiple file-systems.  we'll split the
  # MFCC dir across multiple locations.  You might want to be careful here, if you
  # have multiple copies of Kaldi checked out and run the same recipe, not to let
  # them overwrite each other.
 
  echo "<<< Preparing unsupervised data: $unsup_dataset >>>"
  utils/copy_data_dir.sh data/$unsup_dataset data/${unsup_dataset}_hires
  
  echo "<<< Feature extraction for unsupervised data: $unsup_dataset >>>"
  mfccdir=mfcc_hires
  
  steps/make_mfcc.sh --cmd "$train_cmd" --nj "$train_nj" --mfcc-config conf/mfcc_hires.conf \
    data/${unsup_dataset}_hires $exp_dir/make_hires/$unsup_dataset $mfccdir || exit 1;
  steps/compute_cmvn_stats.sh data/${unsup_dataset}_hires $exp_dir/make_hires/$unsup_dataset $mfccdir || exit 1;
  utils/fix_data_dir.sh data/${unsup_dataset}_hires || exit 1;
fi

if [ $stage -le 3 ]; then
  # iVector extractors can in general be sensitive to the amount of data, but
  # this one has a fairly small dim (defaults to 100) so we don't use all of it,
  # we use just the 100k subset (about one sixteenth of the data).

  echo "<<< Using previously trained ivector extractor dir from: $sup_ivector_extractor_dir >>>"
  echo "<<< Extracting ivectors for semisup >>>"

  ivectordir_unsup=$nnet_dir/ivectors_$unsup_dataset
  
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "$train_nj" \
   data/${unsup_dataset}_hires $sup_ivector_extractor_dir $ivectordir_unsup || exit 1;
fi

exit 0;
