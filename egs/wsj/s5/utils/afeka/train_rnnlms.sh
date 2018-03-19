#!/bin/bash
# Modified by Ella Erlich

# Copyright 2012  Johns Hopkins University (author: Daniel Povey)  Tony Robinson
#           2015  Guoguo Chen

# This script takes no command-line arguments but takes the --cmd option.

# Begin configuration section.
cmd=run.pl

rand_seed=0
nwords=10000           # This is how many words we're putting in the vocab of the RNNLM. - 10k most frequent words.
hidden=30             # For less than 1M words, 50-200 neurons is usually enough, for 1M-10M words use 200-300
                       # (using larger hidden layer usually does not degrade the performance, but makes the training progress slower)
class=200              # Num-classes... should be somewhat larger than sqrt of nwords.
                       # will use N classes to speed up training progress
direct=1000            # Number of weights that are used for "direct" connections, in millions.
rnnlm_ver=rnnlm-0.3e   # version of RNNLM to use
threads=1              # for RNNLM-HS
bptt=2                 # length of BPTT unfolding in RNNLM
bptt_block=20          # length of BPTT unfolding in RNNLM
rnnlm_options="-direct-order 4"
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 3 ]; then
   echo "Usage: $(basename $0) [options] <lm-text> <lexicon> <rnn-dir>"
   echo "e.g.: $(basename $0)  data/lang_test/rnn"
   echo "Options:"
   echo "For options, see top of script file"
   exit 1;
fi

lm_text=$1
lexicon=$2
rnn_dir=$3

if [ ! -d $rnn_dir ]; then
  mkdir -p $rnn_dir
fi

$KALDI_ROOT/tools/extras/check_for_rnnlm.sh "$rnnlm_ver" || exit 1
export PATH=$KALDI_ROOT/tools/$rnnlm_ver:$PATH

for f in $lm_text $lexicon; do
  [ ! -f $f ] && echo "Expecting file $f to exist" && exit 1;
done

cat $lexicon | awk '{print $1}' | grep -v -w '!SIL' > $rnn_dir/wordlist.all

# Get training data with OOV words (w.r.t. our current vocab) replaced with <unk>.
echo "Getting training data with OOV words replaced with <unk> (train_nounk.gz)" 
cat $lm_text | awk -v w=$rnn_dir/wordlist.all \
  'BEGIN{while((getline<w)>0) v[$1]=1;}
  {for (i=1;i<=NF;i++) if ($i in v) printf $i" ";else printf "<unk> ";print ""}'|sed 's/ $//g' \
  | gzip -c > $rnn_dir/all.gz

echo "Splitting data into train and validation sets."
heldout_sent=10000
gunzip -c $rnn_dir/all.gz | head -n $heldout_sent > $rnn_dir/valid.in # validation data
gunzip -c $rnn_dir/all.gz | tail -n +$heldout_sent | \
 perl -e ' use List::Util qw(shuffle); @A=<>; print join("", shuffle(@A)); ' \
  > $rnn_dir/train.in # training data

# The rest will consist of a word-class represented by <RNN_UNK>, that
# maps (with probabilities) to a whole class of words.

# Get unigram counts from our training data, and use this to select word-list
# for RNNLM training; e.g. 10k most frequent words.  Rest will go in a class
# that we (manually, at the shell level) assign probabilities for words that
# are in that class.  Note: this word-list doesn't need to include </s>; this
# automatically gets added inside the rnnlm program.
# Note: by concatenating with $rnn_dir/wordlist.all, we are doing add-one
# smoothing of the counts.

cat $rnn_dir/train.in $rnn_dir/wordlist.all | grep -v '</s>' | grep -v '<s>' | \
  awk '{ for(x=1;x<=NF;x++) count[$x]++; } END{for(w in count){print count[w], w;}}' | \
  sort -nr > $rnn_dir/unigram.counts

head -$nwords $rnn_dir/unigram.counts | awk '{print $2}' > $rnn_dir/wordlist.rnn

tail -n +$nwords $rnn_dir/unigram.counts > $rnn_dir/unk_class.counts

tot=`awk '{x=x+$1} END{print x}' $rnn_dir/unk_class.counts`
awk -v tot=$tot '{print $2, ($1*1.0/tot);}' <$rnn_dir/unk_class.counts  >$rnn_dir/unk.probs

for type in train valid; do
  cat $rnn_dir/$type.in | awk -v w=$rnn_dir/wordlist.rnn \
    'BEGIN{while((getline<w)>0) v[$1]=1;}
    {for (i=1;i<=NF;i++) if ($i in v) printf $i" ";else printf "<RNN_UNK> ";print ""}'|sed 's/ $//g' \
    > $rnn_dir/$type
done

rm $rnn_dir/train.in # no longer needed, and big.

# Now randomize the order of the training data.
cat $rnn_dir/train | awk -v rand_seed=$rand_seed 'BEGIN{srand(rand_seed);} {printf("%f\t%s\n", rand(), $0);}' | \
 sort | cut -f 2 > $rnn_dir/foo
mv $rnn_dir/foo $rnn_dir/train

echo "Training RNNLM (note: this uses a lot of memory! Run it on a big machine.)"

# since the mikolov rnnlm and faster-rnnlm have slightly different interfaces...
if [ "$rnnlm_ver" == "faster-rnnlm" ]; then
  $cmd $rnn_dir/rnnlm.log \
    $KALDI_ROOT/tools/$rnnlm_ver/rnnlm -threads $threads -train $rnn_dir/train -valid $rnn_dir/valid \
    -rnnlm $rnn_dir/rnnlm -hidden $hidden -seed 1 -bptt $bptt -bptt-block $bptt_block \
    $rnnlm_options -direct $direct || exit 1;
else
  #'-debug 2' switch will cause the training progress to be shown on the screen interactively
  
  $cmd $rnn_dir/rnnlm.log \
    $KALDI_ROOT/tools/$rnnlm_ver/rnnlm -threads $threads -independent -train $rnn_dir/train -valid $rnn_dir/valid \
    -rnnlm $rnn_dir/rnnlm -hidden $hidden -rand-seed 1 -debug 2 -class $class -bptt $bptt -bptt-block $bptt_block \
    $rnnlm_options -direct $direct -binary || exit 1;
fi

# make it like a Kaldi table format, with fake utterance-ids.
cat $rnn_dir/valid.in | awk '{ printf("uttid-%d ", NR); print; }' > $rnn_dir/valid.with_ids

utils/rnnlm_compute_scores.sh --ensure_normalized_probs true --rnnlm_ver $rnnlm_ver $rnn_dir $rnn_dir/tmp.valid $rnn_dir/valid.with_ids \
  $rnn_dir/valid.scores
nw=`cat $rnn_dir/valid.with_ids | awk '{a+=NF}END{print a}'` # Note: valid.with_ids includes utterance-ids which
  # is one per word, to account for the </s> at the end of each sentence; this is the
  # correct number to normalize buy.
p=`awk -v nw=$nw '{x=x+$2} END{print exp(x/nw);}' <$rnn_dir/valid.scores` 
echo Perplexity is $p | tee $rnn_dir/perplexity.log

rm $rnn_dir/train $rnn_dir/all.gz

exit 0;