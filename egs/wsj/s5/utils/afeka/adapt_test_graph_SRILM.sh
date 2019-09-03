#!/bin/bash
# Author: Ella Erlich

[ -f cmd.sh ] && . ./cmd.sh
[ -f path.sh ] && . ./path.sh
set -e

# Begin configuration section.
stage=1
default_dict=local/default.dict
start_field=2 # 1 without segment ID
dev_portion=10
ngram_order=3
model_dir=
self_loop_scale=1.0
out_dir=
# end configuration sections

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

if [ $# -ne 6 ]; then
  echo "Usage: $(basename $0) <src-lang-dir> <src-dict-dir> <orig-arpa> <lex-file> <text-file> <lm-name>"
  echo "e.g.: $(basename $0) data/lang data/local/dict lm.arpa.gz lexicon.dict data/train/text test"
  echo "Options:"
  echo "main options (for others, see top of script file)"
  echo "--start-field        # text start field (default 2, with utt ID)"
  echo "--dev-portion        # percent data for dev (default 10)"
  echo "--ngram-order        # ngram order (default 3)"
  echo "--model-dir          # acoustic model dir (creates graph_dir)"
  echo "--self-loop-scale    # scale for mkgraph (default 1.0 - fmllr need 0.1)"
  exit 1;
fi

src_lang_dir=$1
src_dict_dir=$2
orig_lm=$3
lex=$4
text=$5
lang_name=$6

lang_out=data/lang_$lang_name
if [ -n "$out_dir" ]; then lang_out=$out_dir ; fi

dict_dir=$lang_out/dict
data=$lang_out/data

lexicon=$dict_dir/lexicon.txt
words=$lang_out/words.txt
vocab=$lang_out/vocab
train_text=$data/train.gz
dev_text=$data/dev.gz

get_seeded_random()
{
  seed="$1"
  openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt </dev/zero 2>/dev/null
}

for f in "$default_dict $lex $orig_lm $text" ; do
  [ ! -f $f ] && echo "$0: No such file $f" && exit 1;
done

if [ $stage -le 1 ]; then
  echo "--------------------------------------------------------------------------------"
  echo "Prepare lang dir - $lang_out on " `date`
  echo "--------------------------------------------------------------------------------"

  [ ! -d $lang_dir ] && mkdir -p $lang_dir
  [ ! -d $dict_dir ] && mkdir -p $dict_dir

  cat $default_dict | sed -e "s#\t# #g" > $dict_dir/default.dict
  cat $lex | sed -e "s#\t# #g" | sort -u > $lexicon.temp

  cp $dict_dir/default.dict $lexicon
  #awk "BEGIN { while ((getline < \"$dict_dir/default.dict\")>0) lex[\$2] = 1} { if (! (\$2 in lex)) print \$0 }" $lexicon.temp >> $lexicon
  awk "BEGIN { while ((getline < \"$dict_dir/default.dict\")>0) lex[\$1] = 1} { if (! (\$1 in lex)) print \$0 }" $lexicon.temp >> $lexicon

  cp $src_dict_dir/extra_questions.txt $dict_dir/extra_questions.txt
  cp $src_dict_dir/silence_phones.txt $dict_dir/silence_phones.txt
  cp $src_dict_dir/optional_silence.txt $dict_dir/optional_silence.txt
  cp $src_dict_dir/nonsilence_phones.txt $dict_dir/nonsilence_phones.txt
  if [ -f $src_dict_dir/silprob.txt ]; then
    cp $src_dict_dir/silprob.txt $dict_dir/silprob.txt
  fi

  utils/prepare_lang.sh --phone-symbol-table $src_lang_dir/phones.txt \
    $dict_dir "<unk>" $lang_out $lang_out || exit 1;
fi

arpa_lm=$lang_out/lm.arpa.gz  # note: output is $arpa_lm

if [ $stage -le 2 ]; then
  if [ ! -f $arpa_lm ]; then
    [ ! -d $data ] && mkdir -p $data
    echo "-------------------------------------"
    echo "Building an SRILM language model - ${ngram_order}gram on " `date`
    echo "-------------------------------------"
    loc=`which ngram-count`;
    if [ -z $loc ]; then
      if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
        sdir=`pwd`/../../../tools/srilm/bin/i686-m64 
      else
        sdir=`pwd`/../../../tools/srilm/bin/i686
      fi
      if [ -f $sdir/ngram-count ]; then
        echo Using SRILM tools from $sdir
        export PATH=$PATH:$sdir
      else
        echo You appear to not have SRILM tools installed, either on your path,
        echo or installed in $sdir.  See tools/install_srilm.sh for installation
        echo instructions.
        exit 1
      fi
    fi

    cp $orig_lm $data/orig.arpa.gz

    cut -d' ' -f1 $lexicon | grep -v '\#0' | grep -v '<eps>' | uniq > $vocab
    cat $text | cut -d ' ' -f $start_field- > $data/text.orig
    cat $data/text.orig | awk -v lex=$lexicon 'BEGIN{while((getline<lex) >0){ seen[$1]=1; } } 
      {for(n=1; n<=NF;n++) { if (seen[$n]) { printf("%s ", $n); } else {printf("<unk> ");} } printf("\n");}' \
      > $data/lm_text || exit 1;

    cat $data/lm_text | shuf --random-source=<(get_seeded_random 17) > $data/text.shuf
    num_lines=$(cat $data/text.shuf | wc -l)
    num_dev=$(($dev_portion * $num_lines / 100))
    num_train=$(($num_lines - $num_dev))
    head -n $num_dev $data/text.shuf | gzip > $dev_text
    tail -n $num_train $data/text.shuf | gzip > $train_text
    rm $data/text.shuf

    echo "Training $ngram_order gram LM using $train_text..."
    ngram-count -text $train_text -order $ngram_order -limit-vocab -vocab $vocab \
      -unk -map-unk "<unk>" -kndiscount -interpolate -lm $arpa_lm
    [ ! -f $lang_out/lm.arpa.gz ] && echo "Failed to create LM" && exit 1;

    echo "Computing perplexity using LM from training data:"
    ngram -unk -lm $arpa_lm -ppl $dev_text
    ngram -unk -lm $arpa_lm -ppl $dev_text -debug 2 >& $lang_out/${ngram_order}gram.ppl2
  
    echo "Computing perplexity using original model pack LM:"
    ngram -order $ngram_order -unk -lm $orig_lm -ppl $dev_text
    ngram -order $ngram_order -unk -lm $orig_lm -ppl $dev_text -debug 2 >& $lang_out/orig_lm.ppl2

    echo "Computing best mixture"
    compute-best-mix $lang_out/${ngram_order}gram.ppl2 $lang_out/orig_lm.ppl2 >& $lang_out/lm_mix.log
  
    grep 'best lambda' $lang_out/lm_mix.log \
      | perl -e '$_=<>; s/.*\(//; s/\).*//; @A = split;
      die "Expecting 2 numbers; found: $_" if(@A != 2);
      print "$A[0]\n$A[1]\n";' > $lang_out/lm_mix.weights
    lm_weight=$(head -1 $lang_out/lm_mix.weights)
    orig_lm_weight=$(tail -n 1 $lang_out/lm_mix.weights)
  
    echo "Combining LM with weight $lm_weight on new trainig data"
    ngram -order $ngram_order -lm $arpa_lm -lambda $lm_weight \
      -mix-lm $orig_lm -unk -write-lm $lang_out/mix.arpa.gz

    echo "PPL for the interolated LM:"
      ngram -unk -lm $lang_out/mix.arpa.gz -ppl $dev_text
  fi

  if [[ ! -f $lang_out/G.fst || $lang_out/G.fst -ot $arpa_lm ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "Creating G.fst on " `date`
    echo "--------------------------------------------------------------------------------"

    gunzip -c "$arpa_lm" | arpa2fst --disambig-symbol=#0 \
     --read-symbol-table=$words - $lang_out/G.fst

    echo "Checking how stochastic G is (the first of these numbers should be small):"
    fstisstochastic $lang_out/G.fst || echo "[log:] G is not stochastic"

    # Check lexicon - just have a look and make sure it seems sane.
    echo "First few lines of lexicon FST:"
    fstprint --isymbols=$lang_out/phones.txt --osymbols=$words $lang_out/L.fst | head

    echo Performing further checks

    echo "Checking that G.fst is determinizable"
    fstdeterminize $lang_out/G.fst /dev/null || echo Error determinizing G.

    echo "Checking that L_disambig.fst is determinizable"
    fstdeterminize $lang_out/L_disambig.fst /dev/null || echo Error determinizing L.

    echo "Checking that disambiguated lexicon times G is determinizable"
    # Note: we do this with fstdeterminizestar not fstdeterminize, as
    # fstdeterminize was taking forever (presumbaly relates to a bug
    # in this version of OpenFst that makes determinization slow for
    # some case).
    fsttablecompose $lang_out/L_disambig.fst $lang_out/G.fst | \
     fstdeterminizestar --use-log=true >/dev/null || echo Error

    echo "Checking that LG is stochastic"
    fsttablecompose $lang_out/L_disambig.fst $lang_out/G.fst | \
    fstisstochastic || echo "[log:] LG is not stochastic"
  fi
fi

if [ $stage -le 3 ]; then
  if [ ! -z $model_dir ]; then
    echo "--------------------------------------------------------------------------------"
    echo "Make Graph on " `date`
    echo "--------------------------------------------------------------------------------"

    graph_dir=$model_dir/graph_$lang_name
    if [ "$self_loop_scale" = "1.0" ]; then
      graph_dir=$model_dir/graph_selfloop_$lang_name
    fi

    if [ ! -f $graph_dir/.done ]; then
      utils/mkgraph.sh --self-loop-scale $self_loop_scale $lang_out $model_dir $graph_dir || exit 1;
      touch $graph_dir/.done
    fi
  fi
fi

echo "--------------------------------------------------------------------------------"
echo "End on " `date`
echo "--------------------------------------------------------------------------------"

exit 0;
