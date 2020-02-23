Kaldi uasage (score is based on best window of best training file):

**Training speaker models:
cd xVec
./run_xVec_train_speakers.sh ../inputData/example_audio/tr/train_files_utt.txt exmpl
where:
train_files_utt.txt is a file with pairs of audioFile and speakerID (path starts at ../inputData/):
./example_audio/tr/jolana1.wav jol
./example_audio/tr/jolana2.wav jol
./example_audio/tr/martina1.wav mar
./example_audio/tr/martina2.wav mar

exmpl is a string for dbname


**Testing:
./run_xVec.sh ../inputData/example_audio/tst/tests_file.txt exmpl
where: 
tests_file.txt is a file with a list of audio file (path starts at ../inputData/):
example_audio/tst/020119CN_5min.wav
example_audio/tst/020119MN_5min.wav

exmpl is a string for dbname

**Output:
results are in: exp/scores/{DBNAME}_test_scores.per_speaker:
speaker file score best_15_seconds_start best_train_file 
mar 020119MN_5min 68.21844 50 martina2
jol 020119CN_5min 66.35521 7 jolana1
jol 020119MN_5min 22.58579 6 jolana2
mar 020119CN_5min 19.20027 5 martina2

