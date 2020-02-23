#!/bin/bash
# Copyright  2016 David Snyder
# Apache 2.0.
#
# This script demonstrates training a DNN for the NIST LRE07 eval
# Modified by Noam Lothner 2020 02 for training on LDC SAD RATS DB
# Continued modification by ZR 

. cmd.sh
. path.sh
set -e


#stage=1 #<<<<<<<<<<<< verify from start
stage=2


sad_stage=2 # Not a patch really start from 2

mfcc_suffix='_hires'
datadir=data
datafile=data/sad.data
sad_nnet_dir=mdl/tdnn_stats_asr_sad

nj=8
mfccdir=`pwd`/mfcc${mfcc_suffix}
#languages=local/lmfccg_ids.txt
apply_min_len=false
apply_min_utt=false
nnet_dir=exp/xvector_nnet_1a

. ./utils/parse_options.sh || exit 1


sad_graph_opts="--min-silence-duration=0.03 --min-speech-duration=0.3 --max-speech-duration=10.0"
sad_priors_opts="--sil-scale=0.1"
sad_opts="--extra-left-context 79 --extra-right-context 21 --frames-per-chunk 150 --extra-left-context-initial 0 --extra-right-context-final 0 --acwt 0.3"


echo "start time"
date
# Training data sources
if [ $stage -le 1 ] && [ ! -e ${datadir}/.done.rats15 ]; then
  echo ">>>>> DB ingesstion"
  date
  mkdir -p $datadir
  local/make_rats15_sad.py --verbose 1 ${datafile} ${datadir} /storage/DB/LDC/LDC2015S02/RATS_SAD
  
  ## >>>> run only on dev, train processed above without cutting to short PTTs
  
  # for s in dev-1 dev-2; do
    # for ch in A B C D E F G src; do
      # for f in /storage/DB/LDC/LDC2015S02/RATS_SAD/data/${s}/sad/${ch}/*.tab; do
        # local/RatsKwsPrepKaldiData.py ${f} data_new/${s} -RmRxNx=1 -RmSnoTxt=0 -RmSingleNs=1 -MaxGap=0.2 -MaxPtt=5
      # done
    # done
  # done
  # for s in train; do
    # for lang in alv  eng  fas  pus  urd; do
      # for ch in A B C D E F G src; do
        # for f in /storage/DB/LDC/LDC2015S02/RATS_SAD/data/${s}/sad/${lang}/${ch}/*.tab; do
          # local/RatsKwsPrepKaldiData.py ${f} data_new/${s} -RmRxNx=1 -RmSnoTxt=0 -RmSingleNs=1 -MaxGap=0.2 -MaxPtt=5
        # done
      # done
    # done
  # done

  touch ${datadir}/.done.rats15
fi

