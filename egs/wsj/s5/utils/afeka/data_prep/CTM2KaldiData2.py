#!/usr/bin/env python3
# coding=utf-8
'''
  File: CTM2KaldiData.py 
  Usage eg. python CTM2KaldiData.py  <CTM file> <kaldi data dir> 
  e.g.  utils/afeka/data_prep/CTM2KaldiData.py exp/chain_cleaned/tdnn_lstm_attend_bs1b_sp_bi/decode_LM-GaleTrain4xLevDev_Lev-3set_tr/lm_8/utt.1.ctm data/tmp
  Reads CTM file and creates kaldi data dir with appropriate segments and text files words are merged to setences (segments) and text file is synced to the segments
  Note: If more than one CTM file exist, merge them with "cat" to one file (sort is not needed)
  Created on 3 1 2019 
  @author: zeevr
'''
from __future__ import print_function

import sys
import argparse
import string
import re
import os
import io
import codecs
import json



class Segment:
  def __init__(self, speaker, begin, begin_idx):
    self.seg_id    = '' 
    self.speaker   = speaker 
    self.words    = []
    self.begin    = begin
    self.end      = -1.0
    self.begin_idx   = begin_idx
    self.end_idx   = -1

 
  def append_word(self, Word):
    self.words.append(Word)

class WordInfo:
  def __init__(self, idx = '', word = '', begin = -1.0, end = -1.0, rec_name = ''):
    self.set(idx, word, begin, end, rec_name)

  def set(self, idx, word, begin, end, rec_name):
    self.word     = word
    self.idx      = idx
    self.begin    = begin
    self.end      = end
    self.speaker  = rec_name

########################
class KaldiFiles:
  def __init__(self, kaldi_data_out_dir):
    self.kaldi_data_out_dir   = kaldi_data_out_dir

    os.makedirs(self.kaldi_data_out_dir, exist_ok=True)
    #self.text      = codecs.open(os.path.join(KaldiDataOutDir, 'text'), 'w', encoding='utf8')
    self.text      = codecs.open(os.path.join(kaldi_data_out_dir, 'text'), 'w')
    self.segments  = open(os.path.join(kaldi_data_out_dir, 'segments'), 'w')
    self.utt2spk   = open(os.path.join(kaldi_data_out_dir, 'utt2spk'), 'w')
  
  def close(self):
    self.text.close()
    self.segments.close()
    self.utt2spk.close()

#################################
def parse_args():
  parser = argparse.ArgumentParser(description="Read CTM file and creates a kaldi data directory with segments and text"
                                               "acording to word locations in CTM file"
                                               "Create files for kaldi train"
                                               "Usage: python CTM2KaldiData.py <gentle json file dir> <kaldi data dir> "
                                               "E.g. Usage: python CTM2KaldiData.py $CTMfile data/ResegTest",
                                               formatter_class=argparse.ArgumentDefaultsHelpFormatter)

  parser.add_argument("CTMfileName",       help = "Input CTM file name")
  parser.add_argument("KaldiDataOutDir",   help = "output kaldi data dir")
  parser.add_argument("-SilGapTh",         help = "Silence duration between words, defining a segment end", default = '1.0')
  parser.add_argument("-MaxSegLen",        help = "Maximum segment target length ", default = '15.0')
  parser.add_argument("-MinSilGap",        help = "Min Silence duration between words, to define segment end when segment length above TH", default = '0.3')
  parser.add_argument("-MinSegLen",        help = "Min Duration of a speech segment", default = '0.3')
    
  #parser.add_argument("-kald_data_in_dir",    help = "Input kaldi data dir", default = '')
  #parser.add_argument("-audio_file_ext", help = "audio file extension", default = '.wav')
  
  print(' '.join(sys.argv))
  
  args = parser.parse_args()
  return args

#################################
def load_ctm(ctm_filename, out_words):
  for line_num, line in enumerate(open(ctm_filename)):
    tokens  = re.split("[, \t\r\n]+", line.rstrip())
    if len(tokens) != 5:
      print('Bad line in CTM file (#{}): {}'.format(line_num, line))
      print("Tokens: {}".format('***'.join(tokens)))
      return False
    label = tokens[0]
    channel = tokens[1]
    begin = float(tokens[2])
    end = begin + float(tokens[3])
    txt = tokens[4]
    out_words.append(WordInfo(line_num, txt, begin, end, label))

  return True

