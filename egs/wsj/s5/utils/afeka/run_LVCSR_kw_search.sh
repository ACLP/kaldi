#!/bin/bash
# Author: Ella Erlich

# Begin configuration section.
cmd=run.pl
model= # You canecify the model to use
kws_xml=""
language=""
lmwt=1.0
kwmapping=
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# -ne 4 ]; then
  echo "Usage: $(basename $0) [options] <data-dir> <data-lang> <KWS-List> <decode-dir>"
  echo "e.g.: $(basename $0) data/dev data/lang_test KeyWords.txt exp/tri3/decode_dev"
  echo "Options:"
  echo "--cmd (run.pl|queue.pl...)  # specify how to run the sub-processes."
  echo "--kws-xml                   # kws xml format"
  echo "--language                  # language type (string,  default = "")"
  echo "--lmwt                      # lm scale used for *.lat (default 1.0)"
  echo "--model                     # which model to use"
  echo "--kwmapping                 # use kws mapping for additional results"
  exit 1;
fi

data_dir=$1
data_lang=$2
KWS_List=$3
decode_dir=$4

ecf_file=$data_dir/ecf.xml
kwdatadir=$data_dir/kw
kw_raw=$kwdatadir/keywords.raw

if [[ ! -f "$ecf_file"  ]] ; then
  echo "$0: FATAL: the $data_dir does not contain the ecf.xml file"
  exit 1;
fi

mkdir -p $kwdatadir || exit 1;

srcdir=`dirname $decode_dir`; # The model directory is one level up from decoding directory.

if [ -z "$model" ]; then # if --model <mdl> was notecified on the command line...
  model=$srcdir/final.mdl
fi

duration=`head -1 $ecf_file |\
  grep -o -E "duration=\"[0-9]*[    \.]*[0-9]*\"" |\
  perl -e 'while($m=<>) {$m=~s/.*\"([0-9.]+)\".*/\1/; print $m/2;}'`

kwsoutdir=$decode_dir/lm_$lmwt/kws

kw_opt=

if [ ! -z $kws_xml ]; then
  kw_raw=$kws_xml
else
  tr -d "\r" < $KWS_List > $kw_raw
  kw_opt="--kwlist_wordlist true"
fi

if [ ! -z $kwmapping ]; then
  utils/afeka/kws/kws_setup.sh  $kw_opt --case_insensitive true $ecf_file $kw_raw $data_lang $data_dir $kwdatadir
else
  utils/afeka/kws/kws_setup.sh $kw_opt --case_insensitive true $ecf_file $kw_raw $data_lang $data_dir $kwdatadir
fi

acwt=`echo "scale=5; 1/$lmwt" | bc -l | sed "s/^\./0./"` 

max_states=150000
word_ins_penalty=0
max_silence_frames=50
ntrue_scale=1.0
duptime=0.6

indices=$kwsoutdir/indices

steps/make_index.sh --cmd "$cmd" --acwt $acwt --model $model --skip-optimization true --max-states $max_states \
  --word-ins-penalty $word_ins_penalty --max-silence-frames $max_silence_frames $kwdatadir $data_lang $decode_dir $indices  || exit 1
  
if [ -z "$frame_subsampling_factor" ]; then
  if [ -f $srcdir/frame_subsampling_factor ] ; then
    frame_subsampling_factor=$(cat $srcdir/frame_subsampling_factor)
  else 
    frame_subsampling_factor=1
  fi
  echo "$0: Frame subsampling factor autodetected: $frame_subsampling_factor"
fi

#  --strict false
utils/afeka/kws/search_index.sh --cmd "$cmd" --strict false --frame-subsampling-factor $frame_subsampling_factor --indices-dir $indices $kwdatadir $kwsoutdir || exit 1;

segments_opts=
if [ -f $data_dir/segments ]; then
  segments_opts="--segments=$data_dir/segments"
fi

language_opts=
if [ ! -z $language ]; then
  language_opts="--language=$language";
fi

$cmd LMWT=$lmwt:$lmwt $kwsoutdir/write_normalized.LMWT.log \
  set -e ';' set -o pipefail ';'\
  cat ${kwsoutdir}/result.*.gz \| gunzip \| \
    utils/afeka/kws/write_kwslist.pl $language_opts --Ntrue-scale=$ntrue_scale --flen=0.01 --duration=$duration \
      $segments_opts --normalize=true --duptime=$duptime --remove-dup=true\
      --map-utter=$kwdatadir/utter_map --reco2fc=$data_dir/reco2file_and_channel --digits=3 \
      - ${kwsoutdir}/kwslist_norm.xml || exit 1;

awk -f utils/afeka/kws/fix_kwslist.awk $kwdatadir/kwlist.xml ${kwsoutdir}/kwslist_norm.xml > ${kwsoutdir}/kwslist.xml

exit 0;
