#!/bin/bash
# Modified by Ella Erlich

# begin configuration section.
stage=1
train_stage=-10
generate_alignments=true # false if doing ctc training
speed_perturb=true
#end configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

[ ! -f ./conf/main.conf ] && echo "File configuration does not exist!" && exit 1
. ./conf/main.conf || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) <train-set> <data-lang> <fmllr-dir> <out-nnet-dir>"
  echo "e.g.: $(basename $0) train data/lang exp/tri3 exp/chain/tdnn_7g_sp"
  exit 1;
fi

train=$1
lang_dir=$2
fmllr_dir=$3
nnet_dir=$4

exp_dir=`dirname $fmllr_dir`

# perturbed data preparation
train_set=$train
if [ "$speed_perturb" == "true" ]; then
  if [ $stage -le 1 ]; then
    #Although the nnet will be trained by high resolution data, we still have to perturbe the normal data to get the alignment
    # _sp stands for speed-perturbed

    for datadir in $train; do
      utils/perturb_data_dir_speed.sh 0.9 data/${datadir} data/temp1
      utils/perturb_data_dir_speed.sh 1.1 data/${datadir} data/temp2
      utils/combine_data.sh data/${datadir}_tmp data/temp1 data/temp2
      utils/validate_data_dir.sh --no-feats data/${datadir}_tmp
      rm -r data/temp1 data/temp2

      mfccdir=mfcc_perturbed
      use_pitch=true

      if $use_pitch; then
        steps/make_plp_pitch.sh --cmd "$train_cmd" --nj "$train_nj" --compress false data/${datadir}_tmp $exp_dir/make_mfcc/${datadir}_tmp $mfccdir || exit 1;
      else
        steps/make_plp.sh --cmd "$train_cmd" --nj "$train_nj" --compress false data/${datadir}_tmp $exp_dir/make_mfcc/${datadir}_tmp $mfccdir || exit 1;
      fi

      steps/compute_cmvn_stats.sh data/${datadir}_tmp $exp_dir/make_mfcc/${datadir}_tmp $mfccdir || exit 1;
      utils/fix_data_dir.sh data/${datadir}_tmp

      utils/copy_data_dir.sh --spk-prefix sp1.0- --utt-prefix sp1.0- data/${datadir} data/temp0
      utils/combine_data.sh data/${datadir}_sp data/${datadir}_tmp data/temp0
      utils/fix_data_dir.sh data/${datadir}_sp
      rm -r data/temp0 data/${datadir}_tmp
    done
  fi

  if [ $stage -le 2 ] && [ "$generate_alignments" == "true" ]; then
    #obtain the alignment of the perturbed data
    steps/align_fmllr.sh --cmd "$train_cmd" --nj "$train_nj" \
      data/${train}_sp $lang_dir $fmllr_dir ${fmllr_dir}_ali_sp || exit 1;
  fi
  train_set=${train}_sp
fi

if [ $stage -le 3 ]; then
  mfccdir=mfcc_hires


  for dataset in $train_set $train; do
    utils/copy_data_dir.sh data/$dataset data/${dataset}_hires

    utils/data/perturb_data_dir_volume.sh data/${dataset}_hires

    steps/make_mfcc.sh --cmd "$train_cmd" --nj "$train_nj" --mfcc-config conf/mfcc_hires.conf \
        data/${dataset}_hires $exp_dir/make_hires/$dataset $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/${dataset}_hires $exp_dir/make_hires/${dataset} $mfccdir || exit 1;
    utils/fix_data_dir.sh data/${dataset}_hires || exit 1;
  done
fi

# ivector extractor training
if [ $stage -le 4 ]; then
  # We need to build a small system just because we need the LDA+MLLT transform
  # to train the diag-UBM on top of.  We use --num-iters 13 because after we get
  # the transform (12th iter is the last), any further training is pointless.
  # this decision is based on fisher_english
  
  #numLeavesMLLT=4000  (swbd: 5500)
  #numGaussMLLT=50000 (swbd: 90000)

  steps/train_lda_mllt.sh --cmd "$train_cmd" --num-iters 13 --splice-opts "--left-context=3 --right-context=3" $numLeavesMLLT $numGaussMLLT \
    data/${train}_hires $lang_dir $fmllr_dir $nnet_dir/fmllr || exit 1;
fi

if [ $stage -le 5 ]; then
  # To train a diagonal UBM we don't need very much data, so use the smallest subset.
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj "$train_nj" --num-frames 200000 \
    data/${train_set}_hires 512 $nnet_dir/fmllr $nnet_dir/diag_ubm || exit 1;
fi

if [ $stage -le 6 ]; then
  # iVector extractors can be sensitive to the amount of data, but this one has a
  # fairly small dim (defaults to 100) so we don't use all of it, we use just the
  # 100k subset (just under half the data).
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj "$train_nj" \
    data/${train}_hires $nnet_dir/diag_ubm $nnet_dir/extractor || exit 1;
fi

if [ $stage -le 7 ]; then
  # We extract iVectors on all the train_nodup data, which will be what we
  # train the system on.

  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 data/${train_set}_hires data/${train_set}_max2_hires

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "$train_nj" \
    data/${train_set}_max2_hires $nnet_dir/extractor $nnet_dir/ivectors_$train_set || exit 1;
fi

exit 0;
