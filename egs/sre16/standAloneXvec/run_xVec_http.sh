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

#example: ./run_xVec.sh ../inputData/example_audio/tst/tests_file.txt flask
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
stage=25

nFiles=`wc -l $train_wav_spkr | awk '{print $1}' `
if [ $nFiles -le $n_jobs_mfcc ]; then
	$n_jobs_mfcc = $nFiles
fi
if [ $nFiles -le $n_jobs_ivec ]; then
	$n_jobs_ivec= $nFiles
fi

train_wav_spkr="data/${dbname}_train/new_uniq_wav2spkr.txt"

# compute mfcc for testing files
if [ $stage -le 30 ]; then
  echo  "stage 30"
 echo "MAKE_WIN ${eg_path}/local_afeka/make_flask_test_window_http.pl $input_folder/ ${run_path}/data/ $dbname $train_wav_spkr $input_file "
 ${eg_path}/local_afeka/make_flask_test_window.pl $input_folder/ ${run_path}/data/   $dbname $train_wav_spkr $input_file

  # Make filterbanks and compute the energy-based VAD for each dataset
  for name in ${dbname}_test ; do  #removed from for: ${dbname}_train
    ${eg_path}/local_afeka/make_mfcc.sh --mfcc-config  ${eg_path}/conf/mfcc.conf --nj $n_jobs_mfcc --cmd "$train_cmd" \
      ${run_path}/data/${name} ${run_path}/exp/make_mfcc $mfccdir
    ${eg_path}/utils/fix_data_dir.sh ${run_path}/data/${name}
    ${eg_path}/sid/compute_vad_decision.sh --nj $n_jobs_mfcc --cmd "$train_cmd" \
      ${run_path}/data/${name} ${run_path}/exp/make_vad $vaddir
    ${eg_path}/utils/fix_data_dir.sh ${run_path}/data/${name}
  done
fi

# compute ivec for testing files
if [ $stage -le 40 ]; then
  echo  "stage 40"
  # The  test data
  ${eg_path}/sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 12G" --nj $n_jobs_ivec \
    $nnet_dir ${run_path}/data/${dbname}_test \
    ${run_path}/exp/xvectors_${dbname}_test
fi

#PLDA scoring
if [ $stage -le 50 ]; then
  echo  "stage 50"
  # Get results using the out-of-domain PLDA model.
  # run: train vs test
  $train_cmd ${run_path}/exp/scores/log/${dbname}_test.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:${run_path}/exp/xvectors_${dbname}_train/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 ${eg_path}/exp/xvectors_sre_combined/plda - |" \
    "ark:ivector-mean ark:${run_path}/data/${dbname}_train/spk2utt scp:${run_path}/exp/xvectors_${dbname}_train/xvector.scp ark:- | ivector-subtract-global-mean ${eg_path}/exp/xvectors_sre16_major/mean.vec ark:- ark:- | transform-vec ${eg_path}/exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean ${eg_path}/exp/xvectors_sre16_major/mean.vec scp:${run_path}/exp/xvectors_${dbname}_test/xvector.scp ark:- | transform-vec ${eg_path}/exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trials' | cut -d\  --fields=1,2 |" ${run_path}/exp/scores/${dbname}_test_scores || exit 1;
    uniq  ${run_path}/exp/scores/${dbname}_test_scores >  ${run_path}/exp/scores/${dbname}_test_scores.uniq
    ${eg_path}/local_afeka/get_max_speaker_file_window_score.pl data/${dbname}_train/original_wav2spkr.txt  ${run_path}/exp/scores/${dbname}_test_scores.uniq | sort -rn -k 3 >  ${run_path}/exp/scores/${dbname}_test_scores.per_speaker

    #echo "${eg_path}/local_afeka/get_max_speaker_file_window_score.pl data/${dbname}_train/original_wav2spkr.txt  ${run_path}/exp/scores/${dbname}_test_scores.uniq | sort -rn -k 3 >  ${run_path}/exp/scores/${dbname}_test_scores.per_speaker"

    #${eg_path}/local_afeka/kaldi_results_2_json.pl ${run_path}/exp/scores/${dbname}_test_scores.per_speaker  normalization_parameters.txt > $output_json
fi

echo "ENDED"