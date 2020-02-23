from flask import Flask, jsonify
from flask import request
from logging.handlers import RotatingFileHandler
from logging import StreamHandler
import json
import subprocess
import os.path
import os
import logging
import codecs

app = Flask(__name__)

#Checking that service is responding and working properly
@app.route('/health', methods=['GET'])
def health():
    return 'Kaldi service is very healthy!'

# test by a json call
# input json: {"audio_links":["http://blabla/file1", "http://blabla/file1"]}
# this function/app was not checked!!!
@app.route('/speakerIdScoreXvecWinHttp', methods=['POST'])
def speakerIdScoreXvecWinHttp():
  input_json=request.get_json()
  f=open("TEST_FILE.txt","w") # output for next script
  for element in input_json["audio_links"]:
    f.writelines(element)
    #f.write("\n")
  f.close()
	cmd_line='/media/win-docekr_share/xVec/run_xVec_http.sh {}'.format("TEST_FILE.txt").' flask'
	res = subprocess.run([cmd_line], shell=True,cwd='/media/win-docekr_share/xVec/') 
	# load output json file
	with open('/media/win-docekr_share/results_xvec.json', encoding='utf8') as res_f:
		return jsonify(json.load(res_f))

# input json: {"audio_links":["http://blabla/file1", "http://blabla/file1"]}
@app.route('/speakerIdScoreXvecWinHttp', methods=['POST'])
def speakerIdScoreXvecWinHttp():
  input_json=request.get_json()
  f=open("TEST_FILE.txt","w") # output for next script
  for element in input_json["audio_links"]:
    f.writelines(element)
    #f.write("\n")
  f.close()
	cmd_line='/media/win-docekr_share/xVec/run_xVec_http.sh {}'.format("TEST_FILE.txt")
	res = subprocess.run([cmd_line], shell=True,cwd='/media/win-docekr_share/xVec/') 
	# load output json file
	with open('/media/win-docekr_share/results_xvec.json', encoding='utf8') as res_f:
		return jsonify(json.load(res_f))


# Score given files on all speakers from the last speakerIdTrainSpeakersXvec call using xVec algorithm.
# parameter TestsFile should point to the relative path of a text file with list of files 
# e.g. http://localhost:5001/speakerIdScoreXvec?TestsFile=inputData/tests_file.txt
# example tests_file.txt:
# ./elisra_ddc1/1/R000002_S1.wav
# ./elisra_ddc1/1/R000003_S2.wav
# Output is JSON:
# {
    # "s1 R000002_S1": "13.77218",
    # "s1 R000003_S2": "5.13802"
# }
@app.route('/speakerIdScoreXvec', methods=['GET'])
def speakerIdScoreXvec():
	tests_file = request.args.get('TestsFile')
	cmd_line='/media/win-docekr_share/xVec/run_xVec.sh {}'.format(tests_file)
	res = subprocess.run([cmd_line], shell=True,cwd='/media/win-docekr_share/xVec/') 
	# load output json file
	with open('/media/win-docekr_share/results_xvec.json', encoding='utf8') as res_f:
		return jsonify(json.load(res_f))

# set and train speakers. 
# after this call only the speakers trained here will be used.
# parameter TrainSpeakers should point to a text file with pairs of wav and speaker id
# e.g.  http://localhost:5001/speakerIdTrainSpeakersXvec?TrainSpeakers=inputData/train_files_utt_external.txt
# example train_files_utt.txt:
# ./elisra_ddc1/1/R000007_S2.wav s1
# ./elisra_ddc1/2/R000024_S1.wav s2
@app.route('/speakerIdTrainSpeakersXvec', methods=['GET'])
def speakerIdTrainSpeakersXvec():
	train_speakers = request.args.get('TrainSpeakers')
	cmd_line='/media/win-docekr_share/xVec/run_xVec_train_speakers.sh {}'.format(train_speakers)
	res = subprocess.run([cmd_line], shell=True,cwd='/media/win-docekr_share/xVec/') 	
	return 'Trained Speakers!'
	# load output json file
	#with open('/media/win-docekr_share/results_xvec.json', encoding='utf8') as res_f:
	#	return jsonify(json.load(res_f))

# Score given files on all speakers from the last speakerIdTrainSpeakersSupGMM call using xVec algorithm.
# parameter TestsFile should point to the relative path of a text file with list of files 
# e.g. http://localhost:5001/speakerIdScoreSupGMM?TestsFile=inputData/tests_file.txt
# example tests_file.txt:
# ./elisra_ddc1/1/R000002_S1.wav
# ./elisra_ddc1/1/R000003_S2.wav
# Output is JSON:
# {
    # "s1 R000002_S1": "13.77218",
    # "s1 R000003_S2": "5.13802"
