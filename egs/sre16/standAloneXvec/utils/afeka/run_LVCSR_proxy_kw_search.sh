#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.
cmd=run.pl
model= # You canecify the model to use
language=""
lmwt=1.0

beam=-1             # Beam for proxy FST, -1 means no prune
phone_beam=-1       # Beam for KxL2xE FST, -1 means no prune
nbest=-1            # Use top n best proxy keywords in proxy FST, -1 means all proxies
phone_nbest=50      # Use top n best phone sequences in KxL2xE, -1 means all phone sequences
phone_cutoff=5      # We don't generate proxy keywords for OOV keywords that
                    # have less phones than the specified cutoff as they may introduce a lot false alarms
pron_probs=false    # If true, then lexicon looks like:
                    # Word Prob Phone1 Phone2...
confusion_matrix=   # If supplied, using corresponding E transducer
count_cutoff=1      # Minimal count to be considered in the confusion matrix;
                    # will ignore phone pairs that have count less than this.
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $(basename $0) [options] <data-dir> <data-lang> <decode-dir>"
  echo "e.g.: $(basename $0) data/dev data/lang_test exp/tri3/decode_dev"
  echo "Options:"
  echo "main options (for others, see top of script file)"
  echo "--cmd (run.pl|queue.pl...)  # specify how to run the sub-processes."
  echo "--language                  # language type (string,  default = "")"
  echo "--lmwt                      # lm scale used for *.lat (default 1.0)"
  echo "--model                     # which model to use"
  echo "--confusion-matrix          # phone confusion matrix"
  exit 1;
fi

data_dir=$1
data_lang=$2
decode_dir=$3

ecf_file=$data_dir/ecf.xml

srcdir=`dirname $decode_dir`; # The model directory is one level up from decoding directory.

if [ -z "$model" ]; then # if --model <mdl> was notecified on the command line...
  model=$srcdir/final.mdl
fi

if [ -z "$confusion_matrix" ]; then # if --model <mdl> was notecified on the command line...
  confusion_matrix=$srcdir/conf_matrix/confusions.txt
fi

nj=`cat $decode_dir/num_jobs` || exit 1;

kwsdatadir=$data_dir/kw
kwsdatadir_proxy=$data_dir/kw_proxy

mkdir -p $kwsdatadir_proxy/tmp

l1_lexicon=$data_lang/lexiconp.txt
l2_lexicon=$kwsdatadir/oov_words.dict.final

# Checks some files.
for f in $ecf_file $model $confusion_matrix $l1_lexicon $l2_lexicon $data_lang/words.txt; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1
done

cp $data_lang/words.txt $kwsdatadir_proxy/words.txt
cat $l1_lexicon | sed 's/\s/ /g' > $kwsdatadir_proxy/tmp/L1.tmp.lex

perl -ape 's/(\S+\s+)(.+)/${1}1.0\t$2/;' < $l2_lexicon > $kwsdatadir_proxy/tmp/L2.tmp.lex

perl -ane '@A=split(" ",$_); $w = shift @A; $p = shift @A; @A>0||die;
  if(@A==1) { print "$w $p $A[0]_S\n"; } else { print "$w $p $A[0]_B ";
  for($n=1;$n<@A-1;$n++) { print "$A[$n]_I "; } print "$A[$n]_E\n"; } ' \
  < $kwsdatadir_proxy/tmp/L2.tmp.lex > $kwsdatadir_proxy/tmp/L2.original.lex || exit 1;
  
mv $kwsdatadir_proxy/tmp/L2.original.lex $kwsdatadir_proxy/tmp/L2.tmp.lex

cat $kwsdatadir/keywords_all.int |\
  (grep -E " 0 | 0$" || true) | awk '{print $1;}' | sort -u > $kwsdatadir_proxy/keywords_proxy.list #only OOV

#cat $kwsdatadir/keywords_all.int | awk '{print $1;}' | sort -u > $kwsdatadir_proxy/keywords_proxy.list

cat $kwsdatadir/keywords.txt |\
  grep -f $kwsdatadir_proxy/keywords_proxy.list > $kwsdatadir_proxy/keywords_proxy.txt
cat $kwsdatadir_proxy/keywords_proxy.txt |\
  cut -f 2- | awk '{for(x=1;x<=NF;x++) {print $x;}}' |\
  sort -u > $kwsdatadir_proxy/keywords_proxy_words.list

