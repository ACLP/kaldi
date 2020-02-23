#!/usr/bin/env python
# coding=utf-8

'''
  File: RatsKwsPrepKaldiData.py 
  Usage eg. python RatsKwsPrepKaldiData.py  <Base Dir name> <Sub dir list file> <kaldi data dir> [<audio out dir>] 
  Gets .tab fles recursively from <Base Dir name> filtering sub dirs according to list in <Sub dir list file> and creates kaldi data dir files
  to given <audio out dir> is given audio files are cut 
  Created on 09 12 2019 
  @author: Shlomit
'''
import sys
import argparse
import string
import re
import os
import io
import codecs
import glob

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
        self.sTextWords.append('%s'%Word)

    def printTabentry (self):  
        TabText=''
        for w in self.sTextWords:
            TabText = TabText + w + ' '
        print "printTabentry sDbName: %s  sAudioFileName: %s fBegSec: %f fEndSec: %f sRecN_S_RX_state: %s sRecOrig_auto_part: %s sLang: %s sTextWords: %s"%(self.sDbName,self.sAudioFileName,self.fBegSec,self.fEndSec,self.sRecN_S_RX_state ,self.sRecOrig_auto_part,self.sLangOrig,TabText) 
        
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
        self.TextWords.append('%s'%Word)
    
    def printSegEntry (self):
        SegText=''
        for w in self.TextWords:
            SegText = SegText + w + ' '
        print "printSegEntry sSegKey: %s  fBegSec: %f fEndSec: %f sRecKey: %s sAudioFileName: %s sRecN_S_RX_state: %s SegText: %s "%(self.sSegKey, self.fBegSec,self.fEndSec,self.sRecKey ,self.sAudioFileName,self.sRecN_S_RX_state, SegText) 
        