if [ $stage -le 2 ]; then
  echo ">>>>> MFCC extraction and VAD"
  date
  for x in train dev-1 dev-2; do
    dir=${datadir}/${x}

    utils/fix_data_dir.sh ${dir}

    if [ ! -e ${mfccdir}/.done.mfcc.${x} ]; then
      steps/make_mfcc.sh --cmd "$cmd" --nj $nj --write-utt2num-frames true --mfcc-config conf/mfcc${mfcc_suffix}.conf \
        ${dir} exp/make_mfcc${mfcc_suffix} ${mfccdir}
      utils/fix_data_dir.sh ${dir}
      touch ${mfccdir}/.done.mfcc.${x}
    fi
    
    #if [ $stage -le -100 ]; then
    if [ ! -e ${mfccdir}/.done.vad.${x} ]; then
      local/detect_speech_activity.sh --cmd "${gpu_cmd}" --nj $nj \
        --stage ${sad_stage} --mfcc_config conf/mfcc${mfcc_suffix}.conf \
        --graph-opts "$sad_graph_opts" \
        --transform-probs-opts "$sad_priors_opts" $sad_opts \
        ${dir} $sad_nnet_dir ${mfccdir} exp/make_vad${mfcc_suffix} \
        ${dir} || exit 1;

    #   lid/compute_vad_decision.sh --cmd "$cmd" --nj $nj ${dir} exp/make_vad${mfcc_suffix} ${mfccdir}
    #   utils/fix_data_dir.sh ${dir}
      touch ${mfccdir}/.done.vad.${x}
    fi
  done

  # # train_no_src
  # if [ ! -d ${datadir}/train_no_src ]; then
  #   mkdir -p ${datadir}/train_no_src 
  #   cp ${datadir}/train/frame_shift ${datadir}/train/vad_subsampling_factor ${datadir}/train_no_src
  #   for f in wav.scp vad.scp utt2spk utt2num_frames utt2lang utt2dur; do
  #     grep -v '_src' ${datadir}/train/$f > ${datadir}/train_no_src/$(basename $f)
  #   done
  #   utils/fix_data_dir.sh ${datadir}/train_no_src
  # fi

  # train languages (for sub-setting):
  for lang in $(gawk '{print $1}' local/lang_ids.txt); do 
    if [ ! -d ${datadir}/train_${lang} ]; then
      #echo $lang
      mkdir -p ${datadir}/train_${lang}
      cp ${datadir}/train/frame_shift ${datadir}/train/vad_subsampling_factor ${datadir}/train_${lang};
      for f in wav.scp vad.scp feats.scp utt2spk utt2num_frames utt2lang utt2dur; do 
        #echo "\t$f"
        gawk "\$1~/_${lang}_/{print}" ${datadir}/train/$f > ${datadir}/train_${lang}/$f;
      done
    fi
  done

  # dev
  utils/combine_data.sh --extra-files "utt2num_frames vad.scp utt2lang frame_shift vad_subsampling_factor" \
    ${datadir}/dev ${datadir}/dev-{1,2}
fi

exit

vad_subsampling_factor=1
if [ -f $sad_nnet_dir/frame_subsampling_factor ]; then
  vad_subsampling_factor=$(cat $sad_nnet_dir/frame_subsampling_factor)

  echo "vad_subsampling_factor set to ${vad_subsampling_factor}"
fi


if [ $stage -le 3 ] ; then
  echo ">>>>> Prepare feats"
  date
  for x in train_alv_eng; do # train_no_src dev train; do
    mkdir -p ${datadir}/${x}
    utils/combine_data.sh --extra-files "utt2num_frames vad.scp utt2lang frame_shift vad_subsampling_factor" \
      ${datadir}/${x} ${datadir}/train_{alv,eng}

    dir=${datadir}/${x}_no_sil
    if [ ! -e ${dir}/.done.prep_feats ]; then
      echo prepare_feats_for_egs on ${x}
      # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
      # wasteful, as it roughly doubles the amount of training data on disk.  After
      # creating training examples, this can be removed.
      lid/nnet3/xvector/prepare_feats_for_egs.sh --nj $nj --cmd "$cmd" \
        --vad-subsampling-factor $vad_subsampling_factor ${datadir}/${x} ${dir} exp/${x}_no_sil
      cp ${datadir}/${x}/utt2lang ${dir}
      utils/fix_data_dir.sh ${dir}
      touch ${dir}/.done.prep_feats
    fi
  done
fi

if [ $stage -le 6 ]; then
  echo ">>>>> X-Vector training"
  for x in _alv_eng; do # _no_src ""; do
    _nnet_dir=${nnet_dir}${x}
    echo "_nnet_dir=${nnet_dir}"
    if [ ! -e ${_nnet_dir}/.done.xvector ]; then
      echo run_xvector on ${_nnet_dir}

      lid/nnet3/xvector/run_xvector.sh --nj $nj \
        --stage ${stage} --train-stage -1 \
        --data ${datadir}/train${x}_no_sil --nnet-dir $_nnet_dir \
        --egs-dir $_nnet_dir/egs

        touch ${_nnet_dir}/.done.xvector
    fi
  done
fi

echo "done training x-vector net"

if [ $stage -le 8 ]; then
  echo running evaluation on dev utternaces

  for x in _alv_eng; do # _no_src ""; do
    _nnet_dir=${nnet_dir}${x}

    lid/eval_dnn.sh --cmd "${gpu_cmd}" --chunk-size 3000 \
                  --min-chunk-size 500 --use-gpu yes \
                  --nj $nj \
                  $_nnet_dir/final.raw ${datadir}/dev_no_sil \
                  exp/dev_results${x}

    echo "Done evaluation on dev (train${x}), analysis:"
    cat exp/dev_results${x}/output | gawk -f local/analyze_output.awk
  done
