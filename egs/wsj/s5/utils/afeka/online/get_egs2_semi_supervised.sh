#!/bin/bash

# Copyright 2012-2014 Johns Hopkins University (Author: Daniel Povey).  Apache 2.0.
#
# This script, which will generally be called from other neural-net training
# scripts, extracts the training examples used to train the neural net (and also
# the validation examples used for diagnostics), and puts them in separate archives.
#
# This script differs from get_egs.sh in that it dumps egs with several frames
# of labels, controlled by the frames_per_eg config variable (default: 8).  This
# takes many times less disk space because typically we have 4 to 7 frames of
# context on the left and right, and this ends up getting shared.  This is at
# the expense of slightly higher disk I/O during training time.
#
# We also have a simpler way of dividing the egs up into pieces, with one level
# of index, so we have $dir/egs.{0,1,2,...}.ark instead of having two levels of
# indexes.  The extra files we write to $dir that explain the structure are
# $dir/info/num_archives, which contains the number of files egs.*.ark, and
# $dir/info/frames_per_eg, which contains the number of frames of labels per eg
# (e.g. 7), and $dir/samples_per_archive.  These replace the files
# iters_per_epoch and num_jobs_nnet and egs_per_iter that the previous script
# wrote to.  This script takes the directory where the "egs" are located as the
# argument, not the directory one level up.

# Begin configuration section.
do_supervised_semisup_train=false # Training while using unsupervised data as supervised (DEBUG mode)

cmd=run.pl
feat_type=          # e.g. set it to "raw" to use raw MFCC
frames_per_eg=1   # number of frames of labels per example.  more->less disk space and
                  # less time preparing egs, but more I/O during training.
                  # note: the script may reduce this if reduce_frames_per_eg is true.
left_context=4    # amount of left-context per eg
right_context=4   # amount of right-context per eg
delta_order=      # delta feature order

reduce_frames_per_eg=true  # If true, this script may reduce the frames_per_eg
                           # if there is only one archive and even with the
                           # reduced frames_pe_eg, the number of
                           # samples_per_iter that would result is less than or
                           # equal to the user-specified value.
num_utts_subset=300     # number of utterances in validation and training
                        # subsets used for shrinkage and diagnostics.
num_valid_frames_combine=0 # #valid frames for combination weights at the very end.
num_train_frames_combine=10000 # # train frames for the above.
num_frames_diagnostic=4000 # number of frames for "compute_prob" jobs
samples_per_iter=400000 # each iteration of training, see this many samples
                        # per job.  This is just a guideline; it will pick a number
                        # that divides the number of samples in the entire data.

transform_dir_sup=      # If supplied, overrides alidir as the place to find fMLLR transforms
postdir_sup=            # If supplied, we will use posteriors in it as soft training targets.
transform_dir_unsup=    # If supplied, overrides alidir as the place to find fMLLR transforms
postdir_unsup=          # If supplied, we will use posteriors in it as soft training targets.

weight_threshold=0.7    # Only select frames above this score from unsupervised data
use_frame_selection=true
use_frame_weights=false # TODO: Not supported yet
supervised_copies=1     # Make x copies of supervised data to "over" weight supervised data

stage=0

io_opts="-tc 5" # for jobs with a lot of I/O, limits the number running at one time.
random_copy=false
sup_online_ivector_dir=    # can be used if we are including speaker information as iVectors.
unsup_online_ivector_dir=  # can be used if we are including speaker information as iVectors.
cmvn_opts=  # can be used for specifying CMVN options, if feature type is not lda (if lda,
            # it doesn't make sense to use different options than were used as input to the
            # LDA transform).  This is used to turn off CMVN in the online-nnet experiments.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;