# Maps original phone set to a "reduced" phone set. We limit L2 to only cover
# the words that are actually used in keywords_proxy.txt for efficiency purpose.
# Besides, if L1 and L2 contains the same words, we use the pronunciation from
# L1 since it is the lexicon used for the LVCSR training.
cat $kwsdatadir_proxy/tmp/L1.tmp.lex | cut -d ' ' -f 1 |\
  paste -d ' ' - <(cat $kwsdatadir_proxy/tmp/L1.tmp.lex | cut -d ' ' -f 2-|\
  sed 's/_[B|E|I|S]//g' | sed 's/_[%|"]//g' | sed 's/_[0-9]\+//g') |\
  awk '{if(NF>=2) {print $0}}' > $kwsdatadir_proxy/tmp/L1.lex
cat $kwsdatadir_proxy/tmp/L2.tmp.lex | cut -d ' ' -f 1 |\
  paste -d ' ' - <(cat $kwsdatadir_proxy/tmp/L2.tmp.lex | cut -d ' ' -f 2-|\
  sed 's/_[B|E|I|S]//g' | sed 's/_[%|"]//g' | sed 's/_[0-9]\+//g') |\
  awk '{if(NF>=2) {print $0}}' | perl -e '
  ($lex1, $words) = @ARGV;
  open(L, "<$lex1") || die "Fail to open $lex1.\n";
  open(W, "<$words") || die "Fail to open $words.\n";
  while (<L>) {
    chomp;
    @col = split;
    @col >= 2 || die "Too few columsn in \"$_\".\n";
    $w = $col[0];
    $w_p = $_;
    if (defined($lex1{$w})) {
      push(@{$lex1{$w}}, $w_p);
    } else {
      $lex1{$w} = [$w_p];
    }
  }
  close(L);
  while (<STDIN>) {
    chomp;
    @col = split;
    @col >= 2 || die "Too few columsn in \"$_\".\n";
    $w = $col[0];
    $w_p = $_;
    if (defined($lex1{$w})) {
      next;
    }
    if (defined($lex2{$w})) {
      push(@{$lex2{$w}}, $w_p);
    } else {
      $lex2{$w} = [$w_p];
    }
  }
  %lex = (%lex1, %lex2);
  while (<W>) {
    chomp;
    if (defined($lex{$_})) {
      foreach $x (@{$lex{$_}}) {
        print "$x\n";
      }
    }
  }
  close(W);
  ' $kwsdatadir_proxy/tmp/L1.lex $kwsdatadir_proxy/keywords_proxy_words.list \
  > $kwsdatadir_proxy/tmp/L2.lex
rm -f $kwsdatadir_proxy/tmp/L1.tmp.lex $kwsdatadir_proxy/tmp/L2.tmp.lex

# Creates words.txt that covers all the words in L1.lex and L2.lex. We append
# new words to the original word symbol table.
max_id=`cat $kwsdatadir_proxy/words.txt | awk '{print $2}' | sort -n | tail -1`;
cat $kwsdatadir_proxy/keywords_proxy.txt |\
  awk '{for(i=2; i <= NF; i++) {print $i;}}' |\
  cat - <(cat $kwsdatadir_proxy/tmp/L2.lex | awk '{print $1;}') |\
  cat - <(cat $kwsdatadir_proxy/tmp/L1.lex | awk '{print $1;}') |\
  sort -u | \
  (grep -F -v -x -f <(cat $kwsdatadir_proxy/words.txt | awk '{print $1;}') || true)|\
  awk 'BEGIN{x='$max_id'+1}{print $0"\t"x; x++;}' |\
  cat $kwsdatadir_proxy/words.txt - > $kwsdatadir_proxy/tmp/words.txt

# Creates keyword list that we need to generate proxies for.
cat $kwsdatadir_proxy/keywords_proxy.txt | perl -e '
  open(W, "<'$kwsdatadir_proxy/tmp/L2.lex'") ||
    die "Fail to open L2 lexicon: '$kwsdatadir_proxy/tmp/L2.lex'\n";
  my %lexicon;
  while (<W>) {
    chomp;
    my @col = split();
    @col >= 2 || die "'$0': Bad line in lexicon: $_\n";
    if ('$pron_probs' eq "false") {
      $lexicon{$col[0]} = scalar(@col)-1;
    } else {
      $lexicon{$col[0]} = scalar(@col)-2;
    }
  }
  while (<>) {
    chomp;
    my $line = $_;
    my @col = split();
    @col >= 2 || die "Bad line in keywords file: $_\n";
    my $len = 0;
    for (my $i = 1; $i < scalar(@col); $i ++) {
      if (defined($lexicon{$col[$i]})) {
        $len += $lexicon{$col[$i]};
      } else {
        print STEDRR "'$0': No pronunciation found for word: $col[$i]\n";
      }
    }
    if ($len >= '$phone_cutoff') {
      print "$line\n";
    } else {
      print STDERR "'$0': Keyword $col[0] is too short, not generating proxy\n";
    }
  }' > $kwsdatadir_proxy/tmp/keywords.txt

