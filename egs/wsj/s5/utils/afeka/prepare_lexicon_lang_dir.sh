#!/bin/bash
# Author: Ellat
# Modified by Ruth Aloni-Lavi

# begin configuration section.
sil_prob=0.5
extra_word_disambig_syms=
#end configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh
. utils/parse_options.sh

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) <lexicon-file> <lexicon-nonspeach> <src-data-dir> <out-data-dir>"
  echo "e.g.: $(basename $0) new_lexicon.dict nonspeach.dict data/lang data/lang_test"
  echo "Options:"
  echo "--sil-prob       # probability of silence (default: 0.5)"
  echo "--extra-word-disambig-syms <filename>           # default: \"\"; if not empty, add disambiguation symbols"
  exit 1;
fi

dict_file=$1
nonspeach_file=$2
src_lang_dir=$3
out_lang_dir=$4

lexicon=$out_lang_dir/lexicon.txt

echo ---------------------------------------------------------------------
echo "Prepare dict data"
echo ---------------------------------------------------------------------

mkdir -p $out_lang_dir
mkdir -p $out_lang_dir/phones

cat $dict_file > $lexicon.tmp
cat $nonspeach_file >> $lexicon.tmp
#echo $'SIL\tSIL' >> $lexicon.tmp
#echo $'<silence>\tSIL' >> $lexicon.tmp
#echo $'<noise>\t<ns>' >> $lexicon.tmp
#echo $'<v-noise>\t<vns>' >> $lexicon.tmp
#echo $'<unk>\t<oov>' >> $lexicon.tmp
cat $lexicon.tmp | sed -e "s#\t# #g" | sort | uniq > $lexicon && rm $lexicon.tmp

for f in topo oov.txt phones/ ; do
  cp -r $src_lang_dir/$f $out_lang_dir
done

for f in align_lexicon.int align_lexicon.txt disambig.txt disambig.int disambig.csl wdisambig_words.int ; do
  [ -s $f ] && rm $out_lang_dir/phones/$f
done

perl -ape 's/(\S+\s+)(.+)/${1}1.0\t$2/;' < $lexicon > $out_lang_dir/lexiconp.txt || exit 1;
perl -ane '@A=split(" ",$_); $w = shift @A; $p = shift @A; @A>0||die;
  if(@A==1) { print "$w $p $A[0]_S\n"; } else { print "$w $p $A[0]_B ";
  for($n=1;$n<@A-1;$n++) { print "$A[$n]_I "; } print "$A[$n]_E\n"; } ' \
  < $out_lang_dir/lexiconp.txt > $out_lang_dir/lexiconp.original || exit 1;

mv $out_lang_dir/lexiconp.original $out_lang_dir/lexiconp.txt
num_extra_phone_disambig_syms=1
ndisambig=`utils/add_lex_disambig.pl --pron-probs $out_lang_dir/lexiconp.txt $out_lang_dir/lexiconp_disambig.txt`
ndisambig=$[$ndisambig+$num_extra_phone_disambig_syms]; # add extra phone disambig syms
echo $ndisambig > $out_lang_dir/lex_ndisambig
n=0
src_ndisambig=`cat $src_lang_dir/lex_ndisambig`
head -n -$[$src_ndisambig+1] $src_lang_dir/phones.txt > $out_lang_dir/phones.txt

k=`grep \#$n $src_lang_dir/phones.txt | awk '{print $2}'`
echo "#$n $k" >> $out_lang_dir/phones.txt
echo "#$n" > $out_lang_dir/phones/disambig.txt
echo "$k" > $out_lang_dir/phones/disambig.int
echo "$k" > $out_lang_dir/phones/disambig.csl #in case extra_word_disambig_syms is defined disambig.csl file does not contain it. only disambig.txt and disambig.int are updated.

while [ $n -lt $ndisambig ]
do
  n=$[$n+1]
  k=$[$k+1]
  echo "#$n $k" >> $out_lang_dir/phones.txt
  echo "#$n" >> $out_lang_dir/phones/disambig.txt
  echo "$k" >> $out_lang_dir/phones/disambig.int
  line=$(head -n 1 $out_lang_dir/phones/disambig.csl)
  echo "$line:$k" > $out_lang_dir/phones/disambig.csl
done

# Create word symbol table.
# <s> and </s> are only needed due to the need to rescore lattices with
# ConstArpaLm format language model. They do not normally appear in G.fst or
# L.fst.
cat $out_lang_dir/lexiconp.txt | awk '{print $1}' | sort | uniq  | awk '
  BEGIN {
    print "<eps> 0";
  } 
  {
    if ($1 == "<s>") {
      print "<s> is in the vocabulary!" > "/dev/stderr"
      exit 1;
    }
    if ($1 == "</s>") {
      print "</s> is in the vocabulary!" > "/dev/stderr"
      exit 1;
    }
    printf("%s %d\n", $1, NR);
  }
  END {
    printf("#0 %d\n", NR+1);
    printf("<s> %d\n", NR+2);
    printf("</s> %d\n", NR+3);
  }' > $out_lang_dir/words.txt || exit 1;

