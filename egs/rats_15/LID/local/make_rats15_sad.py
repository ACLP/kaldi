#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import print_function
import argparse
import sys, os, re
from collections import namedtuple

parser = argparse.ArgumentParser(description="Prepare data folders for LID with RATS2015-SAD data-set",
                                 epilog="e.g. make_rats15_sad.py data/sad.data data/rats15_sad /storage/DB/LDC/LDC2015S02/RATS_SAD",
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("data_file", type=str,
                    help="Input data file")
parser.add_argument("out_path", type=str,
                    help="Output directory")
parser.add_argument("db_root", type=str,
                    help="Root path of audio files")
parser.add_argument("--verbose", type=int, default=0,
                    help="Be verbose (larger==more info)")
parser.add_argument("--print-stats", action='store_true',
                    help="Output statistics and exit")
parser.add_argument("--simple-split", action='store_true',
                    help="Just remove leading and trailing RX/NT segments, do not split utterances")

args = parser.parse_args()


Segline = namedtuple('Segline', 'part utt_id t_start t_end vad_type lang channel')
Files = namedtuple('Files', 'wav_scp vad_ref utt2spk utt2lang utt2dur')

all_utterances = dict()
all_partitions = dict()
all_langs = dict()

class Segment:
    def __init__(self, t_start, t_end, vad_type, id=None):
        self.t_start = t_start
        self.t_end = t_end
        self.vad_type = vad_type
        self.id = id

class Utterance:
    def __init__(self, utt_id, part, lang, channel):
        self.utt_id = utt_id
        self.part = part
        self.lang = lang
        self.channel = channel
        self.done_split = False
        self.segments = []

    def add_segment(self, seg):
        self.segments.append(seg)

    def split(self):
        # don't run twice..
        if self.done_split:
            return
        if args.verbose>2:
            sys.stderr.write('Scanning segments in {}\n'.format(self.utt_id))

        self.segments = sorted(self.segments, key=lambda seg: seg.t_start)
        if args.simple_split:
            start = end = -1
            while len(self.segments)>0 and re.match('RX|NT', self.segments[0].vad_type):
                self.segments.pop(0)
            while len(self.segments)>0 and re.match('RX|NT', self.segments[-1].vad_type):
                self.segments.pop(-1)
        else:
            self.segments = [ x for x in self.segments if not re.match('RX|NT', x.vad_type) ]
        self.done_split = True

    def write_to_files(self, files, db_root):
        self.split()

        if len(self.segments)==0:
            if args.verbose>1:
                sys.stderr.write('>>> utt {} has not segments left, discarding...'.format(self.utt_id))
            return


        if args.verbose>2:
            sys.stderr.write('Writing files for utt {} ...'.format(self.utt_id))

        audio_path = [db_root, 'data', self.part, 'audio'] 
        if self.part=='train':
            audio_path.append(self.lang)
        audio_path.extend([ self.channel, '{}.{}'.format(self.utt_id, 'flac') ])
        audio_fname = os.path.sep.join(audio_path)

        files.utt2spk.write('{} {}\n'.format(self.utt_id, self.utt_id))
        files.utt2lang.write('{} {}\n'.format(self.utt_id, self.lang))
        files.utt2dur.write('{} {:.3f}\n'.format(self.utt_id, self.segments[-1].t_end-self.segments[0].t_start))

        trim_line = []
        start = last_end = self.segments[0].t_start
        for seg in self.segments:
            if seg.t_start-last_end > 0.01 : # there's a gap...
                trim_line.append('={:.3f} ={:.3f}'.format(start, last_end))
                start = seg.t_start
            last_end = seg.t_end

            v_start = 0
            in_v = False
            if re.match('RX|NT|NS', seg.vad_type):
                if in_v:
                    seg_id = '{}_{:07d}_{:07d}'.format(seg.id, int(v_start*100), int(seg.t_start*100))
                    files.vad_ref.write('{} {:.3f} {:.3f}\n'.format(seg_id, v_start, seg.t_start))
                    in_v = False
            elif not in_v: # vad_type=='S'
                v_start = seg.t_start
                in_v = True
        if len(trim_line)>0:
            trim_line.insert(0, 'trim')
        files.wav_scp.write('{} sox {} -r 8000 -b 16 -t wavpcm - {} |\n'.format(self.utt_id, audio_fname, ' '.join(trim_line)))
        if args.verbose>2:
            sys.stderr.write(' ... done.\n')

def parse_line(line):
    f = line.split()
    part = f[0]
    utt_id = f[1]
    t_start = float(f[2])
    t_end = float(f[3])
    vad_type = f[4]
    lang = f[6]
    channel = utt_id[utt_id.rindex("_")+1:]
    return Segline(part, utt_id, t_start, t_end, vad_type, lang, channel)

def read_data(fname):
    n = 0
    if fname=='-':
        fin = sys.stdin
    else:
        fin = open(fname, 'r', encoding='utf8')

    for line in fin.readlines():
        s = parse_line(line)
        n+=1

        if not s.utt_id in all_utterances:
            all_utterances[s.utt_id] = Utterance(s.utt_id, s.part, s.lang, s.channel)

        u = all_utterances[s.utt_id]
        u.add_segment(Segment(s.t_start, s.t_end, s.vad_type))

        if not s.part in all_partitions:
            all_partitions[s.part] = 1
        if not s.lang in all_langs:
            all_langs[s.lang] = 1

        if args.verbose>2 and n%1000==0:
            sys.stderr.write('processed {:12d} lines\r'.format(n))
    
    if fname=='-':
        fin.close()

    if args.verbose>0:
        sys.stderr.write('\nFinished reading - total {:12d} lines\n'.format(n))

def write_all(path, db_root):
    for part in all_partitions:
        if args.verbose>0:
            sys.stderr.write('Writing {} utterances\n'.format(part))
        os.makedirs(os.path.sep.join([path, part]), exist_ok=True)
        with open(os.path.sep.join([path, part, 'wav.scp']), 'w', encoding='utf8') as wav_scp, \
            open(os.path.sep.join([path, part, 'segments.vad.ref']), 'w', encoding='utf8') as vad_ref, \
            open(os.path.sep.join([path, part, 'utt2spk']), 'w', encoding='utf8') as utt2spk, \
            open(os.path.sep.join([path, part, 'utt2lang']), 'w', encoding='utf8') as utt2lang, \
            open(os.path.sep.join([path, part, 'utt2dur']), 'w', encoding='utf8') as utt2dur:

            files = Files(wav_scp, vad_ref, utt2spk, utt2lang, utt2dur)
            n=0
            for u in [ all_utterances[x] for x in all_utterances if all_utterances[x].part == part ]:
                u.write_to_files(files, db_root)
                n+=1
                if (args.verbose>1 and n%1000==0) or (args.verbose>2 and n%10==0):
                    sys.stderr.write('done {} utterances\n'.format(n))
        if args.verbose>0:
            sys.stderr.write('Finished {} ({} utterances)\n'.format(part, n))

def print_stats():
    import math
    for part in all_partitions:
        nutt=0
        tot_dur=0.0
        tot_dur_2 = 0.0
        for u in [ all_utterances[x] for x in all_utterances if all_utterances[x].part == part ]:
            u.split()
            nutt += 1
            for s in u.segments:
                dur = s.t_end - s.t_start
                tot_dur += dur
                tot_dur_2 += dur*dur
        sys.stdout.write('Partition: {}\n\t#Utt\t{}\n\t#sec\t{}\n\tmean: {}; std: {}\n\n'.format(part, nutt, tot_dur, tot_dur/nutt, math.sqrt(tot_dur*tot_dur - tot_dur_2)/nutt))

    for lang in all_langs:
        nutt=0
        tot_dur=0.0
        tot_dur_2 = 0.0
        for u in [ all_utterances[x] for x in all_utterances if all_utterances[x].lang == lang ]:
            u.split()
            nutt += 1
            for s in u.segments:
                dur = s.t_end - s.t_start
                tot_dur += dur
                tot_dur_2 += dur*dur
        sys.stdout.write('Lang: {}\n\t#Utt\t{}\n\t#sec\t{}\n\tmean: {}; std: {}\n'.format(lang, nutt, tot_dur, tot_dur/nutt, math.sqrt(tot_dur*tot_dur - tot_dur_2)/nutt))
        
def main():
    if args.verbose>0:
        sys.stderr.write('Reading data from: {}\n'.format(args.data_file))
    read_data(args.data_file)

    if args.print_stats:
        print_stats()
    else:
        if args.verbose>0:
            sys.stderr.write('Writing output to: {} (Audio data root: {})\n'.format(args.out_path, args.db_root))
        write_all(args.out_path, args.db_root)

if __name__ == "__main__":
    main()