####################################################################################################################
########################
'''
class KaldiFiles:
    def __init__(self, KaldiDataOutDir,TABinputFileName ):
         mypath = TABinputFileName
         directories = mypath.split("/")
         fileName = directories[-1].split(".")[0]
         self.KaldiDataOutDir   = KaldiDataOutDir
         self.text      = codecs.open(os.path.join(KaldiDataOutDir, fileName+'_text'), 'w', encoding='utf8')
         self.segments  = open(os.path.join(KaldiDataOutDir, fileName+'_segments'), 'w')
         self.utt2spk   = open(os.path.join(KaldiDataOutDir, fileName+'_utt2spk'), 'w')
    def Close(self):
        self.text.close()
        self.segments.close()
        self.utt2spk.close()
'''
#################################
####################################################################################################################
class KaldiFiles:
    def __init__(self, KaldiDataOutDir,isTxtMaP=0 ,fileName=''):
         
         self.KaldiDataOutDir   = KaldiDataOutDir
         self.text      = codecs.open(os.path.join(KaldiDataOutDir, fileName+'text'), 'w', encoding='utf8')
         if (isTxtMaP):
             self.text_bk      = codecs.open(os.path.join(KaldiDataOutDir, fileName+'text.bk'), 'w', encoding='utf8')
         self.segments  = open(os.path.join(KaldiDataOutDir, fileName+'segments'), 'w')
         self.segmentsToAvoid = open(os.path.join(KaldiDataOutDir, fileName+'segmentsToAvoid'), 'w')
         self.utt2spk   = open(os.path.join(KaldiDataOutDir, fileName+'utt2spk'), 'w')
         self.reco2file_and_channel  = open(os.path.join(KaldiDataOutDir, fileName+'reco2file_and_channel'), 'w')
         self.wavscp   = open(os.path.join(KaldiDataOutDir, fileName+'wav.scp'), 'w')
         '''
         self.KaldiDataOutDir   = KaldiDataOutDir
         self.text      = codecs.open(os.path.join(KaldiDataOutDir, fileName+'text'), 'a', encoding='utf8')
         self.text_bk      = codecs.open(os.path.join(KaldiDataOutDir, fileName+'text.bk'), 'a', encoding='utf8')
         self.segments  = open(os.path.join(KaldiDataOutDir, fileName+'segments'), 'a')
         self.segmentsToAvoid = open(os.path.join(KaldiDataOutDir, fileName+'segmentsToAvoid'), 'a')
         self.utt2spk   = open(os.path.join(KaldiDataOutDir, fileName+'utt2spk'), 'a')
         self.reco2file_and_channel  = open(os.path.join(KaldiDataOutDir, fileName+'reco2file_and_channel'), 'a')
         self.wavscp   = open(os.path.join(KaldiDataOutDir, fileName+'wav.scp'), 'a')
         '''

    def Close(self,isTxtMaP=0):
        self.text.close()
        if (isTxtMaP):
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
    
    parser.add_argument("RATS_KWS_data_loc",  help = "RATS_KWS_data_loc")
    parser.add_argument("data_name_list",     help = "data_name_list")
    parser.add_argument("data_sub_dir",       help = "data_sub_dir")
    parser.add_argument("Channels_list",      help = "Channels_list")
    #parser.add_argument("TABinputFileName",  help = "TAB Input File name")
    parser.add_argument("KaldiDataOutDir",    help = "output kaldi data dir")
    parser.add_argument("Languages_list",     help = "Languages_list")
    
    parser.add_argument("-RmRxNx",            help = "RmRxNx          : 1 to remove RX NX entries          0 to leave entries as is", default = '1')
    parser.add_argument("-RmSnoTxt",          help = "RmSnoTxt        : 1 to remove S entries with no text 0 to leave entries as is", default = '1')
    parser.add_argument("-RmSingleNs",        help = "RmSingleNs   : 1 to remove Single N entries       0 to leave entries as is", default = '1')
    parser.add_argument("-MaxGap",            help = "Max Gap between 2 following segment to be merged- default 2 sec",  default = '2')
    parser.add_argument("-MaxPtt",            help = "Maximum segment length ", default = '40.0')
    parser.add_argument("-TxtMap",            help = "Text maaping ", default = '1')
 
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
        tok  = filter(None, re.split("[, \t\r\n]+", line))
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
def MergeSegments(CurRecTabs, SegList,SegToAvoidList, MaxGap, MaxPtt, RmRxNx,RmSnoTxt,RmSingleNs):
 
    CurRecTabs.sort(key=lambda x: x.fBegSec)
    iTabIdx = Afterreverse = MergedSegDuration =  Reverse_index_required= 0
    
    Seg = SegEntry()
    ##--##print "MergeSegments"
    ListLength=len(CurRecTabs)
    while iTabIdx < (len(CurRecTabs)-1):
            Seg = SegEntry()
            StartSegSeqIndx=iTabIdx
            SegSeqSizeIndex=1
            startMergedToTrim = endMergedToTrim = startMergedSeg = endMergedSeg = SegMaxPtt = SegMaxGap = 0
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
            ##--##print   ('---SegSeqSizeIndex :',SegSeqSizeIndex,)        
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
                            Seg.AddWord('%s'% SegText)
                        ####Seg.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
                        ##--##Seg.printSegEntry()

                        if startMergedToTrim:
                            if Afterreverse:
                                Afterreverse=0
                            else:
                                SegStLoN = SegEntry()
                                SegStLoN.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName, CurRecTabs[iTabIdx].fBegSec, startMergedSeg,  ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                                SegStLoN.sRecN_S_RX_state= CurRecTabs[iTabIdx].sRecN_S_RX_state
                                SegStLoN.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
                                ##--##SegStLoN.printSegEntry()
                                SegToAvoidList.append(SegStLoN)

                        if (endMergedToTrim & (Reverse_index_required==0)):
                            SegEnLoN = SegEntry()
                            SegEnLoN.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName,endMergedSeg, CurRecTabs[iTabIdx+SegSeqSizeIndex-1].fEndSec, ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                            SegEnLoN.sRecN_S_RX_state= CurRecTabs[iTabIdx].sRecN_S_RX_state
                            SegEnLoN.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
                            ##--##SegEnLoN.printSegEntry()
                            SegToAvoidList.append(SegEnLoN)

                        if (SegMaxPtt):
                            iTabIdx = iTabIdx + SegSeqSizeIndex
                        else:
                            iTabIdx = iTabIdx + SegSeqSizeIndex-1 
            ###########################################################
            #SegSeqSizeIndex, iTabIdx,Reverse_index_required ,SegMaxGap= IntoMerge(CurRecTabs,iTabIdx,Reverse_index_required,SegSeqSizeIndex,SegMaxGap,MergedSegDuration, MaxGap, MaxPtt)###
            ##--##print   ('SegSeqSizeIndex :', SegSeqSizeIndex)
            
            if (SegSeqSizeIndex == 1): # Not to merge 
                    Seg.setSegEntry(CurRecTabs[iTabIdx].sAudioFileName, CurRecTabs[iTabIdx].fBegSec, CurRecTabs[iTabIdx].fEndSec,  ' ',CurRecTabs[iTabIdx].sAudioFileName,CurRecTabs[iTabIdx].sRecN_S_RX_state)
                    MergedSegDuration=0
                    SegSeqSizeIndex=0
                    
                    if Seg.TextWords == []:
                        SegText = ''
                        for w in CurRecTabs[iTabIdx].sTextWords:
                            SegText = SegText + w + ' '
                        if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                            SegText = SegText +'<noise>'
                        Seg.AddWord('%s'% SegText)
                        if CurRecTabs[iTabIdx].sRecN_S_RX_state=="NS":
                            Seg.sRecN_S_RX_state="SingleNoise"
                        else:
                            Seg.sRecN_S_RX_state=CurRecTabs[iTabIdx].sRecN_S_RX_state
                        ####Seg.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
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
                   SegLoN.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
                   SegToAvoidList.append(SegLoN)
                Reverse_index_required=0
            SegMaxGap=0  

    '''    
    print "segment list len after first mege %s:"%( len(SegList))
    for Seg in SegList:
            Seg.printSegEntry()          
    '''
