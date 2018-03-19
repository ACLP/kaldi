#!/bin/bash
# Author: Ella Erlich

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 3 ]; then
   echo "Usage: $(basename $0) <ref-text> <rec-text> <out-wer-segments>"
   echo "e.g.: $(basename $0) data/dev/text exp/tri3/decode_test/1bext.txt exp/tri3/decode_test/wer_per_segment"
   exit 1;
fi

ref_text=$1;
rec_text=$2;
wer_segments=$3

while read line; do
  echo $line > temp.ref
  cat $rec_text | grep $(echo $line | cut -d' ' -f1) > temp.rec
  paste <(cat temp.ref | cut -d' ' -f1) <(compute-wer --print-args=false --text ark:temp.ref ark:temp.rec | grep WER | cut -d' ' -f2 ) >> $wer_segments
done < $ref_text

rm temp.ref
rm temp.rec

exit 0;