cat $out_lang_dir/oov.txt | utils/sym2int.pl $out_lang_dir/words.txt >$out_lang_dir/oov.int || exit 1;

silphone=`cat $src_lang_dir/phones/optional_silence.txt` || exit 1;
  
# Create the basic L.fst without disambiguation symbols
utils/make_lexicon_fst.pl --pron-probs $out_lang_dir/lexiconp.txt $sil_prob $silphone | \
 fstcompile --isymbols=$out_lang_dir/phones.txt --osymbols=$out_lang_dir/words.txt \
 --keep_isymbols=false --keep_osymbols=false | \
 fstarcsort --sort_type=olabel > $out_lang_dir/L.fst || exit 1;

# Create the lexicon FST with disambiguation symbols
#phone_disambig_symbol=`grep \#0  $out_lang_dir/phones.txt | awk '{print $2}'`
#word_disambig_symbol=`grep \#0  $out_lang_dir/words.txt | awk '{print $2}'`

#echo "$word_disambig_symbol" > $out_lang_dir/phones/wdisambig_words.int
#echo "$phone_disambi_symbol" > $out_lang_dir/phones/wdisambig_phones.int

echo '#0' >$out_lang_dir/phones/wdisambig.txt

#if [ ! -z "$extra_word_disambig_syms" ]; then
#in_list=$out_lang_dir/in.list
#out_list=$out_lang_dir/out.list
#cp -rR $extra_word_disambig_syms/* $out_lang_dir/
#fi
# In case there are extra word-level disambiguation symbols we need
# to make sure that all symbols in the provided file are valid.
if [ ! -z "$extra_word_disambig_syms" ]; then
	if ! utils/lang/validate_disambig_sym_file.pl --allow-numeric "false" $extra_word_disambig_syms; then
		echo "$0: Validation of disambiguation file \"$extra_word_disambig_syms\" failed."
		exit 1;
	fi
 # In case there are extra word-level disambiguation symbols they also
 # need to be added to the list of phone-level disambiguation symbols.
	phone_count=`tail -n 1 $out_lang_dir/phones.txt | awk '{ print $2 }'`
	# The list of symbols is attached to the current phones.txt (including
	# a numeric identifier for each symbol).
	
	
	
	cat $extra_word_disambig_syms | \
    awk -v PC=$phone_count '{ printf("%d\n", ++PC); }' >> $out_lang_dir/phones/disambig.int || exit 1;
	cat $extra_word_disambig_syms | awk '{ print $1 }' >> $out_lang_dir/phones/disambig.txt
		
	cat $extra_word_disambig_syms | \
    awk -v PC=$phone_count '{ printf("%s %d\n", $1, ++PC); }' >> $out_lang_dir/phones.txt || exit 1;
	cat $extra_word_disambig_syms | awk -v PC=$phone_count '{ printf("%s %d\n", $1, ++PC); }'
	
 # Since words.txt already exists, we need to extract the current word count.
	word_count=`tail -n 1 $out_lang_dir/words.txt | awk '{ print $2 }'`
 # The list of symbols is attached to the current words.txt (including
 # a numeric identifier for each symbol).
	cat $extra_word_disambig_syms | \
    awk -v WC=$word_count '{ printf("%s %d\n", $1, ++WC); }' >> $out_lang_dir/words.txt || exit 1;	
 # In case there are extra word-level disambiguation symbols they need
 # to be added to the existing word-level disambiguation symbols file.
 # The regular expression for awk is just a paranoia filter (e.g. for empty lines).
	cat $extra_word_disambig_syms | awk '{ print $1 }' >> $out_lang_dir/phones/wdisambig.txt
	
fi

 utils/sym2int.pl $out_lang_dir/phones.txt <$out_lang_dir/phones/wdisambig.txt >$out_lang_dir/phones/wdisambig_phones.int
 utils/sym2int.pl $out_lang_dir/words.txt <$out_lang_dir/phones/wdisambig.txt >$out_lang_dir/phones/wdisambig_words.int
	
 utils/make_lexicon_fst.pl --pron-probs $out_lang_dir/lexiconp_disambig.txt $sil_prob $silphone '#'$ndisambig | \
 fstcompile --isymbols=$out_lang_dir/phones.txt --osymbols=$out_lang_dir/words.txt \
 --keep_isymbols=false --keep_osymbols=false | \
 fstaddselfloops   $out_lang_dir/phones/wdisambig_phones.int $out_lang_dir/phones/wdisambig_words.int  | \
 fstarcsort --sort_type=olabel > $out_lang_dir/L_disambig.fst || exit 1;

exit 0;