if [ $# != 5 ]; then
  echo "Usage: $0 [opts] <supervised-data-dir> <unsupervised-data-dir> <supervised-ali-dir> <unsupervised-lat-dir> <egs-dir>"
  echo " e.g.: $0 data/train_sup data/train_unsup exp/tri3_ali exp/tri3/decoder_unsup exp/tri4_nnet/egs"
  echo ""
  echo "Main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config file containing options"
  echo "  --cmd (utils/run.pl;utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --samples-per-iter <#samples;400000>             # Number of samples of data to process per iteration, per"
  echo "                                                   # process."
  echo "  --feat-type <lda|raw>                            # (by default it tries to guess).  The feature type you want"
  echo "                                                   # to use as input to the neural net."
  echo "  --frames-per-eg <frames;8>                       # number of frames per eg on disk"
  echo "  --left-context <width;4>                         # Number of frames on left side to append for feature input"
  echo "  --right-context <width;4>                        # Number of frames on right side to append for feature input"
  echo "  --num-frames-diagnostic <#frames;4000>           # Number of frames used in computing (train,valid) diagnostics"
  echo "  --num-valid-frames-combine <#frames;10000>       # Number of frames used in getting combination weights at the"
  echo "                                                   # very end."
  echo "  --stage <stage|0>                                # Used to run a partially-completed training process from somewhere in"
  echo "                                                   # the middle."
  echo "  --weight-threshold <weight|0.7>                  # Threshold on the confidence factor below which the "
  echo "                                                   # frame of unsupervised training data is ignored."
  echo "  --supervised-copies <#copies|3>                  # Make copies of supervised data"
  echo "  --transform-dir-sup                              # Directory with transforms for supervised training data"
  echo "  --transform-dir-unsup                            # Directory with transforms for unsupervised training data"
  exit 1;
fi

data_sup=$1
data_unsup=$2
alidir=$3
latdir=$4
dir=$5

echo "$0 Using weight_threshold=$weight_threshold"

# Check some files.
[ ! -z "$sup_online_ivector_dir" ] && \
  sup_extra_files="$sup_online_ivector_dir/ivector_online.scp $sup_online_ivector_dir/ivector_period"
[ ! -z "$unsup_online_ivector_dir" ] && \
  unsup_extra_files="$unsup_online_ivector_dir/ivector_online.scp $unsup_online_ivector_dir/ivector_period"

for f in $data_sup/feats.scp $data_unsup/feats.scp $alidir/ali.1.gz $alidir/final.mdl $alidir/tree $latdir/best_path_ali.1.gz $latdir/weights.1.gz $latdir/../final.mdl $latdir/../tree $sup_extra_files $unsup_extra_files; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

nj_sup=`cat $alidir/num_jobs` || exit 1;  # number of jobs in alignment dir...
nj_unsup=`cat $latdir/num_jobs` || exit 1;  # number of jobs in decode dir

if [ $nj_sup -ne $nj_unsup ]; then
  echo "$nj_sup -ne $nj_unsup <<<< Currently both sup and unsup num of jobs have to be equal"
  exit
fi

nj=$nj_sup

# in this dir we'll have just one job.
sdata_sup=$data_sup/split$nj_sup
sdata_unsup=$data_unsup/split$nj_unsup
utils/split_data.sh $data_sup $nj_sup
utils/split_data.sh $data_unsup $nj_unsup

mkdir -p $dir/log $dir/info

echo $nj_sup > $dir/num_jobs_sup
echo $nj_unsup > $dir/num_jobs_unsup

cp $alidir/tree $dir

##Ella - ???
#num_utts=$(cat $data/utt2spk | wc -l)
#if ! [ $num_utts -gt $[$num_utts_subset*4] ]; then
#  echo "$0: number of utterances $num_utts in your training data is too small versus --num-utts-subset=$num_utts_subset"
#  echo "... you probably have so little data that it doesn't make sense to train a neural net."
#  exit 1
#fi

# Get list of validation utterances.
awk '{print $1}' $data_sup/utt2spk | utils/shuffle_list.pl | head -$num_utts_subset \
    > $dir/valid_uttlist || exit 1;

# TODO (Vimal 22-Jan-14): Might need to deal unsupervised data separately 
if [ -f $data_sup/utt2uniq ]; then
  echo "File $data_sup/utt2uniq exists, so augmenting valid_uttlist to"
  echo "include all perturbed versions of the same 'real' utterances."
  mv $dir/valid_uttlist $dir/valid_uttlist.tmp
  utils/utt2spk_to_spk2utt.pl $data_sup/utt2uniq > $dir/uniq2utt
  cat $dir/valid_uttlist.tmp | utils/apply_map.pl $data_sup/utt2uniq | \
    sort | uniq | utils/apply_map.pl $dir/uniq2utt | \
    awk '{for(n=1;n<=NF;n++) print $n;}' | sort  > $dir/valid_uttlist
  rm $dir/uniq2utt $dir/valid_uttlist.tmp
fi

# TODO (Vimal 22-Jan-14): Might need to deal unsupervised data separately
awk '{print $1}' $data_sup/utt2spk | utils/filter_scp.pl --exclude $dir/valid_uttlist | \
   utils/shuffle_list.pl | head -$num_utts_subset > $dir/train_subset_uttlist || exit 1;

[ -z "$transform_dir_sup" ] && transform_dir_sup=$alidir
[ -z "$transform_dir_unsup" ] && transform_dir_unsup=$latdir

## Set up features.
if [ -z $feat_type ]; then
  if [ -f $alidir/final.mat ] && [ ! -f $transform_dir_sup/raw_trans.1 ]; then feat_type=lda; else feat_type=raw; fi
fi
echo "$0: feature type is $feat_type"

case $feat_type in
  raw) feats_sup="ark,s,cs:utils/filter_scp.pl --exclude $dir/valid_uttlist $sdata_sup/JOB/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$sdata_sup/JOB/utt2spk scp:$sdata_sup/JOB/cmvn.scp scp:- ark:- |"
    feats_unsup="ark,s,cs:cat $sdata_unsup/JOB/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$sdata_unsup/JOB/utt2spk scp:$sdata_unsup/JOB/cmvn.scp scp:- ark:- |"
    valid_feats="ark,s,cs:utils/filter_scp.pl $dir/valid_uttlist $data_sup/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$data_sup/utt2spk scp:$data_sup/cmvn.scp scp:- ark:- |"
    train_subset_feats="ark,s,cs:utils/filter_scp.pl $dir/train_subset_uttlist $data_sup/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$data_sup/utt2spk scp:$data_sup/cmvn.scp scp:- ark:- |"
    echo $cmvn_opts >$dir/cmvn_opts # caution: the top-level nnet training script should copy this to its own dir now.
    if [ ! -z "$delta_order" ]; then
      feats_sup="$feats add-deltas --delta-order=$delta_order ark:- ark:- |"
      valid_feats="$valid_feats add-deltas --delta-order=$delta_order ark:- ark:- |"
      train_subset_feats="$train_subset_feats add-deltas --delta-order=$delta_order ark:- ark:- |"
      echo $delta_order >$dir/delta_order
    fi
   ;;
  lda)
    splice_opts=`cat $alidir/splice_opts 2>/dev/null`
    # caution: the top-level nnet training script should copy these to its own dir now.
    cp $alidir/{splice_opts,cmvn_opts,final.mat} $dir || exit 1;
    [ ! -z "$cmvn_opts" ] && \
       echo "You cannot supply --cmvn-opts option if feature type is LDA." && exit 1;
    cmvn_opts=$(cat $dir/cmvn_opts)
    feats_sup="ark,s,cs:utils/filter_scp.pl --exclude $dir/valid_uttlist $sdata_sup/JOB/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$sdata_sup/JOB/utt2spk scp:$sdata_sup/JOB/cmvn.scp scp:- ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $dir/final.mat ark:- ark:- |"
    feats_unsup="ark,s,cs:cat $sdata_unsup/JOB/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$sdata_unsup/JOB/utt2spk scp:$sdata_unsup/JOB/cmvn.scp scp:- ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $dir/final.mat ark:- ark:- |"
    valid_feats="ark,s,cs:utils/filter_scp.pl $dir/valid_uttlist $data_sup/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$data_sup/utt2spk scp:$data_sup/cmvn.scp scp:- ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $dir/final.mat ark:- ark:- |"
    train_subset_feats="ark,s,cs:utils/filter_scp.pl $dir/train_subset_uttlist $data_sup/feats.scp | apply-cmvn $cmvn_opts --utt2spk=ark:$data_sup/utt2spk scp:$data_sup/cmvn.scp scp:- ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $dir/final.mat ark:- ark:- |"
    ;;
  *) echo "$0: invalid feature type $feat_type" && exit 1;
