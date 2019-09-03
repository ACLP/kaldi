#!/bin/bash

# 2019 Dongji Gao

# This script generates subword text form word text.
# For example, <noise> internatioal -> <noise> inter@@ nation@@ al
# @@ here is the separator indicate the poisition of subword in word.
# Subword directly followed by separator can only appear at he begining or middle of word.
# "<noise>" here can be reserved if added to the option "--glossaries"

# Begin configuration section
separator="@@"
glossaries=
start_field=2 # 1 without segment ID, 2 with segment ID
# End configuration section

. utils/parse_options.sh

echo "$0 $@"

if [ $# -ne 3 ]; then
  echo "Usage: utils/prepare_subword_text.sh <word-text> <pair_code> <subword-text>"
  echo "e.g.: utils/prepare_subword_text.sh data/train/text data/local/pair_code.txt data/train/text_subword"
  echo "--seperator <separator>         # default: @@"
  echo "--glossaries <reserved-words>   # glossaries are words reserved"
  echo "--start-field        # text start field ( default 2, with utt ID)"
  exit 1;
fi

word_text=$1
pair_code=$2
subword_text=$3

[ ! -f $word_text ] && echo "Word text $word_text does not exits." && exit 1;

grep -q $separator $word_text && echo "$0: Error, word text file contains separator $separator. This might be a subword text file or you need to choose a different separator" && exit 1;

glossaries_opt=
[ -z $glossaires ] && glossaries_opt="--glossaries $glossaries"
echo "glossaries_opt: $glossaries_opt"

cat $word_text | cut -d ' ' -f $start_field- | \
  utils/lang/bpe/apply_bpe.py -c $pair_code --separator $separator $glossaries_opt > $subword_text

echo "Subword text created."