fi

exit 1



if [ $stage -le 8 ]; then
  # Compute the mean vector for centering the evaluation xvectors.
  $train_cmd exp/xvectors_sre16_major/log/compute_mean.log \
    ivector-mean scp:exp/xvectors_sre16_major/xvector.scp \
    exp/xvectors_sre16_major/mean.vec || exit 1;

  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=150
  $train_cmd exp/xvectors_sre_combined/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:exp/xvectors_sre_combined/xvector.scp ark:- |" \
    ark:data/sre_combined/utt2spk exp/xvectors_sre_combined/transform.mat || exit 1;

  # Train an out-of-domain PLDA model.
  $train_cmd exp/xvectors_sre_combined/log/plda.log \
    ivector-compute-plda ark:data/sre_combined/spk2utt \
    "ark:ivector-subtract-global-mean scp:exp/xvectors_sre_combined/xvector.scp ark:- | transform-vec exp/xvectors_sre_combined/transform.mat ark:- ark:- | #ivector-normalize-length ark:-  ark:- |" \
    exp/xvectors_sre_combined/plda || exit 1;

  # Here we adapt the out-of-domain PLDA model to eli major, a pile
  # of unlabeled in-domain data.  In the future, we will include a clustering
  # based approach for domain adaptation, which tends to work better.
  $train_cmd exp/xvectors_sre16_major/log/plda_adapt.log \
    ivector-adapt-plda --within-covar-scale=0.75 --between-covar-scale=0.25 \
    exp/xvectors_sre_combined/plda \
    "ark:ivector-subtract-global-mean scp:exp/xvectors_sre16_major/xvector.scp ark:- | transform-vec exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length #ark:- ark:- |" \
    exp/xvectors_sre16_major/plda_adapt || exit 1;
fi

if [ $stage -le 9 ]; then
  # Get results using the out-of-domain PLDA model.
  $train_cmd exp/scores/log/sre10_test_10sec.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:exp/xvectors_sre10_train_10sec/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 exp/xvectors_sre_combined/plda - |" \
    "ark:ivector-mean ark:data/sre10_train_10sec/spk2utt scp:exp/xvectors_sre10_train_10sec/xvector.scp ark:- | ivector-subtract-global-mean exp/xvectors_sre16_major/mean.vec ark:- ark:- | transform-vec exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean exp/xvectors_sre16_major/mean.vec scp:exp/xvectors_sre10_test_10sec/xvector.scp ark:- | transform-vec exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trials' | cut -d\  --fields=1,2 |" exp/scores/sre10_test_10sec_scores || exit 1;


  pooled_eer=$(paste $trials exp/scores/sre10_test_10sec_scores | awk '{print $6, $3}' | local_afeka/compute-eer_nir - 2>/dev/null)
  
  echo "Using Out-of-Domain PLDA, EER: Pooled ${pooled_eer}%, "
  # EER: Pooled 11.73%, Tagalog 15.96%, Cantonese 7.52%
  # For reference, here's the ivector system from ../v1:
  # EER: Pooled 13.65%, Tagalog 17.73%, Cantonese 9.61%
fi

if [ $stage -le 10 ]; then
  # Get results using the adapted PLDA model.
  $train_cmd exp/scores/log/sre10_test_10sec_scoring_adapt.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:exp/xvectors_sre10_train_10sec/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 exp/xvectors_sre16_major/plda_adapt - |" \
    "ark:ivector-mean ark:data/sre10_train_10sec/spk2utt scp:exp/xvectors_sre10_train_10sec/xvector.scp ark:- | ivector-subtract-global-mean exp/xvectors_sre16_major/mean.vec ark:- ark:- | transform-vec exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean exp/xvectors_sre16_major/mean.vec scp:exp/xvectors_sre10_test_10sec/xvector.scp ark:- | transform-vec exp/xvectors_sre_combined/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trials' | cut -d\  --fields=1,2 |" exp/scores/sre10_test_10sec_scores_adapt || exit 1;

  pooled_eer=$(paste $trials exp/scores/sre10_test_10sec_scores_adapt | awk '{print $6, $3}' | local_afeka/compute-eer_nir - 2>/dev/null)
  echo "Using Adapted PLDA, EER: Pooled ${pooled_eer}%,"