esac

if [ -f $transform_dir_sup/trans.1 ] && [ $feat_type != "raw" ]; then
  echo "$0: using transforms from $transform_dir_sup for supervised data"
  feats_sup="$feats_sup transform-feats --utt2spk=ark:$sdata_sup/JOB/utt2spk ark:$transform_dir_sup/trans.JOB ark:- ark:- |"
  valid_feats="$valid_feats transform-feats --utt2spk=ark:$data_sup/utt2spk 'ark:cat $transform_dir_sup/trans.*|' ark:- ark:- |"
  train_subset_feats="$train_subset_feats transform-feats --utt2spk=ark:$data_sup/utt2spk 'ark:cat $transform_dir_sup/trans.*|' ark:- ark:- |"
fi
if [ -f $transform_dir_sup/raw_trans.1 ] && [ $feat_type == "raw" ]; then
  echo "$0: using raw-fMLLR transforms from $transform_dir_sup for supervised data"
  feats_sup="$feats_sup transform-feats --utt2spk=ark:$sdata_sup/JOB/utt2spk ark:$transform_dir_sup/raw_trans.JOB ark:- ark:- |"
  valid_feats="$valid_feats transform-feats --utt2spk=ark:$data_sup/utt2spk 'ark:cat $transform_dir_sup/raw_trans.*|' ark:- ark:- |"
  train_subset_feats="$train_subset_feats transform-feats --utt2spk=ark:$data_sup/utt2spk 'ark:cat $transform_dir_sup/raw_trans.*|' ark:- ark:- |"