# Creates proxy keywords.
utils/afeka/kws/generate_proxy_keywords.sh \
  --cmd "$cmd" --nj "$nj" --beam "$beam" --nbest "$nbest" \
  --phone-beam $phone_beam --phone-nbest $phone_nbest \
  --confusion-matrix "$confusion_matrix" --count-cutoff "$count_cutoff" \
  --pron-probs "$pron_probs" $kwsdatadir_proxy/tmp/
cp $kwsdatadir_proxy/tmp/keywords.fsts $kwsdatadir_proxy

# Creates utterance id for each utterance.
cat $data_dir/segments | \
  awk '{print $1}' | \
  sort | uniq | perl -e '
  $idx=1;
  while(<>) {
    chomp;
    print "$_ $idx\n";
    $idx++;
  }' > $kwsdatadir_proxy/utter_id

# Map utterance to the names that will appear in the rttm file. You have 
# to modify the commands below accoring to your rttm file
cat $data_dir/segments | awk '{print $1" "$2}' |\
  sort | uniq > $kwsdatadir_proxy/utter_map;

echo "$0: Kws proxy data preparation succeeded"

duration=`head -1 $ecf_file |\
  grep -o -E "duration=\"[0-9]*[    \.]*[0-9]*\"" |\
  perl -e 'while($m=<>) {$m=~s/.*\"([0-9.]+)\".*/\1/; print $m/2;}'`

kwsoutdir=$decode_dir/lm_$lmwt/kws_proxy
indices=$kwsoutdir/indices

acwt=`echo "scale=5; 1/$lmwt" | bc -l | sed "s/^./0./g"` 

max_states=150000
word_ins_penalty=0
max_silence_frames=50
ntrue_scale=1.0
duptime=0.6

if [ -f $srcdir/frame_shift ]; then
  shift=$(cat $srcdir/frame_shift) || exit 1
  factor=$(($shift / 0.01))
  frame_subsampling_opt="--frame-subsampling-factor $factor"
  echo "$srcdir/frame_shift exists, using $frame_subsampling_opt"
elif [ -f $srcdir/frame_subsampling_factor ]; then
  factor=$(cat $srcdir/frame_subsampling_factor) || exit 1
  frame_subsampling_opt="--frame-subsampling-factor $factor"
  echo "$srcdir/frame_subsampling_factor exists, using $frame_subsampling_opt"
fi

steps/make_index.sh --cmd "$decode_cmd" --acwt $acwt --model $model --skip-optimization true --max-states $max_states \
  --word-ins-penalty $word_ins_penalty --max-silence-frames $max_silence_frames $kwsdatadir_proxy $data_lang $decode_dir $indices  || exit 1

#  --strict false
utils/afeka/kws/search_index.sh --cmd "$decode_cmd" --strict false $frame_subsampling_opt --indices-dir $indices $kwsdatadir_proxy $kwsoutdir || exit 1;
segments_opts=
if [ -f $data_dir/segments ]; then
  segments_opts="--segments=$data_dir/segments"
fi

$cmd LMWT=$lmwt:$lmwt $kwsoutdir/write_normalized.LMWT.log \
  set -e ';' set -o pipefail ';'\
  cat ${kwsoutdir}/result.* \| \
    utils/afeka/kws/write_kwslist.pl --language=$language --Ntrue-scale=$ntrue_scale --flen=0.01 --duration=$duration \
      $segments_opts --normalize=true --duptime=$duptime --remove-dup=true\
      --map-utter=$kwsdatadir_proxy/utter_map --reco2fc=$data_dir/reco2file_and_channel --digits=3 \
      - ${kwsoutdir}/kwslist_norm.xml || exit 1;

awk -f utils/afeka/kws/fix_kwslist.awk $kwsdatadir/kwlist.xml ${kwsoutdir}/kwslist_norm.xml > ${kwsoutdir}/kwslist.xml

exit 0;