fi













durs="3 5 10"
prep=false
if $prep && [ $stage -le 9 ]; then
  utils/data/get_segments_for_data.sh ${datadir}/dev > ${datadir}/dev.segments.full
  for dur in ${durs}; do 
    echo "preparing dev (uniform $dur sec segments)"
    dir=${datadir}/dev_uniform_${dur}sec
    mkdir -p ${dir}
    utils/data/get_uniform_subsegments.py \
        --max-segment-duration ${dur} \
        --overlap-duration 0 \
        --max-remaining-duration ${dur} \
        ${datadir}/dev.segments.full > $dir/segments.${dur}sec
    local/subsegment_data_dir.sh ${datadir}/dev ${dir}/segments.${dur}sec ${dir}

    lid/nnet3/xvector/prepare_feats_for_egs.sh --nj $nj --cmd "$cmd" \
        --vad-subsampling-factor $vad_subsampling_factor \
        ${dir} ${dir}_no_sil exp/dev_uniform_${dur}sec_no_sil
  done
  for dur in ${durs}; do
    dir=${datadir}/dev_uniform_${dur}sec
    cp ${dir}/utt2lang ${dir}/segments ${dir}_no_sil
    utils/fix_data_dir.sh ${dir}_no_sil
  done
  rm ${datadir}/dev.segments.full
fi

if [ $stage -le 10 ]; then
  for dur in ${durs}; do
    echo "running evaluation on dev (uniform $dur sec segments)"
    dir=${datadir}/dev_uniform_${dur}sec_no_sil

    for x in ""; do
      _nnet_dir=${nnet_dir}${x}
      expdir=exp/dev_uniform_${dur}sec_results${x}

      lid/eval_dnn.sh --cmd "${gpu_cmd}" --chunk-size 3000 \
                  --min-chunk-size 500 --use-gpu yes \
                  --nj $nj \
                  $_nnet_dir/final.raw ${dir} ${expdir}

      echo "Done evaluation on dev (uniform $dur sec segments, train${x}), analysis:"
      cat ${expdir}/output | gawk -f local/analyze_output.awk
    done
  done
fi

exit 0;


##############################################
## EOF
##############################################




if [ $stage -le 7 ]; then
  # The SRE16 major is an unlabeled dataset consisting of Cantonese and
  # and Tagalog.  This is useful for things like centering, whitening and
  # score normalization.
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    $nnet_dir data/sre16_major \
    exp/xvectors_sre16_major

  # Extract xvectors for SRE data (includes Mixer 6). We'll use this for
  # things like LDA or PLDA.
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 12G" --nj 40 \
    $nnet_dir data/sre_combined \
    exp/xvectors_sre_combined

  # The SRE16 test data
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    $nnet_dir data/sre16_eval_test \
    exp/xvectors_sre16_eval_test

  # The SRE16 enroll data
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 6G" --nj 40 \
    $nnet_dir data/sre16_eval_enroll \
    exp/xvectors_sre16_eval_enroll
fi

exit 0
# Make the evaluation data set. We're concentrating on the General Language
# Recognition Closed-Set evaluation, so we remove the dialects and filter
# out the unknown languages used in the open-set evaluation.
#local/make_lre07.pl /export/corpora5/LDC/LDC2009S04 data/lre07_all

local/make_lre07.pl /export/corpora5/LDC/LDC2009S04 data/lre07_all
cp -r data/lre07_all data/lre07
utils/filter_scp.pl -f 2 $languages <(lid/remove_dialect.pl data/lre07_all/utt2lang) \
  > data/lre07/utt2lang
utils/fix_data_dir.sh data/lre07

src_list="data/sre08_train_10sec_female \
    data/sre08_train_10sec_male data/sre08_train_3conv_female \
    data/sre08_train_3conv_male data/sre08_train_8conv_female \
    data/sre08_train_8conv_male data/sre08_train_short2_male \
    data/sre08_train_short2_female data/ldc96* data/lid05d1 \
    data/lid05e1 data/lid96d1 data/lid96e1 data/lre03 \
    data/ldc2009* data/lre09"