####################################################################################################################

def MergeSegmentsToAvoid(SegToAvoidList, MergedSegListToAvoid, MaxGap, MaxPtt):
 
    SegToAvoidList.sort(key=lambda x: x.fBegSec)
    iTabIdx = MergedSegDuration = 0
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
                ####Seg.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
                iTabIdx = iTabIdx + SegSeqSizeIndex-1 
                SegSeqSizeIndex=0
            else:# Not to merge 
                Seg.setSegEntry(SegToAvoidList[iTabIdx].sAudioFileName, SegToAvoidList[iTabIdx].fBegSec, SegToAvoidList[iTabIdx].fEndSec,  ' ',SegToAvoidList[iTabIdx].sAudioFileName,SegToAvoidList[iTabIdx].sRecN_S_RX_state)
                SegSeqSizeIndex=0
                ####Seg.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
            
            MergedSegListToAvoid.append(Seg)
            iTabIdx = iTabIdx + 1  

    #print "MergedSegListToAvoid list len after first mege %s:"%( len(MergedSegListToAvoid))
    #for Seg in MergedSegListToAvoid:
    #        Seg.printSegEntry()          

####################################################################################################################
def Alv_mapping(text):

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

    for i, j in dic.iteritems():
        text = text.replace(i, j)
    
    return text
####################################################################################################################
####################################################################################################################
def replace_all(text,AlvFileToMap):
    if (AlvFileToMap==1):
        return(Alv_mapping(text))
    else:
         #print ('Warning:no mapping table to support this file language:  original text copied '  ) 
         return text   
    ### to support other Languages  

####################################################################################################################

def WriteKaldiData(SegList, KaldiFiles, RecId, TABinputFileNameWithDir,isTxtMaP,AlvFileToMap,data_sub_dir):
    SegList.sort(key=lambda x: x.fBegSec)#
    for Seg in SegList:#
        Seg.sSegKey = '%s-%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
        KaldiFiles.utt2spk.write('%s %s\n'%(Seg.sSegKey, Seg.sAudioFileName))#
        SegText = ''#
        FixedText=''#-
        for w in Seg.TextWords:#
            SegText = SegText + w + ' '#
        if (isTxtMaP==1):
            KaldiFiles.text_bk.write('%s %s\n'%(Seg.sSegKey, SegText.strip()))#-
            FixedText=replace_all('%s'% SegText.strip(),AlvFileToMap)#-
            KaldiFiles.text.write('%s %s\n'%(Seg.sSegKey, FixedText))#-
        else:
            KaldiFiles.text.write('%s %s\n'%(Seg.sSegKey, SegText.strip()))#-    
    KaldiFiles.segments.write('%s %s %07.3f %07.3f\n'%(Seg.sSegKey, RecId, Seg.fBegSec,  Seg.fEndSec))#
    KaldiFiles.reco2file_and_channel.write('%s %s A\n'%(RecId, RecId))#
    file_path = TABinputFileNameWithDir#
    if (data_sub_dir =='/kws/alv/'):
       AudiofileNameAndPath = file_path.replace('/kws/','/audio/')#
    else:
        if (data_sub_dir =='/sad/'): 
            AudiofileNameAndPath = file_path.replace('/sad/','/audio/') 
        else:
                print ('Warning: path not clear to find audio file location, (.sh data_sub_dir not supported)') 
    AudiofileNameAndPath = AudiofileNameAndPath.replace('.tab','.flac')#
    KaldiFiles.wavscp.write('%s sox %s -b 16 -r 8000 -t wavpcm - |\n'%(RecId, AudiofileNameAndPath))#
    
####################################################################################################################

def WriteKaldiDataSegmentsToAvoid(SegToAvoidList, KaldiFiles, RecId):
    for Seg in SegToAvoidList:
        Seg.sSegKey = '%s_%06d_%06d'%(Seg.sAudioFileName, Seg.fBegSec*100, Seg.fEndSec*100)
        KaldiFiles.segmentsToAvoid.write('%s %s %07.3f %07.3f\n'%(Seg.sSegKey, RecId, Seg.fBegSec,  Seg.fEndSec))

