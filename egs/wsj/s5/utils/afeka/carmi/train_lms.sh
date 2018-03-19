#!/bin/bash

# Begin configuration section.
heldout_sent=10000
run_prune=false
threshold_prune=10.0
clean_oov=false
remove_unk_segments=false
lmtype=3gram-mincount
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

# Parse options.
for n in `seq 2`; do
  if [ "$1" == "--heldout_sent" ]; then
    shift
    heldout_sent=$1
    shift
  fi
  if [ "$1" == "--clean_oov" ]; then
    shift
    clean_oov=$1
    shift
  fi
  if [ "$1" == "--remove_unk_segments" ]; then
    shift
    remove_unk_segments=$1
    shift
  fi
  if [ "$1" == "--lmtype" ]; then
    shift
    lmtype=$1
    shift
  fi
  if [ "$1" == "--threshold_prune" ]; then
    shift
    threshold_prune=$1
    run_prune=true
    echo "run_prune: $run_prune threshold_prune $threshold_prune"
    shift
  fi
done

if [ $# -ne 5 ]; then
  echo "Usage: $(basename $0) [options] <lm-text> <lexicon-file> <words-file> <out-lang-dir> <start-index>"
  echo "e.g.: $(basename $0) data/train/text data/local/dict/lexicon.txt data/lang/words.txt data/lang_test 1"
  echo "Options:"
  echo "main options (for others, see top of script file)"
  echo "--clean-oov             # e.g. default false"
  echo "--remove-unk-segments   # e.g. default false"
  exit 1;
fi

lm_text=$1 #data/train/text
lexicon=$2 #data/local/dict/lexicon.txt 
words_file=$3 #$lang_dir/words.txt 
lang_out_dir=$4 #$data/lang_test
start_index=$5

devtext=data/dev/text

mkdir -p $lang_out_dir

text=$lang_out_dir/lm_text
arpa_lm=$lang_out_dir/lm.gz

cat $lm_text > $text

if [[ ! -f $arpa_lm || $arpa_lm -ot $text ]]; then
  echo "--------------------------------------------------------------------------------"
  echo "Building an LM language model - using train_lm.sh --arpa --lmtype 3gram-mincount"
  echo "--------------------------------------------------------------------------------"

  export PATH=$PATH:`pwd`/../../../tools/kaldi_lm
  ( # First make sure the kaldi_lm toolkit is installed.
  cd ../../../../tools || exit 1;
  if [ -d kaldi_lm ]; then
    echo Not installing the kaldi_lm toolkit since it is already there.
  else
    echo Downloading and installing the kaldi_lm tools
    if [ ! -f kaldi_lm.tar.gz ]; then
      wget http://www.danielpovey.com/files/kaldi/kaldi_lm.tar.gz || exit 1;
    fi
    tar -xvzf kaldi_lm.tar.gz || exit 1;
    cd kaldi_lm
    make || exit 1;
    echo Done making the kaldi_lm tools
  fi
  ) || exit 1;

  echo "Using words file: $words_file"
  echo "Using train text: $lm_text"

  for f in $words_file $lm_text; do
    [ ! -s $f ] && echo "No such file $f" && exit 1;
  done

  cleantext=$lang_out_dir/lm_text.no_oov

  if [ $start_index -eq 1 ]; then
    cat $lm_text | awk -v lex=$lexicon 'BEGIN{while((getline<lex) >0){ seen[$1]=1; } } 
      {for(n=1; n<=NF;n++) {  if (seen[$n]) { printf("%s ", $n); } else {printf("<unk> ");} } printf("\n");}' \
      > $cleantext || exit 1;
   else #note: ignore 1st field of train.txt, it's the utterance-id.
     cat $lm_text | awk -v lex=$lexicon 'BEGIN{while((getline<lex) >0){ seen[$1]=1; } } 
     {for(n=2; n<=NF;n++) {  if (seen[$n]) { printf("%s ", $n); } else {printf("<unk> ");} } printf("\n");}' \
     > $cleantext || exit 1;
  fi

  if $remove_unk_segments ; then
    echo "Remove all segments with <unk>"
    #Remove all segments with "<unk>" symbol
    grep -v "<unk>" $cleantext > ${cleantext}_temp && mv ${cleantext}_temp $cleantext
  fi

  if $clean_oov ; then
    echo "Delete all <unk> terms"
    sed 's/<unk>//g' $cleantext > $lang_out_dir/text.no_unk
    cat $lang_out_dir/text.no_unk > $cleantext
  fi

  echo "Cleantext Ready"
  
  if [ $start_index -eq 1 ]; then
    cat $cleantext | awk '{for(n=1;n<=NF;n++) print $n; }' | sort | uniq -c | \
     sort -nr > $lang_out_dir/word.counts || exit 1;
  else #note: ignore 1st field of train.txt, it's the utterance-id.
    cat $cleantext | awk '{for(n=2;n<=NF;n++) print $n; }' | sort | uniq -c | \
     sort -nr > $lang_out_dir/word.counts || exit 1;
  fi
  
  # Get counts from acoustic training transcripts, and add  one-count
  # for each word in the lexicon (but not silence, we don't want it
  # in the LM-- we'll add it optionally later).
  if [ $start_index -eq 1 ]; then
    cat $cleantext | awk '{for(n=1;n<=NF;n++) print $n; }' | \
     cat - <(grep -w -v '!SIL' $lexicon | awk '{print $1}') | \
     sort | uniq -c | sort -nr > $lang_out_dir/unigram.counts || exit 1;
  else #note: ignore 1st field of train.txt, it's the utterance-id.
    cat $cleantext | awk '{for(n=2;n<=NF;n++) print $n; }' | \
     cat - <(grep -w -v '!SIL' $lexicon | awk '{print $1}') | \
     sort | uniq -c | sort -nr > $lang_out_dir/unigram.counts || exit 1;
  fi

  # note: we probably won't really make use of <unk> as there aren't any OOVs
  cat $lang_out_dir/unigram.counts  | awk '{print $2}' | get_word_map.pl "<s>" "</s>" "<unk>" > $lang_out_dir/word_map || exit 1;

  if [ $start_index -eq 1 ]; then
    cat $cleantext | awk -v wmap=$lang_out_dir/word_map 'BEGIN{while((getline<wmap)>0)map[$1]=$2;}
     { for(n=1;n<=NF;n++) { printf map[$n]; if(n<NF){ printf " "; } else { print ""; }}}' | gzip -c >$lang_out_dir/train.gz || exit 1;
  else #note: ignore 1st field of train.txt, it's the utterance-id.
    cat $cleantext | awk -v wmap=$lang_out_dir/word_map 'BEGIN{while((getline<wmap)>0)map[$1]=$2;}
     { for(n=2;n<=NF;n++) { printf map[$n]; if(n<NF){ printf " "; } else { print ""; }}}' | gzip -c >$lang_out_dir/train.gz || exit 1;
  fi
  
  if $run_prune ; then
    echo "kaldi_train_lm using threshold_prune: $threshold_prune"
    utils/afeka/kaldi_train_lm.sh --heldout_sent $heldout_sent --threshold_prune $threshold_prune --arpa --lmtype $lmtype $lang_out_dir || exit 1;
    # note: output is
    cp $lang_out_dir/$lmtype/lm_pr$threshold_prune.gz $arpa_lm
  else
    echo "kaldi_train_lm"
    utils/afeka/kaldi_train_lm.sh --heldout_sent $heldout_sent --arpa --lmtype $lmtype $lang_out_dir || exit 1;
    # note: output is
    cp $lang_out_dir/$lmtype/lm_unpruned.gz $arpa_lm
  fi
fi

if [[ ! -f $lang_out_dir/G.fst || $lang_out_dir/G.fst -ot $arpa_lm ]]; then
  echo ---------------------------------------------------------------------
  echo "Creating G.fst on " `date`
  echo ---------------------------------------------------------------------
  # grep -v '<s> <s>' etc. is only for future-proofing this script.  Our
  # LM doesn't have these "invalid combinations".  These can cause 
  # determinization failures of CLG [ends up being epsilon cycles].
  # Note: remove_oovs.pl takes a list of words in the LM that aren't in
  # our word list.  Since our LM doesn't have any, we just give it
  # /dev/null [we leave it in the script to show how you'd do it].
  gunzip -c "$arpa_lm" | \
     grep -v '<s> <s>' | \
     grep -v '</s> <s>' | \
     grep -v '</s> </s>' | \
     arpa2fst - | fstprint | \
     utils/remove_oovs.pl $lang_out_dir/oov.txt | \
     utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$words_file \
       --osymbols=$words_file --keep_isymbols=false --keep_osymbols=false | \
        fstrmepsilon > $lang_out_dir/G.fst

  echo "Performing further checks:"

  echo "Checking that G.fst is determinizable"
  fstdeterminize $lang_out_dir/G.fst /dev/null || echo Error determinizing G.

  echo "Checking that L_disambig.fst is determinizable"
  fstdeterminize $lang_out_dir/L_disambig.fst /dev/null || echo Error determinizing L.

  echo "Checking that disambiguated lexicon times G is determinizable"
  # Note: we do this with fstdeterminizestar not fstdeterminize, as
  # fstdeterminize was taking forever (presumbaly relates to a bug
  # in this version of OpenFst that makes determinization slow for
  # some case).  //
  fsttablecompose $lang_out_dir/L_disambig.fst $lang_out_dir/G.fst | \
     fstdeterminizestar --use-log=true >/dev/null || echo Error

  echo "Checking that LG is stochastic"
  fsttablecompose $lang_out_dir/L_disambig.fst $lang_out_dir/G.fst | \
    fstisstochastic || echo "[log:] LG is not stochastic"
fi

exit 0;