fi

if [ -f $transform_dir_unsup/trans.1 ] && [ $feat_type != "raw" ]; then
  echo "$0: using transforms from $transform_dir_unsup for supervised data"
  feats_unsup="$feats_unsup transform-feats --utt2spk=ark:$sdata_unsup/JOB/utt2spk ark:$transform_dir_unsup/trans.JOB ark:- ark:- |"
fi
if [ -f $transform_dir_unsup/raw_trans.1 ] && [ $feat_type == "raw" ]; then
  echo "$0: using raw-fMLLR transforms from $transform_dir_unsup or supervised data"
  feats_unsup="$feats_unsup transform-feats --utt2spk=ark:$sdata_unsup/JOB/utt2spk ark:$transform_dir_unsup/raw_trans.JOB ark:- ark:- |"
fi

if [ ! -z "$sup_online_ivector_dir" ] && [ ! -z "$unsup_online_ivector_dir" ]; then
  feats_one="$(echo "$feats" | sed s:JOB:1:g)"
  ivector_dim=$(feat-to-dim scp:$sup_online_ivector_dir/ivector_online.scp -) || exit 1;
  unsup_ivector_dim=$(feat-to-dim scp:$unsup_online_ivector_dir/ivector_online.scp -) || exit 1;
  if [ "$ivector_dim" -ne "$unsup_ivector_dim" ]; then 
    echo "ivector_dim ne unsup_ivector_dim"
    exit 1; 
  fi
  echo $ivector_dim > $dir/info/ivector_dim
  ivectors_opt="--const-feat-dim=$ivector_dim"
  ivector_period=$(cat $sup_online_ivector_dir/ivector_period) || exit 1;
  unsup_ivector_period=$(cat $unsup_online_ivector_dir/ivector_period) || exit 1;
  if [ "$ivector_period" -ne "$unsup_ivector_period" ]; then 
    echo "ivector_period ne unsup_ivector_period"
    exit 1; 
  fi
  feats_sup="$feats_sup paste-feats --length-tolerance=$ivector_period ark:- 'ark,s,cs:utils/filter_scp.pl $sdata_sup/JOB/utt2spk $sup_online_ivector_dir/ivector_online.scp | subsample-feats --n=-$ivector_period scp:- ark:- |' ark:- |"
  feats_unsup="$feats_unsup paste-feats --length-tolerance=$ivector_period ark:- 'ark,s,cs:utils/filter_scp.pl $sdata_unsup/JOB/utt2spk $unsup_online_ivector_dir/ivector_online.scp | subsample-feats --n=-$ivector_period scp:- ark:- |' ark:- |"
  valid_feats="$valid_feats paste-feats --length-tolerance=$ivector_period ark:- 'ark,s,cs:utils/filter_scp.pl $dir/valid_uttlist $sup_online_ivector_dir/ivector_online.scp | subsample-feats --n=-$ivector_period scp:- ark:- |' ark:- |"
  train_subset_feats="$train_subset_feats paste-feats --length-tolerance=$ivector_period ark:- 'ark,s,cs:utils/filter_scp.pl $dir/train_subset_uttlist $sup_online_ivector_dir/ivector_online.scp | subsample-feats --n=-$ivector_period scp:- ark:- |' ark:- |"
