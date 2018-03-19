#!/bin/bash
# Modified by Ella Erlich

# Make the features, build the iVector extractor

# begin configuration section.
cmd=run.pl
stage=1
#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $0 <train> <data-lang> <fmllr-dir> <out-nnet-dir>"
  echo "e.g.: $0 train data/lang exp/fmllr exp/nnet2_online"
  echo "For options, see top of script file"
  exit 1;
fi

train=$1
lang_dir=$2
fmllr_dir=$3
nnet_dir=$4

exp_dir=`dirname $fmllr_dir`

if [ $stage -le 1 ]; then
  echo "<<< run_nnet2_common.sh Preparing data >>>"
  # this shows how you can split across multiple file-systems.  we'll split the
  # MFCC dir across multiple locations.  You might want to be careful here, if you
  # have multiple copies of Kaldi checked out and run the same recipe, not to let
  # them overwrite each other.
 
  utils/copy_data_dir.sh data/$train data/${train}_hires
  
  echo "<<< run_nnet2_common.sh  Feature extraction >>>"
  mfccdir=mfcc_hires
  
  steps/make_mfcc.sh --cmd "$train_cmd" --nj "$train_nj" --mfcc-config conf/mfcc_hires.conf \
    data/${train}_hires $exp_dir/make_hires/$train $mfccdir || exit 1;
  steps/compute_cmvn_stats.sh data/${train}_hires $exp_dir/make_hires/$train $mfccdir || exit 1;
  utils/fix_data_dir.sh data/${train}_hires || exit 1;
fi

if [ $stage -le 2 ]; then
  echo "<<< run_nnet2_common.sh train_lda_mllt >>>"
  # We need to build a small system just because we need the LDA+MLLT transform
  # to train the diag-UBM on top of. We use --num-iters 13 because after we get
  # the transform (12th iter is the last), any further training is pointless.

  #numLeavesMLLT=4000  (swbd: 5500), (zeev - gale: 5000)
  #numGaussMLLT=50000 (swbd: 90000), (zeev - gale: 10000)

  steps/train_lda_mllt.sh --cmd "$train_cmd" --num-iters 13 --splice-opts "--left-context=3 --right-context=3" \
    $numLeavesMLLT $numGaussMLLT data/${train}_hires $lang_dir $fmllr_dir $nnet_dir/fmllr || exit 1;
fi

if [ $stage -le 3 ]; then
  echo "<<< run_nnet2_common.sh train_diag_ubm >>>"
  # To train a diagonal UBM we don't need very much data, so use the smallest
  # subset. the input directory exp/nnet2_online/tri5a is only needed for
  # the splice-opts and the LDA transform.

  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --num-threads 10 --nj "$train_nj" --num-frames 400000 \
    data/${train}_hires 512 $nnet_dir/fmllr $nnet_dir/diag_ubm || exit 1;
fi

if [ $stage -le 4 ]; then
  echo "<<< run_nnet2_common.sh train_ivector_extractor >>>"
  # iVector extractors can in general be sensitive to the amount of data, but
  # this one has a fairly small dim (defaults to 100) so we don't use all of it,
  # we use just the 100k subset (about one sixteenth of the data).

  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj "$train_nj" --num-threads 1 --num-processes 1\
    data/${train}_hires $nnet_dir/diag_ubm $nnet_dir/extractor || exit 1;
fi

if [ $stage -le 5 ]; then
  ivectordir=$nnet_dir/ivectors_train
  echo "<<< run_nnet2_common.sh Extracting ivectors >>>"
  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  #steps/online/nnet2/copy_data_dir.sh --utts-per-spk-max 2 data/${train}_hires data/${train}_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "$train_nj" \
    data/${train}_hires $nnet_dir/extractor $ivectordir || exit 1;
fi

exit 0;

