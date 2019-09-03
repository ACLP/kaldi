#!/bin/bash
# Author: Ella Erlich
# based swbd\s5c\local\swbd1_train_lms.sh

[ -f cmd.sh ] && . ./cmd.sh
[ -f path.sh ] && . ./path.sh
set -e

# Begin configuration section.
stage=-10
default_dict=local/default.dict
start_field=2 # 1 without segment ID, 2 with segment ID
dev_portion=10
heldout_sent=10000 #max utterances for validation
lm_tool=SRILM
ngram_order=3
gmm_dir=
model_dir=
self_loop_scale=1.0
text=
out_dir=
# end configuration sections

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) <src-lang-dir> <src-dict-dir> <lex-file> <lang-name>"
  echo "e.g.: $(basename $0) data/lang data/local/dict lexicon.dict test"
  echo "Options:"
  echo "main options (for others, see top of script file)"
  echo "--default-dict       # lexicon that append final lexicon"
  echo "--lm-tool            # build statistical language models ( default SRILM, other options: KALDILM, POCOLM)"
  echo "--start-field        # text start field ( default 2, with utt ID)"
  echo "--dev-portion        # percent data for dev (default 10)"
  echo "--ngram-order        # ngram order ( default 3)"
  echo "--text               # text-file "
  echo "--model-dir          # acoustic model dir (creates graph_dir)"
  echo "--self-loop-scale    # scale for mkgraph ( default 1.0 - fmllr need 0.1)"
  exit 1;
fi

src_lang_dir=$1
src_dict_dir=$2
lex=$3
lang_name=$4

lang_dir=data/lang_$lang_name
if [ -n "$out_dir" ]; then lang_dir=$out_dir ; fi

dict_nosp_dir=$lang_dir/dict_nosp
dict_dir=$lang_dir/dict

data=$lang_dir/data
words=$lang_dir/words.txt
vocab=$lang_dir/vocab
train_text=$data/train.gz
dev_text=$data/dev.gz

arpa_lm=$lang_dir/lm.arpa.gz  # note: output is $arpa_lm

get_seeded_random()
{
  seed="$1"
  openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt </dev/zero 2>/dev/null
}

if [ -f $arpa_lm ]; then
  touch $lang_dir/input.text
  text=$lang_dir/input.text
fi

for f in "$default_dict" "$lex" "$text" "$gmm_dir/pron_counts_nowb.txt" "$gmm_dir/sil_counts_nowb.txt" "$gmm_dir/pron_bigram_counts_nowb.txt"; do
  [ ! -f $f ] && echo "$0: No such file $f" && exit 1;
done

if [ $stage -le 1 ]; then
  echo "--------------------------------------------------------------------------------"
  echo "Prepare lang dir - $lang_dir on " `date`
  echo "--------------------------------------------------------------------------------"

  [ ! -d $lang_dir ] && mkdir -p $lang_dir
  [ ! -d $dict_nosp_dir ] && mkdir -p $dict_nosp_dir
  [ ! -d $dict_dir ] && mkdir -p $dict_dir

  cat $default_dict | sed -e "s#\t# #g" > $dict_nosp_dir/default.dict
  cat $lex | sed -e "s#\t# #g" | sort -u > $dict_nosp_dir/lexicon.txt.temp

  cp $dict_nosp_dir/default.dict $dict_nosp_dir/lexicon.txt
  #awk "BEGIN { while ((getline < \"$dict_nosp_dir/default.dict\")>0) lex[\$2] = 1} { if (! (\$2 in lex)) print \$0 }" $dict_nosp_dir/lexicon.txt.temp >> $dict_nosp_dir/lexicon.txt
  awk "BEGIN { while ((getline < \"$dict_nosp_dir/default.dict\")>0) lex[\$1] = 1} { if (! (\$1 in lex)) print \$0 }" $dict_nosp_dir/lexicon.txt.temp >> $dict_nosp_dir/lexicon.txt

  cp $src_dict_dir/extra_questions.txt $dict_nosp_dir/extra_questions.txt
  cp $src_dict_dir/silence_phones.txt $dict_nosp_dir/silence_phones.txt
  cp $src_dict_dir/optional_silence.txt $dict_nosp_dir/optional_silence.txt
  cp $src_dict_dir/nonsilence_phones.txt $dict_nosp_dir/nonsilence_phones.txt
  if [ -f $src_dict_dir/silprob.txt ]; then
    cp $src_dict_dir/silprob.txt $dict_nosp_dir/silprob.txt
  fi
  
  #adding pronunciation probability and sp (short silence) prob before and after a word
  utils/afeka/dict_dir_add_pronprobs.sh --max-normalize true \
    $dict_nosp_dir $gmm_dir/pron_counts_nowb.txt $gmm_dir/sil_counts_nowb.txt \
    $gmm_dir/pron_bigram_counts_nowb.txt $dict_dir || exit 1;
