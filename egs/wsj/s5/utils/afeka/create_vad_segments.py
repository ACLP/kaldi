#! /usr/bin/python
# Author: Noam

import os,sys
import re

def write_segment (outfile, start, end, name):
#	sys.stderr.write("%s_%06d_%06d %s %.2f %.2f\n" % (name ,start, end, name, start/100.0, end/100.0))
	outfile.write("%s %.2f %.2f\n" % (name, start, end))
	return

def spread_ones(vad_data, expansion):

	flg = 0
	start_ndx = []
	end_ndx = []
	i = 0
	FS = 100  # 8e3
	expand = int(float(expansion)*FS)
	N = len(vad_data)
	# find expanded start-end pairs
	for i in range(N):
		if (vad_data[i]==1):
			if flg == 0:
				flg = 1
				start_ndx.append(max(0, i-expand))
		else:
			if flg == 1:
				flg = 0
				end_ndx.append(min(N-1, i-1+expand))
	#check for active segment at end-of-audio
	if flg==1:
		end_ndx.append(N-1)
		
	if (len(start_ndx) != len(end_ndx)):
		sys.stderr.write("starts and ends mismatch")
		sys.exit(3)
	
	#merge consecutive overlapping segments
	s = []
	e = []
	if (len(start_ndx) > 0):
		s.append(start_ndx[0])
		for i in range(1,len(start_ndx)):
			if (start_ndx[i] > end_ndx[i-1]):
				s.append(start_ndx[i])
				e.append(end_ndx[i-1])
		e.append(end_ndx[-1])
	
	return s, e
#                      end of function                        #
###############################################################

newkey = re.compile('\s*([a-zA-Z_0-9\.\-]+)\s+\[', re.U)
lastline = re.compile('\s*(0|1)\s*\]', re.U)
frameline = re.compile('\s*(0|1)\s*', re.U)
def next_key_value(vad_ark_file):
	val = []
	key = ""
	with open(vad_ark_file, 'r') as vad_ark:
		for line in vad_ark:
	#		print "line = "+line
			km = newkey.match(line)
			if (km!=None):
#				sys.stderr.write("New key: %s\n" % km.group(1))
				key = km.group(1)
#				val = []
			else:
				ll = lastline.match(line)
				if (ll!=None and len(val)>0):
#					sys.stderr.write("Last line: %s  __  n=%d\r" % (ll.group(0),len(val)))
					val.append(int(ll.group(1)))
					yield key, val
					val = []
#					key = ""
				else:
					fl = frameline.match(line)
					if (fl!=None):
						val.append(int(fl.group(1)))
					else:
						sys.stderr.write("Bad Line: %s" % (line))
						sys.exit(3)

if (len(sys.argv) != 4):
	print 'create_vad_segments.py <vad.ark> <out-segments> <expansion-size(sec)>'
	sys.exit(2)

with open(sys.argv[2], 'w') as vad_segments:
	for k,v in next_key_value(sys.argv[1]):
		sys.stderr.write("Processing key %s\n" % k)
		s, e = spread_ones(v, sys.argv[3])
		for i in range(len(s)):
			write_segment(vad_segments, s[i]/100.0, e[i]/100.0, k)

print 'DONE! create VAD segments'
