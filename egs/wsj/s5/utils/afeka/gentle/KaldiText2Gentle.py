#!/usr/bin/env python

'''
  File: KaldiText2Gentle.py
  Usage eg. python KaldiText2Gentle.py  <kaldi data dir> <gentle text dir>
  Reads kaldi data text file partitions text according to recording label and writes text contiguously into files 1 file per recording
  Created on 11 12 2018 
  @author: zeevr
'''
import sys
import string
import re
import os

########################
def createDir(dir_name):
    try:
        os.stat(dir_name)
    except:
        os.makedirs(dir_name)

#########################

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print 'Usage: %s <kaldi-data-dir> <gentle-text-dir>' % (sys.argv[0],)
        print 'eg. %s data/test data/GentleTextTest' % (sys.argv[0],)
        sys.exit(1)

    SegmentsFile = sys.argv[1] + "/segments"
    TextFile = sys.argv[1] + "/text"
    GentleTextDir = sys.argv[2]
    createDir(GentleTextDir)
    text_fp = open(TextFile, "r")

    CurrRecLbl=''
    out_text=''
    for indx, seg_line in enumerate(open(SegmentsFile)):
        seg_line.rstrip('\n')
        seg_tok = filter(None, re.split("[, \t\r\n]+", seg_line))
        num_seg_tok=len(seg_tok)
        if num_seg_tok != 4:
            print 'Illegal segments file format: %s'%seg_line
            sys.exit()
        SegLbl = seg_tok[0]
        RecLbl = seg_tok[1]
        #print 'SegLbl: %s RecLbl: %s\n'%(SegLbl, RecLbl)

        if (CurrRecLbl != '') & (CurrRecLbl != RecLbl):
            out_text_fp = open(GentleTextDir+"/"+CurrRecLbl+".txt", "w")
            out_text_fp.write('%s\n' % (out_text))
            #print 'TxtSegLbl: %s text: %s\n'%(TxtSegLbl, out_text)
            #sys.exit()
            out_text=''
            out_text_fp.close()
            print 'Text written to file: %s'%(GentleTextDir+"/"+CurrRecLbl+".txt")
            
        CurrRecLbl = RecLbl
        
        txt_line = text_fp.readline()
        txt_line = txt_line.rstrip('\n')
        txt_tok = filter(None, re.split("[, \t\r\n]+", txt_line))
        num_txt_tok=len(txt_tok)
        TxtSegLbl = txt_tok[0]
        if TxtSegLbl != SegLbl:
            print 'segment and text files are not in sync run utils/fix_data.sh'
            sys.exit()
 
        for i in range(1,num_txt_tok):
            out_text = out_text + ' ' + txt_tok[i]
  
    out_text_fp = open(GentleTextDir+"/"+CurrRecLbl+".txt", "w")
    out_text_fp.write('%s\n' % (out_text))
    out_text=''
    out_text_fp.close()
    print 'Text written to file: %s'%(GentleTextDir+"/"+CurrRecLbl+".txt") 
    text_fp.close()

