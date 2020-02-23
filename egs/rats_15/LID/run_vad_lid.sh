#!/usr/bin/env bash
# Copyright  2016 David Snyder
# Apache 2.0.
#

function do_cleanup() {
    if $cleanup && [ -d $tempdir ]; then echo ; echo ">>>>>>>>>> cleanup: $(date)"; rm -rf $tempdir; fi
}

# run do_cleanup on exit
trap do_cleanup exit

# This script demonstrates training a DNN for the NIST LRE07 eval

. path.sh
set -e
cleanup=true
sad_nnet_dir=mdl/tdnn_stats_asr_sad
sad_graph_dir=$sad_nnet_dir/graph
xvec_nnet_dir=exp/xvector_nnet_1a_alv_eng
languages=local/lang_ids_alv_eng.txt
# xvec_nnet_dir=exp/xvector_nnet_1a
# languages=local/lang_ids.txt

. ./utils/parse_options.sh || exit 1

if [ $# != 1 ] && [ $# != 3 ]; then
   echo "usage: run_vad_lid.sh [options] <in-audio> [<t-start> <t-end>]"
   echo "e.g.:  run_vad_lid.sh input.wav 0.5 10.0"
   echo "  --sad-nnet-dir <dir>    # location of SAD dnn"
   echo "  --xvec-nnet-dir <dir>   # location of x-Vector dnn"
   exit 1;
fi

infile=$1
trim_opts=""

if [ $# == 3 ]; then
    trim_opts="trim =$2 =$3"
fi


sad_priors_opts="--sil-scale=0.1"
sad_opts="--extra-left-context=79 --extra-right-context=21 --frames-per-chunk=150 --extra-left-context-initial=0 --extra-right-context-final=0"
echo ; echo ">>>>>>>>>> start: $(date)"
start=$(date -u +%s)
utt2spk="ark:echo utt1 utt1|"
#wavscp="scp:echo utt1 sox ${infile} -r 8000 -b 16 -f wavpcm - |"
tempdir=$(mktemp -d -p `pwd`)
mkdir $tempdir/feats

echo ; echo ">>>>>>>>>> compute mfcc:"
time ( compute-mfcc-feats --write-utt2dur=ark,t:$tempdir/feats/utt2dur --verbose=2 \
    --config=conf/mfcc_hires.conf scp:<(echo "utt1 sox ${infile} -b 16 -r 8000 -t wavpcm - ${trim_opts} |") ark:- | \
    copy-feats --compress=true --write-num-frames=ark,t:$tempdir/feats/utt2num_frames \
    ark:- ark,scp:$tempdir/feats/feats.ark,$tempdir/feats/feats.scp && \
    compute-cmvn-stats --spk2utt=ark:<(echo "utt1 utt1") scp:$tempdir/feats/feats.scp ark,scp:$tempdir/feats/cmvn.ark,$tempdir/feats/cmvn.scp ) 2>&1

echo ; echo ">>>>>>>>>> nnet3-sad:"
time ( nnet3-compute --use-gpu=no --frame-subsampling-factor=3 $sad_opts ${sad_nnet_dir}/final.raw \
        "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=\"$utt2spk\" scp:$tempdir/feats/cmvn.scp scp:$tempdir/feats/feats.scp ark:- |" \
        "ark:| copy-matrix --apply-exp ark:- ark,scp:$tempdir/feats/output.ark,$tempdir/feats/output.scp" ) 2>&1

time ( decode-faster --acoustic-scale=0.3 --beam=8 --max-active=1000 $sad_graph_dir/HCLG.fst \
    "ark:copy-feats scp:$tempdir/feats/output.scp ark:- | transform-feats $sad_nnet_dir/transform_probs.mat ark:- ark:- | copy-matrix --apply-log ark:- ark:- |" \
    ark:/dev/null ark:- | copy-int-vector ark:- ark,t:- | \
    awk 'BEGIN{s=-1;e=-1;n=0} \
        { printf $1" ["; for (i=2;i<=NF;i++){if ($i==2){n++; e=i; if(s==-1){s=i} } printf " "$i } print " ]" } \
        END{print "start, end frames: \n("n " voiced frames)",s,e > "/dev/stderr"}' 2>$tempdir/start_end | \
    copy-vector ark:- ark,scp:$tempdir/feats/vad.ark,$tempdir/feats/vad.scp ) 2>&1

echo ; echo ">>>>>>>>>> xvector-feats:"
time ( apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 scp:$tempdir/feats/feats.scp ark:- | \
    select-voiced-frames --speech-sym=2 --vad-subsampling-factor=3 ark:- scp,s,cs:$tempdir/feats/vad.scp ark:- | \
    copy-feats --compress=true --write-num-frames=ark,t:$tempdir/feats/utt2num_frames.no_sil ark:- \
        ark,scp:$tempdir/feats/xvector_feats.ark,$tempdir/feats/xvector_feats.scp ) 2>&1

echo ; echo ">>>>>>>>>> LID:"
time ( nnet3-xvector-compute \
    --chunk-size=3000 --min-chunk-size=500 \
    --use-gpu=no $xvec_nnet_dir/final.raw scp:$tempdir/feats/xvector_feats.scp ark,t:$tempdir/post.vec ) 2>&1

echo ; echo ">>>>>>>>>>>> Result:"
cat $tempdir/start_end
echo "LANG ID "
cat $tempdir/post.vec | \
    awk '{max=$3; argmax=3; for(f=3;f<NF;f++) { if ($f>max)
                            { max=$f; argmax=f; }}
                            print $1, (argmax - 3); }' | \
    utils/int2sym.pl -f 2 $languages

finish=$(date -u +%s)
elapsed=$(date -u -d "0 $finish seconds - $start seconds" +%S)
echo ; echo ">>>>>>>>>> done, elapsed time: $elapsed sec"

exit 0
