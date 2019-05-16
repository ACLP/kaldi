#!/bin/bash
# Author: Ella Erlich

# These stats migh help people figure out what is wrong with the data
# a)human-friendly and machine-parsable alignment in the file per_utt_details.txt
# b)evaluation of per-speaker performance to possibly find speakers with 
#   distinctive accents/speech disorders and similar
# c)Global analysis on (Ins/Del/Sub) operation, which might be used to figure
#   out if there is systematic issue with lexicon, pronunciation or phonetic confusability

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) <data-dir> <ref-text> <rec-text> <out-dir>"
  echo "e.g.: $(basename $0) data/dev data/dev/text exp/tri3/decode_dev/scoring/10.map wer_analysis/dev_tri3_lm_10"
  exit 1;
fi

data_dir=$1;
ref_text=$2;
rec_text=$3;
out_dir=$4;

mkdir -p $out_dir

align-text --special-symbol="***"  ark:$ref_text ark:$rec_text ark,t:- | \
  utils/scoring/wer_per_utt_details.pl --special-symbol "***" > $out_dir/per_utt_details.txt

cat $out_dir/per_utt_details.txt | \
    utils/scoring/wer_per_spk_details.pl $data_dir/utt2spk > $out_dir/per_spk_details.txt

cat $out_dir/per_utt_details.txt | \
    utils/scoring/wer_ops_details.pl --special-symbol "***" | \
    sort -i -b -k1,1 -k4,4nr -k2,2 -k3,3 > $out_dir/ops_details.txt

exit 0;