else
  echo 0 >$dir/info/ivector_dim
fi


if [ $stage -le 0 ]; then
  echo "$0: working out number of frames of training data"
  num_sup_frames=$(steps/nnet2/get_num_frames.sh $data_sup)
  num_unsup_frames=$(steps/nnet2/get_num_frames.sh $data_unsup)
  num_frames=$(perl -e "print STDOUT ($num_sup_frames * $supervised_copies + $num_unsup_frames)")
  echo ">>>>> Reduce un-supervsied frames due to TH <<<<<"
  echo $num_sup_frames > $dir/info/num_sup_frames
  echo $num_unsup_frames > $dir/info/num_unsup_frames
  echo $num_frames > $dir/info/num_frames
else
  num_sup_frames=`cat $dir/info/num_sup_frames` || exit 1;
  num_unsup_frames=`cat $dir/info/num_unsup_frames` || exit 1;
  num_frames=`cat $dir/info/num_frames` || exit 1;
fi

# the + 1 is to round up, not down... we assume it doesn't divide exactly.
num_archives=$[$num_frames/($frames_per_eg*$samples_per_iter)+1]
# (for small data)- while reduce_frames_per_eg == true and the number of
# archives is 1 and would still be 1 if we reduced frames_per_eg by 1, reduce it
# by 1.
reduced=false
while $reduce_frames_per_eg && [ $frames_per_eg -gt 1 ] && \
  [ $[$num_frames/(($frames_per_eg-1)*$samples_per_iter)] -eq 0 ]; do
  frames_per_eg=$[$frames_per_eg-1]
  num_archives=1
  reduced=true
done
$reduced && echo "$0: reduced frames_per_eg to $frames_per_eg because amount of data is small."

echo $num_archives >$dir/info/num_archives
echo $frames_per_eg >$dir/info/frames_per_eg

# Working out number of egs per archive
egs_per_archive=$[$num_frames/($frames_per_eg*$num_archives)]
! [ $egs_per_archive -le $samples_per_iter ] && \
  echo "$0: script error: egs_per_archive=$egs_per_archive not <= samples_per_iter=$samples_per_iter" \
  && exit 1;

echo $egs_per_archive > $dir/info/egs_per_archive

echo "$0: creating $num_archives archives, each with $egs_per_archive egs, with"
echo "$0:   $frames_per_eg labels per example, and (left,right) context = ($left_context,$right_context)"

# Making soft links to storage directories.  This is a no-up unless
# the subdirectory $dir/storage/ exists.  See utils/create_split_dir.pl
if [ $stage -le 1 ]; then
  echo "$0: stage 1 Making soft links to storage directories"
  for x in `seq $num_archives`; do
    utils/create_data_link.pl $dir/egs.$x.ark
    for y in `seq $nj`; do
      utils/create_data_link.pl $dir/egs_orig.$x.$y.ark
    done
  done
fi

nnet_context_opts="--left-context=$left_context --right-context=$right_context"