fi

lexicon=$dict_dir/lexicon.txt

if [ $stage -le 2 ]; then
  utils/prepare_lang.sh --phone-symbol-table $src_lang_dir/phones.txt \
    $dict_dir "<unk>" $lang_dir $lang_dir || exit 1;
fi

if [ $stage -le 3 ]; then
  if [ ! -f $arpa_lm ]; then
    [ ! -d $data ] && mkdir -p $data
    cut -d' ' -f1 $lexicon | grep -v '\#0' | grep -v '<eps>' | uniq > $vocab
    cat $text | cut -d ' ' -f $start_field- > $data/text.orig
    cat $data/text.orig | awk -v lex=$lexicon 'BEGIN{while((getline<lex) >0){ seen[$1]=1; } } 
      {for(n=1; n<=NF;n++) { if (seen[$n]) { printf("%s ", $n); } else {printf("<unk> ");} } printf("\n");}' \
      > $data/lm_text || exit 1;

    cat $data/lm_text | shuf --random-source=<(get_seeded_random 17) > $data/text.shuf
    num_lines=$(cat $data/text.shuf | wc -l)
    num_dev=$(($dev_portion * $num_lines / 100))
    if [ "$num_dev" -gt "$heldout_sent" ]; then
      num_dev=$heldout_sent
    fi
    num_train=$(($num_lines - $num_dev))
    head -n $num_dev $data/text.shuf | gzip > $dev_text
    tail -n $num_train $data/text.shuf | gzip > $train_text
    rm $data/text.shuf

    gunzip -c "$train_text" > $data/train.txt
    gunzip -c "$dev_text" > $data/dev.txt

    case $lm_tool in
    SRILM)
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
          echo You appear to not have SRILM tools installed, either on your path, or installed in $sdir.  
          echo See tools/install_srilm.sh for installation instructions.
          exit 1
        fi
      fi

      ngram-count -text $train_text -order $ngram_order -limit-vocab -vocab $vocab \
        -unk -map-unk "<unk>" -kndiscount -interpolate -lm $arpa_lm

      [ ! -f $arpa_lm ] && echo "Failed to create LM" && exit 1;

      echo "PPL for ${ngram_order}gram LM:"
      ngram unk -lm $arpa_lm -ppl $dev_text
      ngram -unk -lm $arpa_lm -ppl $dev_text -debug 2 >& $lang_dir/${ngram_order}gram.ppl2
      ;;
    POCOLM)
      echo "-------------------------------------"
      echo "Building an pocolm language model - ${ngram_order}gram on " `date`
      echo "-------------------------------------"
      export PATH=$KALDI_ROOT/tools/pocolm/scripts:$PATH
      ( # First make sure the toolkit is installed.
      cd $KALDI_ROOT/tools || exit 1;
      if [ -d pocolm ]; then
        echo Not installing the pocolm toolkit since it is already there.
      else
        echo "$0: Please install the PocoLM toolkit with: "
        echo " cd ../../../tools; extras/install_pocolm.sh; cd -"
        exit 1;
      fi
      ) || exit 1;

      mkdir -p ${data}_pocolm
      cp $data/{train,dev}.txt ${data}_pocolm
      # min_counts='train=2'
      # --min-counts="${min_counts}" \

      train_lm.py --wordlist=$vocab --num-splits=10 --warm-start-ratio=20 --limit-unk-history=true \
        ${data}_pocolm $ngram_order $lang_dir/work $lang_dir/pocolm

      format_arpa_lm.py $lang_dir/pocolm | gzip -c > $lang_dir/pocolm/${ngram_order}gram.arpa.gz
      get_data_prob.py $data/dev.txt $lang_dir/pocolm 2>&1 | grep -F '[perplexity' > $lang_dir/perplexity
      cp $lang_dir/pocolm/${ngram_order}gram.arpa.gz $arpa_lm
      [ ! -f $arpa_lm ] && echo "Failed to create LM" && exit 1;
      ;;
    KALDILM)
      ngram_type=${ngram_order}gram-mincount
      echo "--------------------------------------------------------------------------------"
      echo "Building an LM language model - using train_lm.sh --arpa --lmtype $ngram_type on " `date`
      echo "--------------------------------------------------------------------------------"
      export PATH=$KALDI_ROOT/tools/kaldi_lm:$PATH
      ( # First make sure the toolkit is installed.
      cd $KALDI_ROOT/tools || exit 1;
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

      cat $data/lm_text | awk '{for(n=1;n<=NF;n++) print $n; }' | \
      cat - <(grep -w -v '!SIL' $lexicon | awk '{print $1}') | \
      sort | uniq -c | sort -nr > $lang_dir/unigram.counts || exit 1;

      # note: we probably won't really make use of <unk> as there aren't any OOVs
      cat $lang_dir/unigram.counts | awk '{print $2}' | get_word_map.pl "<s>" "</s>" "<unk>" > $lang_dir/word_map || exit 1;

      cat $data/lm_text | awk -v wmap=$lang_dir/word_map 'BEGIN{while((getline<wmap)>0)map[$1]=$2;}
      { for(n=1;n<=NF;n++) { printf map[$n]; if(n<NF){ printf " "; } else { print ""; }}}' | gzip -c >$data/train.all.gz || exit 1;

      gunzip -c "$data/train.all.gz" | shuf --random-source=<(get_seeded_random 17) > $data/text.shuf
      num_lines=$(cat $data/text.shuf | wc -l)
      num_dev=$(($dev_portion * $num_lines / 100))
      if [ "$num_dev" -gt "$heldout_sent" ]; then
        num_dev=$heldout_sent
      fi
      num_train=$(($num_lines - $num_dev))
      head -n $num_dev $data/text.shuf | gzip > $dev_text
      tail -n $num_train $data/text.shuf | gzip > $train_text
      rm $data/text.shuf

      utils/afeka/kaldi_train_lm.sh --arpa --lmtype $ngram_type $data $lang_dir || exit 1;
      cp $lang_dir/$ngram_type/lm_unpruned.gz $arpa_lm
      [ ! -f $arpa_lm ] && echo "Failed to create LM" && exit 1;
      ;;
    *)
      echo Invalid --lm-tool option: $lm_tool
      exit 1
    ;;
    esac
  fi
