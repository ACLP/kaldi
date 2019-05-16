#!/usr/bin/env python
# coding=utf-8
'''
  File: GentleJson2KaldiData.py 
  Usage eg. python GentleJson2KaldiData.py  <gentle json file dir> <kaldi data dir> 
  Reads Gentle json output file and creates kaldi data dir with appropriate segments and text files words are merged to sntences (segments) and text file is synced to the segments
  Created on 13 12 2018 
  @author: zeevr
'''
import sys
import argparse
import string
import re
import os
import io
import codecs
import json



class SegClass:
    def __init__(self, SpkrId, Begin, BegIdx):
         self.SegId    = '' 
         self.SpkrId   = SpkrId 
         self.Words    = []
         self.Begin    = Begin
         self.End      = -1.0
         self.BegIdx   = BegIdx
         self.EndIdx   = -1

 
    def AddWord(self, Word):
         self.Words.append(Word)

class WordInfo:
    def __init__(self):
        self.Word     = ''
        self.Idx      = -1
        self.Begin    = -1.0
        self.End      = -1.0

    def __init__(self, Idx, Word, Begin, End):
        self.Set(Idx, Word, Begin, End)

    def Set(self, Idx, Word, Begin, End):
        self.Word     = Word
        self.Idx      = Idx
        self.Begin    = Begin
        self.End      = End

########################
class KaldiFiles:
    def __init__(self, KaldiDataOutDir, AudioDir):
         self.KaldiDataOutDir   = KaldiDataOutDir
         self.AudioDir  = AudioDir
         self.text      = codecs.open(os.path.join(KaldiDataOutDir, 'text'), 'w', encoding='utf8')
         self.scp       = open(os.path.join(KaldiDataOutDir, 'wav.scp'), 'w')
         self.segments  = open(os.path.join(KaldiDataOutDir, 'segments'), 'w')
         self.utt2spk   = open(os.path.join(KaldiDataOutDir, 'utt2spk'), 'w')
    def Close(self):
        self.text.close()
        self.scp.close()
        self.segments.close()
        self.utt2spk.close()

