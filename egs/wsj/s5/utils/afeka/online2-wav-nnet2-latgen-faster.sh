#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.
graph_mode=LVCSR # LVCSR | Phn
cmd=run.pl
max_jobs_run=1
nj=1

max_active=7000
beam=15.0
lattice_beam=6.0
acoustic_scale=0.1
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 4 ]; then
   echo "Usage: $(basename $0) [options] <data-set> <lang-type> <fmllr-dir> <nnet2-dir>"
   echo "e.g.: $(basename $0) --graph-mode LVCSR dev Only_Train exp/tri3 exp/nnet2_online"
   echo "Options:"
   echo "--cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "--max-nj                                         # number maximum parallel jobs (defualt 1)"
   echo "--nj                                             # number of parallel jobs"
   echo "--graph-mode                                     # graph type (LVCSR | Phn)"
   exit 1;
fi

dataset=$1
lang_type=$2
fmllr_model=$3
nnet_model=$4

data_dir=data/$dataset

case "$graph_mode" in
    "LVCSR" )
        graph_dir=$fmllr_model/graph_$lang_type
        if [ ! -f $graph_dir/.done ]; then
          lang_dir=data/lang_$lang_type
          echo "----------create new graph--------------"
          utils/mkgraph.sh $lang_dir $fmllr_model $graph_dir || exit 1;
          touch $graph_dir/.done
        fi
        ;;
    "Phn" )
        graph_dir=$fmllr_model/graph_Phn
        ;;
esac

decode_dir=$nnet_model/decode_${lang_type}_$dataset

mkdir -p $decode_dir
echo $nj > $decode_dir/num_jobs

spk2utt_rspecifier="ark:$data_dir/split$nj/JOB/spk2utt"

if [ -f $data_dir/segments ]; then
  echo "----------Running recognition using segments data...--------------"
  wav_rspecifier="ark,s,cs:extract-segments scp,p:$data_dir/split$nj/JOB/wav.scp $data_dir/split$nj/JOB/segments ark:- |"
else
  echo "----------Running recognition...--------------"
  wav_rspecifier="ark,s,cs:wav-copy scp,p:$data_dir/split$nj/JOB/wav.scp ark:- |"
fi

$cmd --max-jobs-run $max_jobs_run JOB=1:$nj $decode_dir/log/decode.JOB.log \
  online2-wav-nnet2-latgen-faster --online=false --do-endpointing=false \
   --config=$nnet_model/conf/online_nnet2_decoding.conf \
   --max-active=$max_active --beam=$beam --lattice-beam=$lattice_beam --acoustic-scale=$acoustic_scale \
   --word-symbol-table=$graph_dir/words.txt \
   $nnet_model/final.mdl $graph_dir/HCLG.fst "$spk2utt_rspecifier" "$wav_rspecifier" \
   "ark:|gzip -c > $decode_dir/lat.JOB.gz" || exit 1;

touch $decode_dir/.done

echo "Done"

exit 0;