fi

if [ $stage -le 3 ]; then
  if [[ ! -f $lang_dir/G.fst || $lang_dir/G.fst -ot $arpa_lm ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "Creating G.fst on " `date`
    echo "--------------------------------------------------------------------------------"

    gunzip -c "$arpa_lm" | arpa2fst --disambig-symbol=#0 \
     --read-symbol-table=$words - $lang_dir/G.fst

    echo "Checking how stochastic G is (the first of these numbers should be small):"
    fstisstochastic $lang_dir/G.fst || echo "[log:] G is not stochastic"

    # Check lexicon - just have a look and make sure it seems sane.
    echo "First few lines of lexicon FST:"
    fstprint --isymbols=$lang_dir/phones.txt --osymbols=$words $lang_dir/L.fst | head

    echo Performing further checks

    echo "Checking that G.fst is determinizable"
    fstdeterminize $lang_dir/G.fst /dev/null || echo Error determinizing G.

    echo "Checking that L_disambig.fst is determinizable"
    fstdeterminize $lang_dir/L_disambig.fst /dev/null || echo Error determinizing L.

    echo "Checking that disambiguated lexicon times G is determinizable"
    # Note: we do this with fstdeterminizestar not fstdeterminize, as
    # fstdeterminize was taking forever (presumbaly relates to a bug
    # in this version of OpenFst that makes determinization slow for
    # some case).
    fsttablecompose $lang_dir/L_disambig.fst $lang_dir/G.fst | \
     fstdeterminizestar --use-log=true >/dev/null || echo Error

    echo "Checking that LG is stochastic"
    fsttablecompose $lang_dir/L_disambig.fst $lang_dir/G.fst | \
    fstisstochastic || echo "[log:] LG is not stochastic"
  fi
fi

if [ $stage -le 4 ]; then
  if [ ! -z $model_dir ]; then
    echo "--------------------------------------------------------------------------------"
    echo "Make Graph on " `date`
    echo "--------------------------------------------------------------------------------"

    graph_dir=$model_dir/graph_$lang_name
    if [ "$self_loop_scale" = "1.0" ]; then
      graph_dir=$model_dir/graph_selfloop_$lang_name
    fi

    if [ ! -f $graph_dir/.done ]; then
      utils/mkgraph.sh --self-loop-scale $self_loop_scale $lang_dir $model_dir $graph_dir || exit 1;
      touch $graph_dir/.done
    fi
  fi
fi

echo "--------------------------------------------------------------------------------"
echo "End on " `date`
echo "--------------------------------------------------------------------------------"

exit 0;