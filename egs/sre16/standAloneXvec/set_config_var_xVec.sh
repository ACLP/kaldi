
shared_foler=/storage/kaldi-trunk/egs/sre16/rani/
testFileNames_relPath=$input_file
input_folder=$shared_foler/inputData
dbname=flask
train_wav_spkr=$input_folder/train_files_utt.txt
output_json=$shared_foler/results_xvec.json

run_path=/storage/kaldi-trunk/egs/sre16/rani/xVec #/media/win-docekr_share/xVec  #/media/6GB/nir/xVec_tmpFiles
eg_path=/storage/kaldi-trunk/egs/sre16/rani/xVec # /media/win-docekr_share/xVec #/kaldi/egs/xVec
mfccdir=${run_path}/mfcc
vaddir=${run_path}/mfcc
trials=${run_path}/data/${dbname}_test/trials
nnet_dir=${eg_path}/exp/xvector_nnet_1a
n_jobs_mfcc=1
n_jobs_ivec=1
stage=25
