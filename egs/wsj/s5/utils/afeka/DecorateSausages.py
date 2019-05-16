#!/usr/bin/env python

'''
Created on 5 7 2018 
@author: zeevr

Make *.sau - sausage files readable

'''
import codecs
import sys


def main(argv):
    if (len(sys.argv) != 4):
        print 'python ' + sys.argv[0] + ' <WordList> <SusagesRawText> <SausagesDecoratedOut>'
        print 'E.g.: python DecorateSausages.py $lang_or_graph/words.txt $dir/sausages/${lmwt}_${JobNum}.sau $dir/sausages/${lmwt}_${JobNum}.sau.decorated'
        sys.exit()
    WordListName = sys.argv[1]
    SusagesRawText = sys.argv[2]
    SausagesDecoratedOut = sys.argv[3]
    print 'WordListName:' + WordListName
    print 'SusagesRawText:' + SusagesRawText
    print 'SausagesDecoratedOut:' + SausagesDecoratedOut
    WordListFp = codecs.open(WordListName, 'r', encoding='utf-8')
    WordListStream = WordListFp.readlines()
    WordListFp.close()
    WordList=[]
    for line in WordListStream:
        line = line.strip()
        fields = line.split()
        WordList.append(fields[0])

    print 'Len: %d'%(len(WordList))
    #print WordList[10]
    #sys.exit()
    SusagesRawFp = codecs.open(SusagesRawText, 'r', encoding='utf-8')
    SusagesRawStream = SusagesRawFp.readlines()
    SusagesRawFp.close()
    SausagesOutFp = codecs.open(SausagesDecoratedOut, 'w', encoding='utf-8')
    for line in SusagesRawStream:
        iNumIdx=0
        TextOutLine='\n'
        line = line.strip()
        fields = line.split()
        for str in fields:
            if ((str != '[') & (str != ']')):
                iNumIdx=iNumIdx+1
            if iNumIdx%2 == 0:
                str = WordList[int(str)]
            if str == '[':
                str = '\n['
            TextOutLine=TextOutLine+str+' '
        TextOutLine=TextOutLine+'\n'
        SausagesOutFp.write(TextOutLine)
        
    SausagesOutFp.close()
	
if __name__ == "__main__":
   main(sys.argv[1:])