#################################
def ParseArgs():
    parser = argparse.ArgumentParser(description="Read Gentle Jason format and creates a kaldi data directory with segments and text"
                                     "acording to word locations in jason file"
                                     "Create files for kaldi train"
                                     "Usage: python GentleJson2KaldiData.py <gentle json file dir> <audio dir > <kaldi data dir> "
                                     "E.g. Usage: python GentleJson2KaldiData.py data/GentleJasonTest $audio_dir data/ResegTest",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument("GentleJsonDir",     help = "Input Gentle data dir")
    parser.add_argument("AudioDir",          help = "Input audio data dir")
    parser.add_argument("KaldiDataOutDir",   help = "output kaldi data dir")
    parser.add_argument("-SilGapTh",         help = "Silence duration between words, defining a segment end", default = '1.0')
    parser.add_argument("-MaxSegLen",        help = "Maximum segment target length ", default = '15.0')
    parser.add_argument("-MinSilGap",        help = "Min Silence duration between words, to define segment end when segment length above TH", default = '0.3')
    parser.add_argument("-MinSegLen",        help = "Min Duration of a speech segment", default = '0.3')
    parser.add_argument("-MaxNonAlignedRate",help = "Max rate of non aligned words to num of words in rec", default = '0.1')
    
	#parser.add_argument("-kald_data_in_dir",    help = "Input kaldi data dir", default = '')
    #parser.add_argument("-audio_file_ext", help = "audio file extension", default = '.wav')
    
    print(' '.join(sys.argv))
	
    args = parser.parse_args()
    return args
########################
def createDir(dir_name):
    try:
        os.stat(dir_name)
    except:
        os.makedirs(dir_name)

#################################
def LoadGentleJson(GentleDir, FileKey, WordsLocList):
    JsonFileFullPath = os.path.join(GentleDir, FileKey + '.json')
    assert os.path.isfile(JsonFileFullPath), 'Gentle align file %s does not exist'%(JsonFileFullPath)
    AccWordLen = 0
    nWords = 0
    with io.open(JsonFileFullPath, encoding='utf-8') as JsonFile:
        json_data = json.load(JsonFile)
        #json_words = json_data.get('words')
        #print json_words[0].get('word').strip()
        #sys.exit()

        #js=JsonFile.read()
        #jds = js.decode('utf-8')
        #json_data = json.loads(jds)
        #json_words = json_data.get('words')
        #print json_words[0].get('word').strip()
        #sys.exit()
        #json_data = json.load(JsonFile)
        #print json_data
        #json_data = json.load(JsonFile.read().decode('utf-8'))
        
        json_words = json_data.get('words')
        for count, word in enumerate(json_words):
            txt   = (word.get('word')).strip()
            if 'start' in word:
                start = word.get('start')
            else:
                start = -1
            if 'end' in word:
                end = word.get('end')
                if start != -1:
                    AccWordLen = AccWordLen + end-start
                    nWords = nWords + 1
            else:
                end = -1
            WordInf = WordInfo(count, txt, start, end)
            WordsLocList.append(WordInf)
        return AccWordLen/nWords
#########################		
def FixPreNonAlignedSeg(AlignedWordList, iWordIdx, Seg):
    # Current word index is the 1st non aligned
    iWordIdx = iWordIdx - 1
    while iWordIdx > Seg.BegIdx:
        SilGap = AlignedWordList[iWordIdx].Begin-AlignedWordList[iWordIdx-1].End
        #print "Search for gap for seg end <<<< iWordIdx %d AlignedWordList[iWordIdx-1].End %f AlignedWordList[iWordIdx].Begin %f"%(iWordIdx, AlignedWordList[iWordIdx-1].End, AlignedWordList[iWordIdx].Begin)
        if SilGap > MinSilGap:
            Seg.End = AlignedWordList[iWordIdx-1].End
            Seg.EndIdx = iWordIdx-1
            Seg.Words = []
            #print "fixed seg range Seg.BegIdx %dSeg.EndIdx %d"%(Seg.BegIdx,Seg.EndIdx)
            for iWrd in range(Seg.BegIdx,Seg.EndIdx+1):
                #print "adding iWrd %d %s"%(iWrd, AlignedWordList[iWrd].Word)
                Seg.AddWord(AlignedWordList[iWrd].Word)
            return Seg
        iWordIdx = iWordIdx - 1
    if iWordIdx == Seg.BegIdx:
        # Delete the segment perceeding the nonaligned words
        return []
#########################		
def IgnoreNonAlignedSeg(AlignedWordList, iWordIdx, nNotAligned):
    ValidSegFound = False
	# Arriving here we are already loking on a misaligned word
    WordInf = AlignedWordList[iWordIdx]
	
	# Loop here until valid seg start found
    while iWordIdx < len(AlignedWordList):
	    # Find end of non aligned
        while iWordIdx < len(AlignedWordList):
            if WordInf.Begin == -1.0:
                nNotAligned = nNotAligned + 1
                iWordIdx = iWordIdx + 1
                if iWordIdx == len(AlignedWordList): # End of rec text
                    #print "P0"
                    return [], iWordIdx, nNotAligned			
                WordInf = AlignedWordList[iWordIdx]
            else:
                iWordIdx = iWordIdx + 1
                if iWordIdx == len(AlignedWordList): # End of rec text
                    #print "P1"
                    return [], iWordIdx, nNotAligned			
                WordInf = AlignedWordList[iWordIdx]
                break
		# Search for appropriate word boundary to start 1st seg
        while iWordIdx < len(AlignedWordList):
            if WordInf.Begin != -1.0:
                SilGap = AlignedWordList[iWordIdx].Begin-AlignedWordList[iWordIdx-1].End
                print "Search for gap for seg start >>>> iWordIdx %d AlignedWordList[iWordIdx-1].End %f AlignedWordList[iWordIdx].Begin %f"%(iWordIdx, AlignedWordList[iWordIdx-1].End, AlignedWordList[iWordIdx].Begin)
                if SilGap > MinSilGap:
                    Seg = SegClass(WordSpkrVec[WordInf.Idx], WordInf.Begin, WordInf.Idx)
                    Seg.AddWord(WordInf.Word)
                    ValidSegFound = True
                    break
                iWordIdx = iWordIdx + 1
                if iWordIdx == len(AlignedWordList): # End of rec text
                    #print "P2"
                    return [], iWordIdx, nNotAligned			
                WordInf = AlignedWordList[iWordIdx]
            else:
                break # restart search of aligned
        if ValidSegFound == True:
            return Seg, iWordIdx, nNotAligned
    #print "P3"
    return [], iWordIdx, nNotAligned			
#########################
def WordList2Segments(AlignedWordList, SegList, WordSpkrVec, SilGapTh, MaxSegLen, MinSilGap, MinSegLen, MaxNonAlignedRate):

    # First pass: add to segments list any segment satisfying silence gap rules
	# Second pass: Merge segments to shorter than TH to nearest segment
	
	# Note 
	# 1. With no other source of info we set the speaker Id as Rec Id
	# 2. It is recommended to integrate VAD results for fixing segments having non aligned words
    # 3. Non aligned words are excluded from segments meaning that a nearby segments are cut at nearest aligned word border which satisfies sil gap rules	

    MaxNonAlignedWords = max(1, int(MaxNonAlignedRate*len(AlignedWordList)))
	
	# 1st pass
    PrevSpkrId = ''
    SegIdx = 0
    iWordIdx = 0
    nNotAligned = 0
    while iWordIdx < len(AlignedWordList):
        WordInf = AlignedWordList[iWordIdx]
        #print "Word id %d Beg %f End %f word %s"%(iWordIdx, WordInf.Begin, WordInf.End, WordInf.Word )
        if iWordIdx == 0: # 1st word in recording
            #Seg = SegClass(WordSpkrVec[WordInf.Idx], WordInf.Begin)
		    # Handle words not found in text WordInf.Begin == -1.0
            if WordInf.Begin == -1.0:
                print ">>> Non aligned words at the begin of the recording <<<<<<"
                Seg, iWordIdx, nNotAligned = IgnoreNonAlignedSeg(AlignedWordList, iWordIdx, nNotAligned)
                if Seg == []:
                    print "Misaligned Recording"
                    return -1
                WordInf = AlignedWordList[iWordIdx]
            else: # Aligned 1st word
                Seg = SegClass(WordSpkrVec[WordInf.Idx], WordInf.Begin, WordInf.Idx)
                Seg.AddWord(WordInf.Word)
        else: # Not first word in recording
            if WordInf.Begin == -1.0:
                print ">>> Non aligned words in the recording <<<<<<"
                Seg = FixPreNonAlignedSeg(AlignedWordList, iWordIdx, Seg)
                if Seg != []:
                    Seg.SegId = '%s_%07d_%07d'%(Seg.SpkrId, Seg.Begin*100, Seg.End*100)
                    SegList.append(Seg)
                    print "seg %d shortened due to perceeding misalignment"%(SegIdx)
                    SegIdx = SegIdx + 1
                else:
                    print "seg %d deleted due to perceeding misalignment"%(SegIdx)
               
                Seg, iWordIdx, nNotAligned = IgnoreNonAlignedSeg(AlignedWordList, iWordIdx, nNotAligned)
                if Seg == []:
                    print "End of text right after misaligned seg"
                    break
                WordInf = AlignedWordList[iWordIdx]
            else: # Words aligned successfully
                SilGap = WordInf.Begin-AlignedWordList[iWordIdx-1].End
                CurSegLen = WordInf.End - Seg.Begin
			    # Check Rules for ending segment
                if (SilGap > SilGapTh) | ((CurSegLen > MaxSegLen) & (SilGap > MinSilGap)) | (WordSpkrVec[WordInf.Idx] != WordSpkrVec[WordInf.Idx-1]):
                    Seg.End = AlignedWordList[iWordIdx-1].End
                    #print "seg id %d seg len %f"%(SegIdx, Seg.End - Seg.Begin)
                    Seg.SegId = '%s_%07d_%07d'%(Seg.SpkrId, Seg.Begin*100, Seg.End*100)
                    if Seg.Words == []:
                        print "Seg.Words %s"%(Seg.Words)
                        sys.exit()
                    SegList.append(Seg)
                    Seg = SegClass(WordSpkrVec[WordInf.Idx], WordInf.Begin, WordInf.Idx)
                    Seg.AddWord(WordInf.Word)
                    SegIdx = SegIdx + 1
                else:
                    Seg.AddWord(WordInf.Word)
		
        iWordIdx = iWordIdx + 1
	
	# End last segment
    if Seg != []:
        if Seg.End == -1.0:
            Seg.End = WordInf.End
        Seg.SegId = '%s_%07d_%07d'%(Seg.SpkrId, Seg.Begin*100, Seg.End*100)
        SegList.append(Seg)
    #print SegList[len(SegList)-1].__dict__
    #sys.exit()
    #return
    if nNotAligned > MaxNonAlignedWords:
        print '%d unaligned words in file above TH %d'%(nNotAligned, MaxNonAlignedWords)
        return -1		
	
	# 2nd pass
    OrigSegLen = len(SegList)
    nDeletedSegs = 0
    print "Seg list len before short seg merge:%d"%(OrigSegLen)
    iSeg = 0
    while iSeg < OrigSegLen-nDeletedSegs:
        SegLen = SegList[iSeg].End-SegList[iSeg].Begin
        print "seg id %d seg len %f"%(iSeg, SegLen)
        print "Deleted %d"%(nDeletedSegs)
        #if SegLen < -10000: # Bypass merge
        if SegLen < MinSegLen:
            print ">>>>>>>><<<<<<<<<"
            print "seg id %d >>>>>>>>short seg len %f"%(iSeg, SegLen)
            LeftGap = float("inf")
            if (iSeg > 0)  & (SegList[iSeg-1].SpkrId == SegList[iSeg].SpkrId):
                LeftGap = SegList[iSeg].Begin - SegList[iSeg-1].End
                print "LeftGap %f"%(LeftGap)
            RightGap = float("inf")
            if (iSeg < len(SegList)-1) & (SegList[iSeg+1].SpkrId == SegList[iSeg].SpkrId):
                RightGap = SegList[iSeg+1].Begin - SegList[iSeg].End
                print "RightGap %f"%(RightGap)
            if (LeftGap < RightGap) & (LeftGap != float("inf")):
                SegList[iSeg-1].End = SegList[iSeg].End
                SegList[iSeg-1].SegId = '%s_%07.2f_%07.2f'%(SegList[iSeg-1].SpkrId, SegList[iSeg-1].Begin, SegList[iSeg-1].End)
                SegList.remove(SegList[iSeg])
                nDeletedSegs = nDeletedSegs + 1
                print "Merged to Left"				
            else:
                if (RightGap != float("inf")):			
                    SegList[iSeg+1].Begin = SegList[iSeg].Begin
                    SegList[iSeg+1].SegId = '%s_%07.2f_%07.2f'%(SegList[iSeg+1].SpkrId, SegList[iSeg+1].Begin, SegList[iSeg+1].End)
                    #SegList[iSeg].Reset()	
                    SegList.remove(SegList[iSeg])	
                    nDeletedSegs = nDeletedSegs + 1
                    print "Merged to Right"
                else: 
                    # could not merge				
                    iSeg = iSeg + 1
        else:
            iSeg = iSeg + 1
		# Note in rare cases when the conditions are not satisfied the small segment will be left!
    print "Seg list len after short seg merge:%d"%(OrigSegLen-nDeletedSegs)
    return 0

#########################
def WriteKaldiData(SegList, KaldiFiles, RecId, WavExt):
    
    KaldiFiles.scp.write('%s %s\n'%(RecId, os.path.join(KaldiFiles.AudioDir, RecId + WavExt)))

    # Sort the list (in case segs are deleted it is in disorder)
    SegList.sort(key=lambda x: x.Begin)
    for Seg in SegList:
        KaldiFiles.utt2spk.write('%s %s\n'%(Seg.SegId, Seg.SpkrId))
        SegText = ''
        for w in Seg.Words:
            SegText = SegText + w + ' '
        #print "SegText %s"%(SegText)
        #sys.exit()
        KaldiFiles.text.write('%s %s\n'%(Seg.SegId, SegText))
        KaldiFiles.segments.write('%s %s %07.2f %07.2f\n'%(Seg.SegId, RecId, Seg.Begin,  Seg.End))

#########################
if __name__ == '__main__':

    args = ParseArgs()
    #reload(sys)
    #sys.setdefaultencoding('utf8')	

	# Description:
	# For each json file in Gentle json directory
	# Follow word timings, if duration between end of word to start of next word is larger than SilGapTh
	# add current word to currwnt segment otherwise or current segment length higher than MaxSegLen and 
	# duration between words is larger than MinSilGap, create a segment and initialize a new segment.
	# After all json files are processed create kaldi data files
	
    print 'Note: No speaker data is integrated, it is assumed that every recording is of a single speaker\n' 
    print 'Gentle input dir     %s'%(args.GentleJsonDir)
    print 'Audio  input dir     %s'%(args.AudioDir)
    print 'Output dir           %s'%(args.KaldiDataOutDir) 

    SilGapTh  = float(args.SilGapTh)
    MaxSegLen = float(args.MaxSegLen)
    MinSilGap = float(args.MinSilGap)
    MinSegLen = float(args.MinSegLen)
    MaxNonAlignedRate = float(args.MaxNonAlignedRate)
	
    #MinSegLen=7.0
    #print "   DEB >>>>>>>>> MinSegLen=7.0   <<<<<<<<<<<<<<DEB "
	
    print 'SilGapTh   [sec]  %f'%(SilGapTh) 
    print 'MaxSegLen  [sec]  %f'%(MaxSegLen) 
    print 'MinSilGap  [sec]  %f'%(MinSilGap) 
    print 'MinSegLen  [sec]  %f'%(MinSegLen)
    print 'MaxNonAlignedRate %f'%(MaxNonAlignedRate)
    WavExt = '.wav'	
	
    createDir(args.KaldiDataOutDir)

    KaldiFiles = KaldiFiles(args.KaldiDataOutDir, args.AudioDir)
	
    iFile = 0
    for root, dirs, files in os.walk(args.GentleJsonDir):
        for file in files:
            if file.endswith(".json"):
                iFile = iFile + 1
                tok = file.split('.')
                RecKey = tok[0]
                print 'Reading json for file Key: %s Num %d'%(RecKey, iFile)
                #if iFile > 46:
                #    sys.exit()
                #if RecKey == "SICK_BT100_8":
                #    sys.exit()
                    
                AlignedWordList = []
                fAvWordDur = LoadGentleJson(args.GentleJsonDir, RecKey, AlignedWordList)
               
                print 'Align words list size: %d'%(len(AlignedWordList))
                #print AlignedWordList[0].__dict__
                #sys.exit(1)

				# Temp vector for speaker Id for every word (for future integration of speaker Id)
				# currently Speaker id is identical to the file key
				# In case we have some diarization data tike RTTM file we can sync it with the word timings in AlignedWordList 
				# to create the WordSpkrVec below 
                WordSpkrVec = []
                for i in range(len(AlignedWordList)):
                    WordSpkrVec.append(RecKey)
                #print WordSpkrVec
                #sys.exit(1)
				
                SegList = []
                RetVal = WordList2Segments(AlignedWordList, SegList, WordSpkrVec, SilGapTh, MaxSegLen, MinSilGap, MinSegLen, MaxNonAlignedRate)
                #print SegList[len(SegList)-1].__dict__
                #sys.exit(1)
                if RetVal != 0:
                    print "Ignoring recording %s due to misalingment"%(RecKey)
                    continue
				
                WriteKaldiData(SegList, KaldiFiles, RecKey, WavExt)
                #sys.exit(1)
                              


    KaldiFiles.Close()