#################################################################################################################
if __name__ == '__main__':
    

    args = ParseArgs()
    reload(sys)
    sys.setdefaultencoding('utf8')
    print'-----------'
	# Description:
	# Get files from ...... bla bla,
	
    print 'RATS_KWS_data_loc    : %s'%(args.RATS_KWS_data_loc)
    print 'data_name_list       : %s'%(args.data_name_list)
    print 'data_sub_dir         : %s'%(args.data_sub_dir)
    print 'Channels_list        : %s'%(args.Channels_list)
    #print 'Tab Input File name : %s'%(args.TABinputFileName)
    print 'Kaldi Data Output dir: %s'%(args.KaldiDataOutDir) 
    print 'Languages_list       : %s'%(args.Languages_list)
    
    data_name_list=args.data_name_list.split(",")
    Channels_list=args.Channels_list.split(",")
    Languages_list=args.Languages_list.split(",")
    

    RmRxNx             = int(args.RmRxNx)
    RmSnoTxt           = int(args.RmSnoTxt)
    RmSingleNs         = int(args.RmSingleNs)
    MaxGap             = float(args.MaxGap)
    MaxPtt             = float(args.MaxPtt)
    TxtMap             = int(args.TxtMap)
    
    
    if RmRxNx == 1:
        print 'Remove  RX NT Tab Entries'
    else:
        print 'Include RX NT Tab Entries'
    if RmSnoTxt == 1:
        print 'Remove  S Tab Entries without text'
    else:
        print 'Include S Tab Entries without text'
    if RmSingleNs == 1:
        print 'Remove  Single NS Tab Entries'
    else:
        print 'Include Single NS Tab Entries'        
    print 'MaxGap     [sec]  %f'%(MaxGap) 
    print 'MaxPtt     [sec]  %f'%(MaxPtt) 
    if TxtMap == 1:
        print 'Text mapping'
    else:
        print 'No Text maaping'
    SupportLangAlv    =0 #for mapping 
    AlvFileToMap=0
    for l in Languages_list:
        if (l=='_alv_'):
            SupportLangAlv=1
    
    
    createDir(args.KaldiDataOutDir)
    
    KaldiFiles = KaldiFiles(args.KaldiDataOutDir,TxtMap)
    for x in data_name_list:
	    for m in Channels_list:
             fileDirectory= (args.RATS_KWS_data_loc+'/'+x + args.data_sub_dir + m +'/*.tab')
             for TabFilename in glob.glob(fileDirectory):
                    print (TabFilename)
                    for l in Languages_list:
                         if(TabFilename.count(l)> 0):#chacking the languge
                           
                            fileName__=TabFilename
                            #fileName__=args.TABinputFileName
                            
                            fileExt=fileName__.split(".")[1]
                            #print ('fileExt',fileExt)
                            if (fileExt=='tab'):
                                
                                TABwordsList = GetTABedits(TabFilename,RmSnoTxt)
                                                    
                                # Get words, merge to segments and for each recording update Kaldi data files 
                                CurRecKey =  [] 
                                CurRecTabs = []
                                CurRecNwords = 0
                                
                                for TabEntry1 in TABwordsList:
                                    #print ('*')
                                
                                    # Running on words collecting them for one recording
                                    if CurRecKey == []: # First recording
                                        CurRecKey = TabEntry1.sAudioFileName
                                        CurRecTabs.append(TabEntry1)
                                        CurRecNwords = 1
                                    
                                    else: # Other recording
                                        if TabEntry1.sAudioFileName == CurRecKey:
                                            CurRecTabs.append(TabEntry1)
                                            CurRecNwords = CurRecNwords + 1
                                
                                SegOutList = []
                                SegToAvoidList = []
                                MergedSegListToAvoid=[]

                                RetVal =  MergeSegments(CurRecTabs, SegOutList, SegToAvoidList, MaxGap, MaxPtt, RmRxNx, RmSnoTxt, RmSingleNs)
                                MergeSegmentsToAvoid(SegToAvoidList, MergedSegListToAvoid, MaxGap, MaxPtt)
                                
                                if (SupportLangAlv)&((TabFilename.count('_alv_')> 0)):
                                    
                                    AlvFileToMap=1
                                WriteKaldiData(SegOutList, KaldiFiles, CurRecKey,TabFilename,TxtMap,AlvFileToMap,args.data_sub_dir)
                                
                                WriteKaldiDataSegmentsToAvoid(MergedSegListToAvoid, KaldiFiles, CurRecKey)
                                
                         else:
                                 print ('Language not in list , (.sh file Languages_list in format: _lng_ )',TabFilename)

                        
                        
    KaldiFiles.Close(TxtMap)
    
####################################################################################################################   