#########################
def word_list_to_segments(word_list, segment_list, sil_gap_threshold, max_seg_len, min_sil_gap, min_seg_len):

  # First pass: add to segments list any segment satisfying silence gap rules
  # Second pass: Merge segments shorter than TH to nearest segment
  
  # Note 
  # 1. With no other source of info we set the speaker Id as Rec Id


  # 1st pass
  PrevSpkrId = ''
  SegIdx = 0
  iWordIdx = 0
  nNotAligned = 0
  while iWordIdx < len(word_list):
    WordInf = word_list[iWordIdx]
    print ("Word id %d Beg %f End %f word %s"%(iWordIdx, WordInf.Begin, WordInf.End, WordInf.Word))
    if iWordIdx == 0: # 1st word in recording
      Seg = Segment(WordInf.speaker, WordInf.begin, WordInf.idx)
      Seg.append_word(WordInf.word)
    else: # Not first word in recording
      SilGap = WordInf.begin-word_list[iWordIdx-1].end
      CurSegLen = WordInf.end - Seg.begin
      # Check Rules for ending segment
      if (SilGap > sil_gap_threshold) | ((CurSegLen > max_seg_len) & (SilGap > min_sil_gap)) | (WordInf.speaker != word_list[iWordIdx-1].speaker):
        Seg.end = word_list[iWordIdx-1].end
        
        #print "seg id %d seg len %f text %s iWordIdx: %d"%(SegIdx, Seg.End - Seg.Begin, Seg.Words, iWordIdx)
        #sys.exit()

        Seg.seg_id = '%s_%07d_%07d'%(Seg.speaker, Seg.begin*100, Seg.end*100)
        if Seg.words == []:
          print("Seg.Words %s"%(Seg.words))
          sys.exit()
          segment_list.append(Seg)
          Seg = Segment(WordInf.speaker, WordInf.begin, WordInf.idx)
          Seg.append_word(WordInf.word)
          SegIdx = SegIdx + 1
        else:
          Seg.append_word(WordInf.word)
    
    iWordIdx = iWordIdx + 1
    
  # End last segment
  if Seg != []:
    if Seg.end == -1.0:
      Seg.end = WordInf.end
    Seg.seg_id = '%s_%07d_%07d'%(Seg.speaker, Seg.begin*100, Seg.end*100)
    segment_list.append(Seg)
    
  #print SegList[0].__dict__
  #print SegList[1].__dict__
  #print SegList[len(SegList)-1].__dict__
  #sys.exit()
  #return
    
  # 2nd pass
  OrigSegLen = len(segment_list)
  nDeletedSegs = 0
  print("Seg list len before short seg merge:%d"%(OrigSegLen))
  iSeg = 0
  while iSeg < OrigSegLen-nDeletedSegs:
    SegLen = segment_list[iSeg].end-segment_list[iSeg].begin
    print("seg id %d seg len %f"%(iSeg, SegLen))
    print("Deleted %d"%(nDeletedSegs))
    #if SegLen < -10000: # Bypass merge
    if SegLen < min_seg_len:
      print(">>>>>>>><<<<<<<<<")
      print("seg id %d >>>>>>>>short seg len %f"%(iSeg, SegLen))
      LeftGap = float("inf")
      if (iSeg > 0)  & (segment_list[iSeg-1].speaker == segment_list[iSeg].speaker):
        LeftGap = segment_list[iSeg].begin - segment_list[iSeg-1].end
        print("LeftGap %f"%(LeftGap))
      RightGap = float("inf")
      if (iSeg < len(segment_list)-1) & (segment_list[iSeg+1].speaker == segment_list[iSeg].speaker):
        RightGap = segment_list[iSeg+1].begin - segment_list[iSeg].end
        print("RightGap %f"%(RightGap))
      if (LeftGap < RightGap) & (LeftGap != float("inf")):
        segment_list[iSeg-1].end = segment_list[iSeg].end
        segment_list[iSeg-1].seg_id = '%s_%07.2f_%07.2f'%(segment_list[iSeg-1].speaker, segment_list[iSeg-1].begin, segment_list[iSeg-1].end)
        segment_list.remove(segment_list[iSeg])
        nDeletedSegs = nDeletedSegs + 1
        print("Merged to Left")
      else:
        if (RightGap != float("inf")):
          segment_list[iSeg+1].begin = segment_list[iSeg].begin
          segment_list[iSeg+1].seg_id = '%s_%07.2f_%07.2f'%(segment_list[iSeg+1].speaker, segment_list[iSeg+1].begin, segment_list[iSeg+1].end)
          #SegList[iSeg].Reset()	
          segment_list.remove(segment_list[iSeg])	
          nDeletedSegs = nDeletedSegs + 1
          print("Merged to Right")
        else: 
          # could not merge				
          iSeg = iSeg + 1
    else:
      iSeg = iSeg + 1
    # Note in rare cases when the conditions are not satisfied the small segment will be left!
  print("Seg list len after short seg merge:%d"%(OrigSegLen-nDeletedSegs))
  return 0

