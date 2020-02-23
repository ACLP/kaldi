#!/bin/bash
# Copyright      2017   David Snyder
#                2017   Johns Hopkins University (Author: Daniel Garcia-Romero)
#                2017   Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.
#
# See README.txt for more info on data required.
# Results (mostly EERs) are inline in comments below.
#
# This example demonstrates a "bare bones" NIST SRE 2016 recipe using xvectors.
# In the future, we will add score-normalization and a more effective form of
# PLDA domain adaptation.

# example: ./run_xVec_train_speakers.sh ../inputData/example_audio/tr/train_files_utt.txt flask
. cmd.sh
. path.sh
set -e
echo input file: $1
input_file=$1
dbname=$2

shared_foler=/storage/kaldi-trunk/egs/sre16/rani/
testFileNames_relPath=$input_file
input_folder=$shared_foler/inputData
train_wav_spkr=$input_folder/train_files_utt.txt
output_json=$shared_foler/results_xvec.json
run_path=/storage/kaldi-trunk/egs/sre16/rani/xVec #/media/win-docekr_share/xVec  #/media/6GB/nir/xVec_tmpFiles
eg_path=/storage/kaldi-trunk/egs/sre16/rani/xVec # /media/win-docekr_share/xVec #/kaldi/egs/xVec
mfccdir=${run_path}/mfcc
vaddir=${run_path}/mfcc
trials=${run_path}/data/${dbname}_test/trials
nnet_dir=${eg_path}/exp/xvector_nnet_1a
n_jobs_mfcc=1
n_jobs_ivec=1
stage=1
trainFileNames_relPath=$1


# compute mfcc for training files
if [ $stage -le 10 ]; then
 echo  "stage 10"
 \rm -rf ${run_path}/data/
 cp $trainFileNames_relPath $train_wav_spkr
 ${eg_path}/local_afeka/make_flask_train.pl $input_folder/ ${run_path}/data/   $dbname $train_wav_spkr

  # Make filterbanks and compute the energy-based VAD for each dataset
  for name in ${dbname}_train ; do  
    ${eg_path}/local_afeka/make_mfcc.sh --mfcc-config  ${eg_path}/conf/mfcc.conf --nj $n_jobs_mfcc --cmd "$train_cmd" \
      ${run_path}/data/${name} ${run_path}/exp/make_mfcc $mfccdir
    ${eg_path}/utils/fix_data_dir.sh ${run_path}/data/${name}
    ${eg_path}/sid/compute_vad_decision.sh --nj $n_jobs_mfcc --cmd "$train_cmd" \
      ${run_path}/data/${name} ${run_path}/exp/make_vad $vaddir
    ${eg_path}/utils/fix_data_dir.sh ${run_path}/data/${name}
  done
fi
# compute ivec for training files
if [ $stage -le 20 ]; then
  echo  "stage 20"
  ${eg_path}/sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 12G" --nj $n_jobs_ivec \
    $nnet_dir ${run_path}/data/${dbname}_train \
    ${run_path}/exp/xvectors_${dbname}_train
fi

echo "ENDED"