# Remove any spk2gender files that we have: since not all data
# sources have this info, it will cause problems with combine_data.sh
for d in $src_list; do rm -f $d/spk2gender 2>/dev/null; done

utils/combine_data.sh data/train_unsplit $src_list

# original utt2lang will remain in data/train_unsplit/.backup/utt2lang.
utils/apply_map.pl -f 2 --permissive local/lang_map.txt \
  < data/train_unsplit/utt2lang 2>/dev/null > foo
cp foo data/train_unsplit/utt2lang
rm foo

echo "**Language count for DNN training:**"
awk '{print $2}' data/train/utt2lang | sort | uniq -c | sort -nr

steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
  data/train exp/make_mfcc $mfccdir
steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
  data/lre07 exp/make_mfcc $mfccdir

lid/compute_vad_decision.sh --nj 10 --cmd "$train_cmd" data/train \
  exp/make_vad $mfccdir
lid/compute_vad_decision.sh --nj 10 --cmd "$train_cmd" data/lre07 \
  exp/make_vad $mfccdir

# NOTE: Example of removing the silence. In this case, the features
# are mean normlized MFCCs.
if [ 0 = 1 ]; then
nj=20
feats_dir=mfcc/feats_cmvn_no_sil
for data in lre07 train; do
  sdata=data/$data/split$nj;
  echo "making cmvn vad stats for $data"
  utils/split_data.sh data/$data $nj || exit 1;
  mkdir -p ${feats_dir}/log/
  cp -r data/${data} data/${data}_cmvn_no_sil
  queue.pl JOB=1:$nj ${feats_dir}/log/${data}_cmvn_no_sil.JOB.log \
    apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 scp:$sdata/JOB/feats.scp ark:- \| \
    select-voiced-frames ark:- scp,s,cs:$sdata/JOB/vad.scp \
    ark,scp:${feats_dir}/cmvn_no_sil_${data}_feats.JOB.ark,${feats_dir}/cmvn_no_sil_${data}_feats.JOB.scp || exit 1;
    utils/fix_data_dir.sh data/${data}_cmvn_no_sil
    echo "finished making cmvn vad stats for $data"
done
fi

# NOTE:
# This script will expand the feature matrices, as may be required by the DNN.
# It supports 3 ways of expanding: "tile" copies the entire feature matrix repeatedly,
# "zero" pads with 0 on the left and right, and "copy" pads by copying the first and last
# frames repeatedly. The option --min-length is the target number of frames. If an
# utterance has more frames than this, it is unmodified, otherwise, it is expanded to
# equal min-length.
# NOTE: This script is applied directly to the data directory; it does not make a
# copy (so make a copy first).
steps/expand_feats.sh --cmd "$train_cmd" --min-length 400 \
                      --expand-type "tile" \
                      --nj 40 \
                      data/lre07_cmvn_no_sil_expand \
                      exp/expand_feats $mfccdir
steps/expand_feats.sh --cmd "$train_cmd" --min-length 400 \
                      --expand-type "tile" \
                      --nj 40 \
                      data/train_cmvn_no_sil_expand \
                      exp/expand_feats $mfccdir

utils/fix_data_dir.sh data/lre07_cmvn_no_sil_expand
utils/fix_data_dir.sh data/train_cmvn_no_sil_expand

# NOTE: This script trains the DNN
local/xvector/run_lid.sh --train-stage -10 \
                         --stage -10 \
                         --data data/train_cmvn_no_sil_expand \
                         --nnet-dir exp/xvector_lid_a \
                         --egs-dir exp/xvector_lid_a/egs


# NOTE: Example script of how to extract posteriors from the DNN after it's
# trained. Also does an eval on lre07.
lid/eval_dnn.sh --cmd "$eval_cmd" --chunk-size 3000 \
                --min-chunk-size 500 --use-gpu yes \
                --nj 6 \
                exp/xvector_lid_a/900.raw data/lre07_cmvn_no_sil_expand \
                exp/lre07_results