#########################
def WriteKaldiData(SegList, KaldiFiles, WavExt):
  
  # Sort the list (in case segs are deleted it is in disorder)
  #SegList.sort(key=lambda x: x.Begin)
  
  for Seg in SegList:
    KaldiFiles.utt2spk.write('%s %s\n'%(Seg.seg_id, Seg.speaker))
    SegText = ''
    for w in Seg.words:
        SegText = SegText + w + ' '
    #print "SegText %s"%(SegText)
    #sys.exit()
    RecId = Seg.speaker
    KaldiFiles.text.write('%s %s\n'%(Seg.seg_id, SegText))
    KaldiFiles.segments.write('%s %s %07.2f %07.2f\n'%(Seg.seg_id, RecId, Seg.begin,  Seg.end))

#########################
if __name__ == '__main__':

  args = parse_args()
  #reload(sys)
  #sys.setdefaultencoding('utf8')	

  # Description:
  # For all words in CTM
  # Follow word timings, if duration between end of word to start of next word is larger than SilGapTh
  # add current word to currwnt segment otherwise or current segment length higher than MaxSegLen and 
  # duration between words is larger than MinSilGap, create a segment and initialize a new segment.
  # After all json files are processed create kaldi data files
  
  print('Note: No speaker data is integrated, it is assumed that every recording is of a single speaker\n')
  print('CTM input file     %s'%(args.CTMfileName))
  print('Output dir           %s'%(args.KaldiDataOutDir))

  SilGapTh  = float(args.SilGapTh)
  MaxSegLen = float(args.MaxSegLen)
  MinSilGap = float(args.MinSilGap)
  MinSegLen = float(args.MinSegLen)
  
  #MinSegLen=7.0
  #print "   DEB >>>>>>>>> MinSegLen=7.0   <<<<<<<<<<<<<<DEB "
  
  print('SilGapTh   [sec]  %f'%(SilGapTh))
  print('MaxSegLen  [sec]  %f'%(MaxSegLen))
  print('MinSilGap  [sec]  %f'%(MinSilGap))
  print('MinSegLen  [sec]  %f'%(MinSegLen))
  WavExt = '.wav'	
  
  KaldiFiles = KaldiFiles(args.KaldiDataOutDir)
  
  
  AlignedWordList = []
  RetVal = load_ctm(args.CTMfileName, AlignedWordList)
  if RetVal == False:
      sys.exit()
  
  print('CTM list size: %d'%(len(AlignedWordList)))

  # print AlignedWordList[0].__dict__
  # print AlignedWordList[1].__dict__
  # print AlignedWordList[2].__dict__
  # print AlignedWordList[len(AlignedWordList)-1].__dict__
  # sys.exit(1)
  
  print("dont forget to sort by beg time for each recording !!!!!!!!!!!!!!!!")
  
  SegList = []
  RetVal = word_list_to_segments(AlignedWordList, SegList, SilGapTh, MaxSegLen, MinSilGap, MinSegLen)
  
  #print SegList[0].__dict__
  #print SegList[len(SegList)-1].__dict__
  #sys.exit(1)
  
  if RetVal != 0:
    print("Ignoring recording due to misalingment")
    sys.exit(1)
  
  WriteKaldiData(SegList, KaldiFiles, WavExt)
  #sys.exit(1)

  KaldiFiles.close()
