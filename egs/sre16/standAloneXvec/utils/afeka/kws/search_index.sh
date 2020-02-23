#!/bin/bash

# Copyright 2012  Johns Hopkins University (Author: Guoguo Chen)
# Apache 2.0
# Modified by Ella Erlich

# Begin configuration section.
cmd=run.pl
nbest=-1
strict=true
indices_dir=
keywords=

frame_subsampling_factor=
# End configuration section.

echo "$0 $@"  # Print the command line for logging
. utils/parse_options.sh || exit 1;

. ./path.sh || exit 1;

if [ $# != 2 ]; then
   echo "Usage: $(basename $0) [options] <kws-data-dir> <kws-dir>"
   echo " e.g.: $(basename $0) data/kws exp/sgmm2_5a_mmi/decode/kws/"
   echo "Options:"
   echo "main options (for others, see top of script file)"
   echo "--cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "--nbest                                          # return n best results. (-1 means all)"
   echo "--indices-dir                                    # where the indices should be stored, by default it will be in <kws-dir>"
   echo "--keywords                                       # keywords.fsts file"
   exit 1;
fi

kwsdatadir=$1;
kwsdir=$2;

if [ -z $indices_dir ] ; then
  indices_dir=$kwsdir
fi

mkdir -p $kwsdir/log;
nj=`cat $indices_dir/num_jobs` || exit 1;

if [ -z "$keywords" ]; then # if --keywords <fsts> was notecified on the command line...
  keywords=$kwsdatadir/keywords.fsts;
fi

for f in $indices_dir/index.1.gz $keywords; do
  [ ! -f $f ] && echo "make_index.sh: no such file $f" && exit 1;
done

$cmd JOB=1:$nj $kwsdir/log/search.JOB.log \
  kws-search --strict=$strict --negative-tolerance=-1 \
  --frame-subsampling-factor=$frame_subsampling_factor \
  "ark:gzip -cdf $indices_dir/index.JOB.gz|" ark:$keywords \
  "ark,t:|int2sym.pl -f 2 $kwsdatadir/utter_id | sort -u | gzip > $kwsdir/result.JOB.gz" \
  "ark,t:|int2sym.pl -f 2 $kwsdatadir/utter_id | sort -u | gzip > $kwsdir/stats.JOB.gz" || exit 1;

exit 0;
