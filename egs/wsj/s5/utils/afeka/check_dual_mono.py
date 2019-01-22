from __future__ import print_function
import sys
import os
import wave24
import numpy as np
import scipy.io.wavfile as siw
import scipy.stats as ss

def eprint(*args, **kwargs):
    print("err>>", *args, file=sys.stderr, **kwargs)

def dual_mono(fname):
	samprate,data = siw.read(fname)
	spearman=ss.spearmanr(data[:,0],data[:,1])[0]
	return spearman>0.7
	# c1 = data[:,0]
	# c2 = data[:,1]
	# diff = abs(c1-c2)
	# mean_d = sum(diff)*1.0/len(diff)
	# max_d = max(diff)
	# zeros = np.where(diff==0)[0]
	# zerop = len(zeros)*100.0/len(diff)

	# eprint("%0: ",zerop, "(", len(zeros), "/", len(diff), ")")
	# eprint("mean-diff = ",mean_d)
	# eprint("max-diff = ",max_d)

	# hist_d,e = np.histogram(diff, bins=128)
	#eprint(e)
	# eprint("histogram of diff (%.4f - %.4f):" % (e[0],e[-1]))
	# eprint(hist_d)
	# hist_c1,e = np.histogram(c1, bins=128)
	# eprint("histogram of c1 (%.4f - %.4f):" % (e[0],e[-1]))
	# eprint(hist_c1)
	# hist_c2,e = np.histogram(c2, bins=128)
	# eprint("histogram of c2 (%.4f - %.4f):" % (e[0],e[-1]))
	#eprint("histogram of c2:")
	# eprint(hist_c2)
	# return zerop>50 or max_d<2 or mean_d<0.5

if __name__ == '__main__' :
	#segname = os.path.basename(os.path.splitext(sys.argv[1])[0])
	rm = False
	fname = sys.argv[1]
	wr = wave24.open(fname,'r')
	nchan = wr.getnchannels()

	if (nchan == 1):
		#os.write(3,segname+"\t"+sys.argv[1]+"\n")
		ret=1
	elif (nchan == 2):
		if (wr._comptype != 'PCM'):
			fname = fname+".soxtmp.wav"
			os.system('sox '+sys.argv[1]+' -b 16 '+fname)
			rm=True
		if dual_mono(fname):
			#os.write(3,segname+"\t\"sox "+sys.argv[1]+" -b 16 -r 8000 -c 1 -t wavpcm - remix 1|\"\n")
			ret=1
		else:
			#os.write(3,segname+"_1\t\"sox "+sys.argv[1]+" -b 16 -r 8000 -c 1 -t wavpcm - remix 1|\"\n")
			#os.write(3,segname+"_2\t\"sox "+sys.argv[1]+" -b 16 -r 8000 -c 1 -t wavpcm - remix 2|\"\n")
			ret=2
	else:
		eprint("file not supported: "+sys.argv[1])
		ret=0

	if rm:
		os.system('rm -rf '+fname)
	wr.close()
	sys.exit(ret)
	# print("Different")
	# c1_fname = os.path.splitext(sys.argv[1])[0] + "_c1" + os.path.splitext(sys.argv[1])[1]
	# with open(c1_fname, mode="wb") as f:
		# f.write(bytearray(c1))
	# c2_fname = os.path.splitext(sys.argv[1])[0] + "_c2" + os.path.splitext(sys.argv[1])[1]
	# with open(c2_fname, mode="wb") as f:
		# f.write(bytearray(c2))