# }
@app.route('/speakerIdScoreSupGMM', methods=['GET'])
def speakerIdScoreSupGMM():
	tests_file = request.args.get('TestsFile')
	cmd_line='/media/win-docekr_share/supGMM/run_SupGMM.sh {}'.format(tests_file)
	res = subprocess.run([cmd_line], shell=True,cwd='/media/win-docekr_share/supGMM/') 
	# load output json file
	with open('/media/win-docekr_share/results_supGMM.json', encoding='utf8') as res_f:
		return jsonify(json.load(res_f))

# set and train speakers. 
# after this call only the speakers trained here will be used.
# parameter TrainSpeakers should point to a text file with pairs of wav and speaker id
# e.g. http://localhost:5001/speakerIdTrainSpeakersSupGMM?TrainSpeakers=inputData/train_files_utt_external.txt
# example train_files_utt.txt:
# ./elisra_ddc1/1/R000007_S2.wav s1
# ./elisra_ddc1/2/R000024_S1.wav s2
@app.route('/speakerIdTrainSpeakersSupGMM', methods=['GET'])
def speakerIdTrainSpeakersSupGMM():
	train_speakers = request.args.get('TrainSpeakers')
	cmd_line='/media/win-docekr_share/supGMM/run_SupGMM_train_speakers.sh {}'.format(train_speakers)
	res = subprocess.run([cmd_line], shell=True,cwd='/media/win-docekr_share/supGMM/') 	
	return 'Trained Speakers!'

	
	


	
	#request_json = request.get_json()
	#tests_file = request_json['TestsFile']  # relative path to tests file from the shared path

	#res = subprocess.run(['/media/win-docekr_share/xVec/run_xVec.sh {}'.format(tests_file)], stdout=subprocess.PIPE, shell=True) 
    #res = subprocess.run(['/media/win-docekr_share/xVec/run_xVec.sh {}'.format(tests_file)], stdout='/media/win-docekr_share/xVec/log.stdout.txt', stderr='/media/win-docekr_share/xVec/log.stderr.txt', shell=True) 
		
		
# Indexes a new media in kaldi.
# Request - 
# { 
#		'MediaId' : 'Unique Media Id',
#		'WavFilePath' : 'Path to wav file',
#		'LanguageId' : 'Nexidia's language id',
#		'Environment' : 'Harpoons Environment'
# }
# returns the indexed media id if succesfull, otherwise returns 404.
@app.route('/index', methods=['POST'])
def index_media():
	request_json = request.get_json()
	app.logger.info('Received a request to index media. Payload: %s', request_json)

	#Request params
	#Json convention - world wide convention is lower case and underscore for word delimeter for json properties. 
	#C# convention is first letter uppercased, and no delimeter.
	#To make things easier, using C# convention for input, as I know harpoon does.
	media_id = request_json['MediaId']
	wav_file_path = request_json['WavFilePath']
	language_id = get_kaldi_language_id(request_json['LanguageId'])
	environment = request_json['Environment']

	#Running kaldi's decode phase (removing trainling newline from bash script output).
	decode_cmd='%s %s %s %s %s' % (app.kaldi_service_config['decode_bash_file'], media_id, wav_file_path, language_id, environment)
	decode_process = subprocess.Popen([decode_cmd], stdout=subprocess.PIPE, shell=True)
	decode_response = decode_process.communicate()

	output = decode_response[0]
	return_code = decode_process.returncode
	
	app.logger.info(u'Finished decoding media id %s. Return Code: %s Output: %s', media_id, return_code, output)

	if return_code == 0:
		return media_id
	else:
		return (make_error_response('Could not decode media'), 404)