echo $left_context > $dir/info/left_context
echo $right_context > $dir/info/right_context
if [ $stage -le 2 ]; then
  echo "$0: Getting validation and training subset examples."
  rm $dir/.error 2>/dev/null
  echo "$0: ... extracting validation and training-subset alignments."
  set -o pipefail;
  for id in $(seq $nj); do gunzip -c $alidir/ali.$id.gz; done | \
    copy-int-vector ark:- ark,t:- | \
    utils/filter_scp.pl <(cat $dir/valid_uttlist $dir/train_subset_uttlist) | \
    gzip -c >$dir/ali_special.gz || exit 1;
  set +o pipefail; # unset the pipefail option.

  $cmd $dir/log/create_valid_subset.log \
    nnet-get-egs $ivectors_opt $nnet_context_opts "$valid_feats" \
    "ark,s,cs:gunzip -c $dir/ali_special.gz | ali-to-pdf $alidir/final.mdl ark:- ark:- | ali-to-post ark:- ark:- |" \
     "ark:$dir/valid_all.egs" || touch $dir/.error &
  $cmd $dir/log/create_train_subset.log \
    nnet-get-egs $ivectors_opt $nnet_context_opts "$train_subset_feats" \
     "ark,s,cs:gunzip -c $dir/ali_special.gz | ali-to-pdf $alidir/final.mdl ark:- ark:- | ali-to-post ark:- ark:- |" \
     "ark:$dir/train_subset_all.egs" || touch $dir/.error &
  wait;
  [ -f $dir/.error ] && echo "Error detected while creating train/valid egs" && exit 1
  echo "... Getting subsets of validation examples for diagnostics and combination."
  $cmd $dir/log/create_valid_subset_combine.log \
    nnet-subset-egs --n=$num_valid_frames_combine ark:$dir/valid_all.egs \
        ark:$dir/valid_combine.egs || touch $dir/.error &
  $cmd $dir/log/create_valid_subset_diagnostic.log \
    nnet-subset-egs --n=$num_frames_diagnostic ark:$dir/valid_all.egs \
    ark:$dir/valid_diagnostic.egs || touch $dir/.error &

  $cmd $dir/log/create_train_subset_combine.log \
    nnet-subset-egs --n=$num_train_frames_combine ark:$dir/train_subset_all.egs \
    ark:$dir/train_combine.egs || touch $dir/.error &
  $cmd $dir/log/create_train_subset_diagnostic.log \
    nnet-subset-egs --n=$num_frames_diagnostic ark:$dir/train_subset_all.egs \
    ark:$dir/train_diagnostic.egs || touch $dir/.error &
  wait
  sleep 5  # wait for file system to sync.
  cat $dir/valid_combine.egs $dir/train_combine.egs > $dir/combine.egs

  for f in $dir/{combine,train_diagnostic,valid_diagnostic}.egs; do
    [ ! -s $f ] && echo "No examples in file $f" && exit 1;
  done
  rm $dir/valid_all.egs $dir/train_subset_all.egs $dir/{train,valid}_combine.egs $dir/ali_special.gz
fi

mkdir -p $dir/sup
mkdir -p $dir/unsup

