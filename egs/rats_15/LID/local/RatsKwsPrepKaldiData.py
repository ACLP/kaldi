#!/usr/bin/env python3
# coding=utf-8

'''
  File: RatsKwsPrepKaldiData.py 
  Usage eg. python RatsKwsPrepKaldiData.py  <Base Dir name> <Sub dir list file> <kaldi data dir> [<audio out dir>] 
  Gets .tab fles recursively from <Base Dir name> filtering sub dirs according to list in <Sub dir list file> and creates kaldi data dir files
  to given <audio out dir> is given audio files are cut 
  Created on 09 12 2019 
  @author: Shlomit
'''

from __future__ import print_function

import sys
import argparse
import string
import re
import os
import io
import codecs

####################################################################################################################
class TabEntry:
    def __init__(self):
        self.sDbName            = ''
        self.sAudioFileName     = ''
        self.fBegSec            = -1
        self.fEndSec            = -1
        self.sRecN_S_RX_state   = ''
        self.sRecOrig_auto_part = ''
        self.sLangOrig          = ''
        self.sTextWords         = []
        
    def setTabEntry(self, sDbName, sAudioFileName, fBegSec, fEndSec, sRecN_S_RX_state, sRecOrig_auto_part, sLangOrig='', ):
        self.sDbName            = sDbName
        self.sAudioFileName     = sAudioFileName
        self.fBegSec            = fBegSec
        self.fEndSec            = fEndSec
        self.sRecN_S_RX_state   = sRecN_S_RX_state
        self.sRecOrig_auto_part = sRecOrig_auto_part
        self.sLangOrig          = sLangOrig

    def AddWord(self, Word):
        self.sTextWords.append('{}'.format(Word))

    def printTabentry (self):  
        TabText=''
        for w in self.sTextWords:
            TabText = TabText + w + ' '
        #print ("printTabentry sDbName: {}  sAudioFileName: {} fBegSec: {} fEndSec: {} sRecN_S_RX_state: {} sRecOrig_auto_part: {} sLang: {} sTextWords: {}".format(self.sDbName,self.sAudioFileName,self.fBegSec,self.fEndSec,self.sRecN_S_RX_state ,self.sRecOrig_auto_part,self.sLangOrig,TabText) )
        
####################################################################################################################
class SegEntry:
    def __init__(self):
        self.sSegKey    = ''
        self.fBegSec   = -1
        self.fEndSec   = -1
        self.sRecKey   = ''
        self.sAudioFileName   = ''
        self.sRecN_S_RX_state   = ''
        self.TextWords = []

    def setSegEntry(self, sSegKey, fBegSec, fEndSec, sRecKey, sAudioFileName, sRecN_S_RX_state):
        self.sSegKey = sSegKey
        self.fBegSec = fBegSec
        self.fEndSec = fEndSec
        self.sRecKey = sRecKey
        self.sAudioFileName = sAudioFileName
        self.sRecN_S_RX_state = sRecN_S_RX_state
    
    def AddWord(self, Word):
        self.TextWords.append('{}'.format(Word))
    
    def printSegEntry (self):
        SegText=''
        for w in self.TextWords:
            SegText = SegText + w + ' '
        #print ("printSegEntry sSegKey: {}  fBegSec: {} fEndSec: {} sRecKey: {} sAudioFileName: {} sRecN_S_RX_state: {} SegText: {} ".format(self.sSegKey, self.fBegSec,self.fEndSec,self.sRecKey ,self.sAudioFileName,self.sRecN_S_RX_state, SegText) )
        
####################################################################################################################
class KaldiFiles:
    def __init__(self, KaldiDataOutDir,TABinputFileNameWithDir,fileName='' ):
         
         self.KaldiDataOutDir   = KaldiDataOutDir
         self.text      = open(os.path.join(KaldiDataOutDir, fileName+'text'), 'a', encoding='utf8')
         self.text_bk      = open(os.path.join(KaldiDataOutDir, fileName+'text.bk'), 'a', encoding='utf8')
         self.segments  = open(os.path.join(KaldiDataOutDir, fileName+'segments'), 'a', encoding='utf8')
         self.segmentsToAvoid = open(os.path.join(KaldiDataOutDir, fileName+'segmentsToAvoid'), 'a', encoding='utf8')
         self.utt2spk   = open(os.path.join(KaldiDataOutDir, fileName+'utt2spk'), 'a', encoding='utf8')
         self.reco2file_and_channel  = open(os.path.join(KaldiDataOutDir, fileName+'reco2file_and_channel'), 'a', encoding='utf8')
         self.wavscp   = open(os.path.join(KaldiDataOutDir, fileName+'wav.scp'), 'a', encoding='utf8')

    def Close(self):
        self.text.close()
        self.text_bk.close()
        self.segments.close()
        self.segmentsToAvoid.close()
        self.utt2spk.close()
        self.reco2file_and_channel.close()
        self.wavscp.close()         