#Returns the text transcription of given media, given it was previously indexed.
#If it was not previously indexed, will fail.
#The reason for the language id parameter is that media can be indexed in different languages.
@app.route('/text/<environment>/<languageId>/<mediaId>', methods=['GET'])
def get_media_text(environment, languageId, mediaId):

	app.logger.info(u'Received a request to get text from media. Environment: %s LanguageId: %s Media Id: %s', environment, languageId, mediaId)

	kaldi_language = get_kaldi_language_id(languageId)

	evaluated_tra_path = app.kaldi_service_config['tra_file_path'] % (environment, kaldi_language, mediaId)
	app.logger.info('Will extract text from the .tra file located at %s', evaluated_tra_path)

	if (os.path.isfile(evaluated_tra_path) == False):
		return (make_error_response('Could not find the .tra file of given media'), 404)

	hit_result = {}

	#Reading the tra file.
	with codecs.open(evaluated_tra_path) as tra_file:
		
		#Handling python lack of encoding support (the decode-encode magic).
		tra_hit_lines = tra_file.readlines()
		
		#Stripping to make parsing easier. NOISE_STRING is a friendlier string to work with than <noise>.
		#tra_hit_lines = map(lambda l: l.strip().replace('<noise>', app.kaldi_service_config['noise_string']), tra_hit_lines) 
		
		#We don't care for empty lines
		#tra_hit_lines = filter(lambda l: l != '', tra_hit_lines) 

		
		
	#Constructing the hits.
	#.tra file line structure - MEDIA_ID CHANNEL START_MS END_MS TEXT 
	for hit_line in tra_hit_lines:
		splitted_hit_line = hit_line.split(" ")

		#We ignore the media id column, as we know this .tra file belongs to the given media id.
		channel = splitted_hit_line[1]

		current_hit = {}
		current_hit['start_ms'] = splitted_hit_line[2]
		current_hit['end_ms'] = splitted_hit_line[3]
		current_hit['text'] = extract_hit_text(hit_line)

		if channel not in hit_result:
			hit_result[channel] = []

		hit_result[channel].append(current_hit)

	app.logger.info(u'Finished getting text hits from media. Environment: %s, Media Id: %s, Hits: %s', environment, mediaId, hit_result)
	return jsonify(hit_result)

#Searches Kaldi given a list of words.
#Request - 
# {
#		'SearchId' : 'Search Id',
#		'MediaIds' : [ 'Id1', 'Id2', ... , 'IdN' ],
#		'Conditions' : [ {}, {}, ... , {} ],
#		'LanguageId' : 'Nexidia's language id',
#		'Environment' : 'Harpoons Environment'
# }
@app.route('/search', methods=['POST'])
def search(): 

	request_json = request.get_json()
	app.logger.info('Received a request to search. Payload: %s', request_json)

	#Request params
	search_id = request_json['SearchId']
	media_ids = request_json['MediaIds']
	conditions = request_json['Conditions']
	language_id = get_kaldi_language_id(request_json['LanguageId'])
	environment = request_json['Environment']
	
	if len(conditions) > 1:
		return (make_error_response('Currently only a single condition is supported.'), 404)
	if len(conditions) == 0:
		return (make_error_response('No condition defined.'), 404)

	wd=os.path.dirname(app.kaldi_service_config['decode_bash_file'])
	
	#concat_media_ids = ",".join(media_ids)
	media_list = os.path.join(wd, '.'.join([search_id, 'media']))
	with codecs.open(media_list, 'w', encoding='utf-8') as f:
		f.writelines(u'\n'.join(media_ids))
	#concat_words = ",".join(conditions[0]['Pronunciations'])
	pron_list = os.path.join(wd, '.'.join([search_id, 'pron']))
	with codecs.open(pron_list, 'w', encoding='utf-8') as f:
		for p in conditions[0]['Pronunciations']:
			f.writelines(u'%s\t0.25\n' % p)

	#Running kaldi's search phase (removing trainling newline from bash script output).
	#search_response = subprocess.check_output([app.kaldi_service_config['search_bash_file'], search_id, concat_media_ids, concat_words, language_id, environment]).strip()
	search_cmd=' '.join([app.kaldi_service_config['search_bash_file'], search_id, media_list, pron_list, language_id, environment])
	#print search_cmd
	search_process = subprocess.Popen([search_cmd], stdout=subprocess.PIPE, shell=True)
	search_response = search_process.communicate()

	output = search_response[0]
	return_code = search_process.returncode

	app.logger.info('Finished searching. Hits: %s', output)
	#os.remove(media_list)
	#os.remove(pron_list)

	#return jsonify(json.loads(output))
	return output

#Extracts the actual text from the hit line of the .tra file.
def extract_hit_text(hit_line):
	try:
		#One-liner trick to get the n-th index of space character. 
		#Index throws ValueError if doesn't find the char.
		hit_text_index = hit_line.replace(" ", "X", 3).index(" ") 
	except ValueError:
		hit_text_index = -1

	if hit_text_index > -1:
		hit_text = hit_line[hit_text_index:]
	else:
		#NO_TEXT might be a more pleasent string to work with than an empty string.
		hit_text = app.kaldi_service_config['no_text_string']

	return hit_text.strip()

#Retrieves the correct kaldi language given the harpoon language.
def get_kaldi_language_id(harpoon_language_id):

	language_map = app.kaldi_service_config['language_map']

	if harpoon_language_id not in language_map:
		return (make_error_response('Could not find given language id in the language map from harpoon to kaldi'), 404)
	else:
		return language_map[harpoon_language_id]

#Wrapps error message as a json for easier client side work.
def make_error_response(text):
	error_response = {
		'ErrorMessage' : text
	}

	return jsonify(error_response)

if __name__=='__main__':
	app.run(debug=True, host='0.0.0.0')