if [ $stage -le 3 ]; then
  echo "$0: Getting unsup and sup train examples."
  # create egs_orig.*.*.ark; the first index goes to $num_archives,
  # the second to $nj (which is the number of jobs in the original alignment
  # dir)

  egs_list=
  for n in $(seq $num_archives); do
    egs_list="$egs_list ark:$dir/unsup/egs_orig.$n.JOB.ark"
  done


  # The examples will go round-robin to egs_list.
  if $do_supervised_semisup_train; then
  
    echo " >>>>>>>>>>>>>>>>>>>>>   Running nnet-get-egs on unsup data (DEBUG MODE for getting unsup data non weighted) <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    $cmd $io_opts JOB=1:$nj_unsup $dir/log/get_weighted_egs.JOB.log \
        nnet-get-egs $ivectors_opt $nnet_context_opts --num-frames=$frames_per_eg "$feats_unsup" \
        "ark,s,cs:gunzip -c $latdir/ali.JOB.gz | ali-to-pdf $alidir/final.mdl ark:- ark:- | ali-to-post ark:- ark:- |" ark:- \| \
        nnet-copy-egs ark:- $egs_list || exit 1;

  else
    echo "$0: Running nnet-get-weighted-egs on unsup data."
      #nnet-get-weighted-egs $ivectors_opt $nnet_context_opts 
	  # Using a modified version from  C:\Zeev\Kaldi-Unsupervised-Limal-Manohar2015_05\kaldi-unsupervised-137f0f12726a382529552ee68d75092f939413c3
      $cmd $io_opts JOB=1:$nj_unsup $dir/log/get_weighted_egs.JOB.log \
      nnet-get-weighted-egs-zr $ivectors_opt $nnet_context_opts \
      --weight-threshold=$weight_threshold --use-frame-weights=$use_frame_weights \
      --use-frame-selection=$use_frame_selection "$feats_unsup" \
      "ark,s,cs:gunzip -c $latdir/best_path_ali.JOB.gz | convert-ali $latdir/../final.mdl $alidir/final.mdl $dir/tree ark:- ark:- | ali-to-pdf $alidir/final.mdl ark:- ark:- | ali-to-post ark:- ark:- |" \
      "ark,s,cs:gunzip -c $latdir/weights.JOB.gz |" ark:- \| \
      nnet-copy-egs ark:- $egs_list || exit 1;
	  
  fi

  echo "$0: Running nnet-get-egs on sup data."

  echo "frames_per_eg:" $frames_per_eg
  echo "Num ark files"  $((num_archives*nj))
  delta=$((num_archives/(supervised_copies+1)))

  if [ ! -z $postdir_sup ]; then
    for (( i=0; i<supervised_copies; i++ )); do
      egs_list=
      for n in $(seq $num_archives); do
        egs_list="$egs_list ark:$dir/sup/egs_orig.$((((n+i*delta-1)%num_archives)+1)).$i.JOB.ark"
      done

      $cmd $io_opts JOB=1:$nj $dir/log/get_egs.JOB.log \
        nnet-get-egs $ivectors_opt $nnet_context_opts --num-frames=$frames_per_eg "$feats_sup" \
        scp:$postdir_sup/post.JOB.scp ark:- \| \
        nnet-copy-egs ark:- $egs_list || exit 1;
    done
  else 
    for (( i=0; i<supervised_copies; i++ )); do
      egs_list=
      for n in $(seq $num_archives); do
        egs_list="$egs_list ark:$dir/sup/egs_orig.$((((n+i*delta-1)%num_archives)+1)).$i.JOB.ark"
      done

      $cmd $io_opts JOB=1:$nj $dir/log/get_egs.JOB.log \
        nnet-get-egs $ivectors_opt $nnet_context_opts --num-frames=$frames_per_eg "$feats_sup" \
        "ark,s,cs:gunzip -c $alidir/ali.JOB.gz | ali-to-pdf $alidir/final.mdl ark:- ark:- | ali-to-post ark:- ark:- |" ark:- \| \
        nnet-copy-egs ark:- $egs_list || exit 1;
    done
  fi
fi

if [ $stage -le 4 ]; then
  echo ">>>> Concatenating the eggs <<<<"
  cp  $dir/unsup/* $dir
  for n in $(seq $num_archives); do
    for (( j=1; j<nj; j++ )); do
      cat $dir/sup/egs_orig.$n.*.$j.ark > $dir/egs_orig.$n.$j.ark || exit 1;
    done
  done
fi

if [ $stage -le 5 ]; then
  echo "$0: recombining and shuffling order of archives on disk"
  # combine all the "egs_orig.JOB.*.scp" (over the $nj splits of the data) and
  # shuffle the order, writing to the egs.JOB.ark

  egs_list=
  for n in $(seq $nj); do
    egs_list="$egs_list $dir/egs_orig.JOB.$n.ark"
  done

  $cmd $io_opts $extra_opts JOB=1:$num_archives $dir/log/shuffle.JOB.log \
    nnet-shuffle-egs --srand=JOB "ark:cat $egs_list|" ark:$dir/egs.JOB.ark  || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: removing temporary archives"
  for x in `seq $num_archives`; do
    for y in `seq $nj`; do
      file=$dir/egs_orig.$x.$y.ark
      [ -L $file ] && rm $(readlink -f $file)
      rm $file
      file=$dir/unsup/egs_orig.$x.$y.ark
      [ -L $file ] && rm $(readlink -f $file)
      rm $file
      for (( i=0; i<supervised_copies; i++ )); do
        file=$dir/sup/egs_orig.$x.$i.$y.ark
        [ -L $file ] && rm $(readlink -f $file)
        rm $file
      done
    done
  done
fi

echo "$0: Finished preparing training examples"