####################################################################################################################
def ParseArgs():
    parser = argparse.ArgumentParser(description="update me"
                                     " and me too"
                                     "Usage: python CTMedit2KaldiData.py  <TAB file name> <Orig kaldi data dir>  <kaldi out data dir> "
                                     "E.g. Usage: python CTMedit2KaldiData.py $out_dir/lattice_oracle/ctm_edits $data_out/src $out_dir/clean_seg_data",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument("TABinputFileName",  help = "TAB Input File name")
    parser.add_argument("KaldiDataOutDir",   help = "output kaldi data dir")
    parser.add_argument("-RmRxNx",             help = "RmRxNx          : 1 to remove RX NX entries          0 to leave entries as is", default = '1')
    parser.add_argument("-RmSnoTxt",           help = "RmSnoTxt        : 1 to remove S entries with no text 0 to leave entries as is", default = '1')
    parser.add_argument("-RmSingleNs",      help = "RmSingleNs   : 1 to remove Single N entries       0 to leave entries as is", default = '1')
    parser.add_argument("-MaxGap",           help = "Max Gap between 2 following segment to be merged- default 2 sec",  default = '2')
    parser.add_argument("-MaxPtt",           help = "Maximum segment length ", default = '40.0')
 
    print(' '.join(sys.argv))
    args = parser.parse_args()
    return args
####################################################################################################################

def createDir(dir_name):
    try:
        os.stat(dir_name)
    except:
        os.makedirs(dir_name)

####################################################################################################################

def GetTABedits(TABinputFileName,RmSnoTxt):
    TabEditNumFieldsLong = 8
    TabEditNumFieldsShort = 6
    AlignedWordList = []
    for indx, line in enumerate(open(TABinputFileName)):
        tok  = re.split("[, \t\r\n]+", line)
        num_tok=len(tok)
        TabWord = TabEntry()
        if num_tok==TabEditNumFieldsShort:
             TabWord.setTabEntry(tok[0],tok[1], float(tok[2]),float(tok[3]), tok[4], tok[5])
        else :
             TabWord.setTabEntry(tok[0],tok[1], float(tok[2]),float(tok[3]), tok[4], tok[5],tok[6]+' '+tok[7])
             tok_index = TabEditNumFieldsLong
             if num_tok> tok_index:
                while (num_tok-1)> tok_index:
                    TabWord.AddWord(tok[tok_index])
                    tok_index = tok_index+1
    
             else:
                 if (TabWord.sRecN_S_RX_state=='S')&(RmSnoTxt==1):
                     TabWord.sRecN_S_RX_state='SnoTxt'
                     #TabWord.AddWord('<SnoTxt>')  
                          
        ##--##TabWord.printTabentry()
        AlignedWordList.append(TabWord)
    AlignedWordList.sort(key=lambda x: x.fBegSec)
    return AlignedWordList


####################################################################################################################
def IntoMerge1(CurRecTabs,iTabIdx,Seg,SegStLoN, SegEnLoN,Reverse_index_required,SegSeqSizeIndex,SegMaxGap,MergedSegDuration, MaxGap, MaxPtt,Afterreverse):
    
    startMergedToTrim=0
    endMergedToTrim=0
    #SegSeqSizeIndex=0
    startMergedSeg=0
    endMergedSeg=0
    SegMaxPtt=0
    
    ListLength=len(CurRecTabs)
    
    while ((ListLength-1>(iTabIdx+SegSeqSizeIndex))&(SegMaxGap==0)&
           ((CurRecTabs[iTabIdx].sRecN_S_RX_state =="S")|(CurRecTabs[iTabIdx].sRecN_S_RX_state =="NS"))&
           ((CurRecTabs[iTabIdx+SegSeqSizeIndex].sRecN_S_RX_state =="S")|(CurRecTabs[iTabIdx+SegSeqSizeIndex].sRecN_S_RX_state =="NS"))&
           (MergedSegDuration <= MaxPtt)):

            if ((SegSeqSizeIndex>1)&(CurRecTabs[iTabIdx+SegSeqSizeIndex-1].sRecN_S_RX_state =="NS")&
               ((CurRecTabs[iTabIdx+SegSeqSizeIndex-1].fEndSec - CurRecTabs[iTabIdx+SegSeqSizeIndex-1].fBegSec)>MaxGap)):
                SegMaxGap=1

            if len(CurRecTabs)>iTabIdx+SegSeqSizeIndex:
                if ((CurRecTabs[iTabIdx].sRecN_S_RX_state =="NS")& ((CurRecTabs[iTabIdx].fEndSec - CurRecTabs[iTabIdx].fBegSec)>MaxGap)):
                     startMergedSeg = CurRecTabs[iTabIdx].fEndSec-(MaxGap/2)
                     startMergedToTrim=1
                else:
                     startMergedSeg=  CurRecTabs[iTabIdx].fBegSec
                if (CurRecTabs[iTabIdx+SegSeqSizeIndex].sRecN_S_RX_state =="NS")&((CurRecTabs[iTabIdx+SegSeqSizeIndex].fEndSec - CurRecTabs[iTabIdx+SegSeqSizeIndex].fBegSec)>MaxGap):
                     endMergedSeg =   CurRecTabs[iTabIdx+SegSeqSizeIndex].fBegSec+(MaxGap/2)
                     endMergedToTrim=1
                else:
                     endMergedSeg =   CurRecTabs[iTabIdx+SegSeqSizeIndex].fEndSec  
                MergedSegDuration =  endMergedSeg - startMergedSeg
                ##--##print (' startMergedSeg endMergedSeg' ,startMergedSeg, endMergedSeg,'MergedSegDuration',MergedSegDuration, SegSeqSizeIndex )
            if (MergedSegDuration<=MaxPtt)&(SegMaxGap==0):
                SegSeqSizeIndex=SegSeqSizeIndex+1
            if endMergedToTrim:    
                SegMaxGap=1   
    if (MergedSegDuration > MaxPtt)   :
        SegMaxPtt=1
        if ( SegSeqSizeIndex>1):
           SegSeqSizeIndex=SegSeqSizeIndex-1
           #################
           if len(CurRecTabs)>iTabIdx+SegSeqSizeIndex:
                if ((CurRecTabs[iTabIdx].sRecN_S_RX_state =="NS")& ((CurRecTabs[iTabIdx].fEndSec - CurRecTabs[iTabIdx].fBegSec)>MaxGap)):
                     startMergedSeg = CurRecTabs[iTabIdx].fEndSec-(MaxGap/2)
                     startMergedToTrim=1
                else:
                     startMergedSeg=  CurRecTabs[iTabIdx].fBegSec
                if (CurRecTabs[iTabIdx+SegSeqSizeIndex].sRecN_S_RX_state =="NS")&((CurRecTabs[iTabIdx+SegSeqSizeIndex].fEndSec - CurRecTabs[iTabIdx+SegSeqSizeIndex].fBegSec)>MaxGap):
                     endMergedSeg =   CurRecTabs[iTabIdx+SegSeqSizeIndex].fBegSec+(MaxGap/2)
                     endMergedToTrim=1
                else:
                     endMergedSeg =   CurRecTabs[iTabIdx+SegSeqSizeIndex].fEndSec  
                MergedSegDuration =  endMergedSeg - startMergedSeg
                ##--##print (' startMergedSeg endMergedSeg' ,startMergedSeg, endMergedSeg,'MergedSegDuration',MergedSegDuration, SegSeqSizeIndex )


           #################

   
    if (CurRecTabs[iTabIdx+SegSeqSizeIndex-1].sRecN_S_RX_state =="NS")&((CurRecTabs[iTabIdx+SegSeqSizeIndex-1].fEndSec - CurRecTabs[iTabIdx+SegSeqSizeIndex-1].fBegSec)>MaxGap):
        SegMaxGap=1
    if endMergedToTrim:
        if ((ListLength-1)>(iTabIdx+SegSeqSizeIndex)):
           if (CurRecTabs[iTabIdx+SegSeqSizeIndex].sRecN_S_RX_state =="S")&(SegSeqSizeIndex > 1):
        
            ##--##print 'reverse----------'
            Reverse_index_required=1
    #print   ('---SegSeqSizeIndex :',SegSeqSizeIndex,)        
    if (SegSeqSizeIndex > 1):
                
                Seg.setSegEntry(' ', startMergedSeg, endMergedSeg,' ',CurRecTabs[iTabIdx].sAudioFileName,'NS_S')
                if Seg.TextWords == []:
                    SegText = ''
                    textcounter=0
                    while (textcounter < SegSeqSizeIndex):
                        for w in CurRecTabs[iTabIdx+textcounter].sTextWords:
                            SegText = SegText + w + ' '
                        if CurRecTabs[iTabIdx+textcounter].sRecN_S_RX_state=="NS":
                            SegText = SegText +'<noise> '
                        textcounter=textcounter+1  
                    Seg.AddWord('{}'.format(SegText))
                Seg.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
                ##--##Seg.printSegEntry()

                if startMergedToTrim:
                    if Afterreverse:
                        Afterreverse=0
                    else:

                                ###########################
                            #if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                            #SegStLoN = SegEntry()
                            SegStLoN.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName, CurRecTabs[iTabIdx].fBegSec, startMergedSeg,  ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                            SegStLoN.sRecN_S_RX_state= CurRecTabs[iTabIdx].sRecN_S_RX_state
                            SegStLoN.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
                            #SegToAvoidList.append(SegLoN)
                
                if (endMergedToTrim & (Reverse_index_required==0)):
                    ###########################
                   #if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                   #SegEnLoN = SegEntry()
                   SegEnLoN.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName,endMergedSeg, CurRecTabs[iTabIdx+SegSeqSizeIndex-1].fEndSec, ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                   SegEnLoN.sRecN_S_RX_state= CurRecTabs[iTabIdx].sRecN_S_RX_state
                   SegEnLoN.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
                   #SegToAvoidList.append(SegLoN)


                    ###########################
                if (SegMaxPtt):
                    iTabIdx = iTabIdx + SegSeqSizeIndex
                else:
                    iTabIdx = iTabIdx + SegSeqSizeIndex-1 

                
    ##--##print   ('Reverse_index_required: ',Reverse_index_required, 'SegSeqSizeIndex :',SegSeqSizeIndex,' startMergedToTrim:',startMergedToTrim,' endMergedToTrim:',endMergedToTrim,'startMergedSeg:', startMergedSeg,'endMergedSeg:',endMergedSeg, ' iTabIdx: ', iTabIdx)
 
    return SegSeqSizeIndex , iTabIdx,Seg, Reverse_index_required , SegMaxGap , startMergedToTrim,SegStLoN, endMergedToTrim,SegEnLoN,Afterreverse 
    
####################################################################################################################


def MergeSegments(CurRecTabs, SegList,SegToAvoidList, MaxGap, MaxPtt, RmRxNx,RmSnoTxt,RmSingleNs):
 
    CurRecTabs.sort(key=lambda x: x.fBegSec)
    iTabIdx = 0
    Afterreverse=0
    MergedSegDuration = 0
    Reverse_index_required=0
    Seg = SegEntry()
    ##--##print "MergeSegments"
    ListLength=len(CurRecTabs)
    while iTabIdx < (len(CurRecTabs)-1):
            Seg = SegEntry()
            SegMaxGap=0
            StartSegSeqIndx=iTabIdx
            SegSeqSizeIndex=1
            SegStLoN= SegEntry()
            SegEnLoN = SegEntry()
            # IntoMerge define the group of the sequential TabsEntries in order to merge them to one segment and thir merging format
            SegSeqSizeIndex, iTabIdx, Seg, Reverse_index_required ,SegMaxGap,startMergedToTrim,SegStLoN, endMergedToTrim,SegEnLoN,Afterreverse = IntoMerge1(CurRecTabs,iTabIdx,Seg,SegStLoN, SegEnLoN,Reverse_index_required,SegSeqSizeIndex,SegMaxGap,MergedSegDuration, MaxGap, MaxPtt,Afterreverse)###
            if startMergedToTrim:
                #print('-startMergedToTrim--')
                SegStLoN.printSegEntry()
                SegToAvoidList.append(SegStLoN)
            if (endMergedToTrim & (Reverse_index_required==0)):
                #print('-endMergedToTrim--')
                SegEnLoN.printSegEntry()
                SegToAvoidList.append(SegEnLoN)

            #SegSeqSizeIndex, iTabIdx,Reverse_index_required ,SegMaxGap= IntoMerge(CurRecTabs,iTabIdx,Reverse_index_required,SegSeqSizeIndex,SegMaxGap,MergedSegDuration, MaxGap, MaxPtt)###
            ##--##print   ('SegSeqSizeIndex :', SegSeqSizeIndex)
            
            if (SegSeqSizeIndex > 1):#Merge required
                #SegSeqSizeIndex, iTabIdx , Seg= MergeingSeq(Seg, CurRecTabs, iTabIdx, SegSeqSizeIndex,  MaxGap )
                #SegSeqSizeIndex, iTabIdx , Seg= MergeingSeq1(Seg, CurRecTabs, iTabIdx, SegSeqSizeIndex, MaxGap,startMergedToTrim,endMergedToTrim )
                 #print 'tmp'
                 stam=1
            else:# Not to merge 
                    Seg.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName, CurRecTabs[iTabIdx].fBegSec, CurRecTabs[iTabIdx].fEndSec,  ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                    MergedSegDuration=0
                    SegSeqSizeIndex=0
                    
                    if Seg.TextWords == []:
                        SegText = ''
                        for w in CurRecTabs[iTabIdx].sTextWords:
                            SegText = SegText + w + ' '
                        if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                            SegText = SegText +'<noise>'
                        Seg.AddWord('{}'.format(SegText))
                        if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                            Seg.sRecN_S_RX_state="SingleNoise"
                        else:
                            Seg.sRecN_S_RX_state=CurRecTabs[iTabIdx].sRecN_S_RX_state
                        Seg.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
                        #Seg.printSegEntry()
            
            if ( (((RmRxNx==1)&(Seg.sRecN_S_RX_state!="RX")&( Seg.sRecN_S_RX_state!="NT"))|(RmRxNx==0))&
                 (((RmSnoTxt==1)&(Seg.sRecN_S_RX_state!="SnoTxt"))                        |(RmSnoTxt==0))&
                 (((RmSingleNs==1)&(Seg.sRecN_S_RX_state!="SingleNoise"))                 |(RmSingleNs==0)) ):
                   SegList.append(Seg)
            else:
                   SegToAvoidList.append(Seg)
                
            if (Reverse_index_required==0):
                iTabIdx = iTabIdx + 1 
            else:######leftovers_noise of long noise that trimmed goes to "segement to avoid list"
                if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                   Afterreverse=1 
                   SegLoN = SegEntry()
                   SegLoN.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName, CurRecTabs[iTabIdx].fBegSec+(MaxGap/2), CurRecTabs[iTabIdx].fEndSec-(MaxGap/2),  ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                   SegLoN.sRecN_S_RX_state= CurRecTabs[iTabIdx].sRecN_S_RX_state
                   SegLoN.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
                   SegToAvoidList.append(SegLoN)
                Reverse_index_required=0
            SegMaxGap=0  
    '''    
    print "segment list len after first mege {}:"%( len(SegList))
    for Seg in SegList:
            Seg.printSegEntry()          
    '''
####################################################################################################################
def MergeSegmentsToAvoid(SegToAvoidList, MergedSegListToAvoid, MaxGap, MaxPtt):
 
    SegToAvoidList.sort(key=lambda x: x.fBegSec)
    iTabIdx = 0
    MergedSegDuration = 0
    Seg = SegEntry()
    #print "MergeSegmentsToAvoid"
    ListLength=len(SegToAvoidList)
    while iTabIdx < (len(SegToAvoidList)-1):
            Seg = SegEntry()
            StartSegSeqIndx=iTabIdx
            SegSeqSizeIndex=1
            # Here we define the group of the sequential TabsEntries in order to merge them to one segment
            while ((ListLength-1>(iTabIdx+SegSeqSizeIndex))&((SegToAvoidList[iTabIdx+(SegSeqSizeIndex-1)].fEndSec==SegToAvoidList[iTabIdx+SegSeqSizeIndex].fBegSec))):
                   if len(SegToAvoidList)>iTabIdx+SegSeqSizeIndex:
                        SegSeqSizeIndex=SegSeqSizeIndex+1

            if (SegSeqSizeIndex > 1): #Merge required
                Seg.setSegEntry(' ', SegToAvoidList[iTabIdx].fBegSec, SegToAvoidList[iTabIdx+SegSeqSizeIndex-1].fEndSec,  ' ',SegToAvoidList[iTabIdx].sAudioFileName,'NS_S')
                Seg.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
                iTabIdx = iTabIdx + SegSeqSizeIndex-1 
                SegSeqSizeIndex=0
            else:# Not to merge 
                Seg.setSegEntry(SegToAvoidList[iTabIdx].sAudioFileName, SegToAvoidList[iTabIdx].fBegSec, SegToAvoidList[iTabIdx].fEndSec,  ' ',SegToAvoidList[iTabIdx].sAudioFileName,SegToAvoidList[iTabIdx].sRecN_S_RX_state)
                SegSeqSizeIndex=0
                Seg.sSegKey = '{}-{:06d}-{:06d}'.format(Seg.sAudioFileName, int(Seg.fBegSec*100), int(Seg.fEndSec*100))
            
            MergedSegListToAvoid.append(Seg)
            iTabIdx = iTabIdx + 1  

    #print "MergedSegListToAvoid list len after first mege {}:"%( len(MergedSegListToAvoid))
    #for Seg in MergedSegListToAvoid:
    #        Seg.printSegEntry()          

####################################################################################################################
def replace_all(text):

    dic = {
        "%أم": 	 "(%أم)",
        "%أه"  :  "(%أه)",
        "%أهه":"(%أهه)",
        "%أوو":"(%أوو)",
        "%إيه":"(%إيه)",
        "%تداخل":"",
        "%أصوات":"<noise>",
        "%إنقطاع":" <silence>", 
        "%تنفس":"<v-noise>",
        "%سعال":"<v-noise>",
        "%صمت":"<silence>",
        "%ضجة":"<noise>",
        "%ضحك":" <v-noise>",
        "%عطس":"<v-noise>",
        "%متكلمجديد":"",
        "%مهم":"(%مهم)",
        "%موسيقى":" <noise>",
        "%هاي" : "(%هاي)",
        "%هم" : "(%هم)",
        "<cough/>":"<v-noise>",
        "<laugh>  </laugh>":"<v-noise>"
         }
    
    x = text.count("%تداخل\ ")
    if (x):
       text=text.replace("%تداخل\ ", "",x)
    x = text.count("%ضجة\ ")
    if (x):
       text=text.replace("%ضجة\ ", "",x)   
    x = text.count("%متكلمجديد\ ")
    if (x):
       text=text.replace("%متكلمجديد\ ", "",x)     

    for i, j in dic.items():
        text = text.replace(i, j)
    
    return text
####################################################################################################################

def WriteKaldiData(SegList, KaldiFiles, RecId, TABinputFileNameWithDir):
    SegList.sort(key=lambda x: x.fBegSec)#
    for Seg in SegList:#
        KaldiFiles.utt2spk.write('{} {}\n'.format(Seg.sSegKey, Seg.sAudioFileName))#
        SegText = ''#
        for w in Seg.TextWords:#
            SegText = SegText + w + ' '#
        KaldiFiles.text.write('{} {}\n'.format(Seg.sSegKey, SegText.strip()))#--
        KaldiFiles.segments.write('{} {} {:07.3f} {:07.3f}\n'.format(Seg.sSegKey, RecId, Seg.fBegSec,  Seg.fEndSec))#
    KaldiFiles.reco2file_and_channel.write('{} {} A\n'.format(RecId, RecId))#
    AudiofileNameAndPath = TABinputFileNameWithDir.replace("/sad/","/audio/").replace('.tab','.flac')#
    KaldiFiles.wavscp.write('{} sox {} -b 16 -r 8000 -t wavpcm - |\n'.format(RecId, AudiofileNameAndPath))#    
####################################################################################################################

def WriteKaldiData_Alv_WithTextReplaceing(SegList, KaldiFiles, RecId, TABinputFileNameWithDir):
    SegList.sort(key=lambda x: x.fBegSec)#
    for Seg in SegList:#
        
        KaldiFiles.utt2spk.write('{} {}\n'.format(Seg.sSegKey, Seg.sAudioFileName))#
        SegText = ''#
        FixedText=''#-
        for w in Seg.TextWords:#
            SegText = SegText + w + ' '#
        KaldiFiles.text_bk.write('{} {}\n'.format(Seg.sSegKey, SegText.strip()))#-
        FixedText=replace_all('{}'.format(SegText.strip()))
        KaldiFiles.text.write('{} {}\n'.format(Seg.sSegKey, FixedText))#-
        KaldiFiles.segments.write('{} {} {:07.3f} {:07.3f}\n'.format(Seg.sSegKey, RecId, Seg.fBegSec,  Seg.fEndSec))#
    KaldiFiles.reco2file_and_channel.write('{} {} A\n'.format(RecId, RecId))#
    AudiofileNameAndPath = TABinputFileNameWithDir.replace('/sad/','/audio/').replace('.tab','.flac')#
    KaldiFiles.wavscp.write('{} sox {} -b 16 -r 8000 -t wavpcm - |\n'.format(RecId, AudiofileNameAndPath))#
    
####################################################################################################################

def WriteKaldiDataSegmentsToAvoid(SegToAvoidList, KaldiFiles, RecId):
    for Seg in SegToAvoidList:
        KaldiFiles.segmentsToAvoid.write('{} {} {:07.3f} {:07.3f}\n'.format(Seg.sSegKey, RecId, Seg.fBegSec,  Seg.fEndSec))

#################################################################################################################
if __name__ == '__main__':

    args = ParseArgs()
    # reload(sys)
    # sys.setdefaultencoding('utf8')
    
	# Description:
	# Get files from ...... bla bla,
	
    print ('Tab Input File name:         {}'.format(args.TABinputFileName) )
    print ('Kaldi Data Output dir:       {}'.format(args.KaldiDataOutDir) )
    '''
         mypath = TABinputFileNameWithDir
         directories = mypath.split("/")
         fileName = args.TABinputFileName[-1].split(".")[0]
    '''
    fileName__=args.TABinputFileName
    
    fileExt=fileName__.split(".")[1]
    #print ('fileExt',fileExt)
    if (fileExt=='tab'):

        RmRxNx             = int(args.RmRxNx)
        RmSnoTxt           = int(args.RmSnoTxt)
        RmSingleNs         = int(args.RmSingleNs)
        MaxGap             = float(args.MaxGap)
        MaxPtt             = float(args.MaxPtt)
    
        if RmRxNx == 1:
            print ('Remove  RX NT Tab Entries')
        else:
            print ('Include RX NT Tab Entries')
        if RmSnoTxt == 1:
            print ('Remove  S Tab Entries without text')
        else:
            print ('Include S Tab Entries without text')
        if RmSingleNs == 1:
            print ('Remove  Single NS Tab Entries')
        else:
            print ('Include Single NS Tab Entries')       
        print ('MaxGap     [sec]  {}'.format(MaxGap) )
        print ('MaxPtt     [sec]  {}'.format(MaxPtt) )
    
        
        createDir(args.KaldiDataOutDir)
        
        KaldiFiles = KaldiFiles(args.KaldiDataOutDir,args.TABinputFileName)
        
        TABwordsList = GetTABedits(args.TABinputFileName,RmSnoTxt)
        
        # Get words, merge to segments and for each recording update Kaldi data files 
        CurRecKey =  [] 
        CurRecTabs = []
        CurRecNwords = 0
        for TabEntry in TABwordsList:
            # Running on words collecting them for one recording
            if CurRecKey == []: # First recording
                CurRecKey = TabEntry.sAudioFileName
                CurRecTabs.append(TabEntry)
                CurRecNwords = 1
            else: # Other recording
                if TabEntry.sAudioFileName == CurRecKey:
                    CurRecTabs.append(TabEntry)
                    CurRecNwords = CurRecNwords + 1
    
        SegOutList = []
        SegToAvoidList = []
        MergedSegListToAvoid=[]

        RetVal =  MergeSegments(CurRecTabs, SegOutList, SegToAvoidList, MaxGap, MaxPtt, RmRxNx, RmSnoTxt, RmSingleNs)
        MergeSegmentsToAvoid(SegToAvoidList, MergedSegListToAvoid, MaxGap, MaxPtt)
        WriteKaldiData_Alv_WithTextReplaceing(SegOutList, KaldiFiles, CurRecKey,args.TABinputFileName)
        WriteKaldiDataSegmentsToAvoid(MergedSegListToAvoid, KaldiFiles, CurRecKey)
        
        KaldiFiles.Close()
   
####################################################################################################################   
