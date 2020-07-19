#!/bin/bash
## This script is used to get WER on the TCS dataset by first enhancing the multi-channel
## audio and then doing the decoding.

#author: Sachin Nayak
#From IIT Bombay, Mumbai

. ./config_eval
. ./conf/sad.conf
. ./cmd.sh
stage=1
sad_stage=0
nj=2
test_dir=dev_eval
data_set=data/dev_eval
[ -f path.sh ] && . ./path.sh
path=$1
mkdir -p data.bak
cp -rf data/* data.bak/
rm -rf data
start1=`date +%s` 

# Setting put directories
model_dir="exp/chain_cleaned_aspire/tdnn_7b"
aspire_dict_directory="acoustic_aspire_model/data/local/dict"
graph_dir="exp/chain_cleaned/tdnn_7b/graph"
build_graph=true


#If the downsampled audio already exists, then start with stage=1
if [ $stage -le 0 ]; then
echo '
#######################################################################
TCS-IITB>> Downsampling the audio
#######################################################################
'
start=`date +%s`
for lines in `ls $path/audio`; do
	num_c=$(ls $path/audio/$lines/${lines}.CH* | wc -l)
	for i in $(eval echo {1..$num_c});do
	 sox $path/audio/${lines}/${lines}.CH${i}.wav -c 1 -r 16000 single_channel/${lines}.CH${i}.wav
        done
	
done
end=`date +%s`
runtime=$((end-start))
echo "TCS-IITB>> Runtime for downsampling : $runtime sec"
fi

# If the enhancement is already done then start with stage=2
if [ $stage -le 1 ]; then
echo '
#######################################################################
TCS-IITB>> Performing Enhancement
#######################################################################
'
	## Data Preparation for enhancement
	rm -f out_beamform/*
	start=`date +%s`
	mask=$(echo $beamform | cut -d '_' -f 2)
	reverb=1
	noise=1
	if [ -z "$dereverb" ] || [ -z "$denoise" ]; then

		if [ -z "$denoise" ] && [ ! -z "$dereverb" ] ; then
		#do dereverb only
		reverb=1
		noise=0
		elif [ ! -z "$denoise" ] && [ -z "$dereverb" ]; then
		#echo It will take about $(echo $dur*32/55/60 | bc -l) minutes to complete the enhancement
		reverb=0
		noise=1
		else
		#echo It will take roughly $(echo $dur*22/55/60 | bc -l) minutes to complete the enhancement '(depends on the CPU)'
		reverb=0
		noise=0
		fi
	fi
	if [ ! -z "$mask" ]; then
	   beamforming=$(echo $beamform | cut -d '_' -f 1)
	else
	   beamforming=$beamform
	fi
	if [ -z "$dereverb" ]; then 
	    dereverb=n
	fi
	if [ -z "$denoise" ]; then
	    denoise=n
	fi 
	for lines in `ls $path/audio`; do
	num_c=$(ls $path/audio/$lines/${lines}.CH* | wc -l)
	octave -q codes/enhancement.m $lines $localize $beamforming $noise $reverb $denoise $dereverb ${num_c} $mask $seq
	sox out_beamform/${lines}_${beamform}.wav -c 1 -r 8000 out_beamform/${lines}_${beamform}_8k.wav #Downsampling for Aspire Decoding
	#rm out_beamform/${lines}_${beamform}.wav  # Removing 16KHZ audio
	done 

	end=`date +%s`
	runtime=$((end-start))
	echo "TCS-IITB>> Runtime for enhancement : $runtime sec"
fi

echo '
#######################################################################
TCS-IITB>> Preparing LM
#######################################################################
'

if [[ ($stage -le 2) && ("${build_graph}" == true) ]]; then

	echo "TCS-IITB>> Preparing LM"
	rm -rf corpus.txt
	for lines in `ls $path/audio`; do
	cat ${path}/audio/${lines}/script.txt | grep -v 'Number of Speakers' | sed 's/Speaker [0-9]: //g' | sed 's/\. /\n/g' | sed 's/\.//g' >> corpus.txt
	done

	echo "TCS-IITB>> Lexicon Preparation  [Using Aspire lexicon]"
	dict_dir=data/local/dict
	mkdir -p $dict_dir

	cp $aspire_dict_directory/extra_questions.txt $dict_dir
	cp $aspire_dict_directory/silence_phones.txt $dict_dir
	cp $aspire_dict_directory/optional_silence.txt $dict_dir
	cp $aspire_dict_directory/nonsilence_phones.txt $dict_dir
	cp $aspire_dict_directory/lexicon_new $dict_dir/lexicon.txt

	sed -i '1s/^/!SIL sil\n/' $dict_dir/lexicon.txt # Add !SIL to lexicon

	echo "Using Aspire lexicon"

	echo 'TCS-IITB>> Language Model Preparation'

	mkdir -p data/local/lm
	mkdir -p data/local/tmp

	# Clear previous runs if they exist
	rm -rf local/lm/lm_phone_bg.arpa.gz data/lm/lm_phone_bg.arpa.gz
	rm -rf data/lang/*
	rm -rf data/lm/*
	rm -rf data/local/tmp/*
	rm -rf data/local/dict/lexiconp.txt
	rm -rf data/local/lang/lexiconp*
	rm -rf data/local/lang/align_lexicon.txt
	rm -rf data/local/lang/lex_ndisambig
	rm -rf data/local/lang/phone_map.txt


	utils/prepare_lang.sh --num-sil-states 3 ./data/local/dict " " data/local/lang  data/lang

	ngram-count -wbdiscount -order 4 -interpolate -text corpus.txt -lm data/local/tmp/lm_phone_bg.arpa	# comptes n-gram probabilities

	compile-lm --text=yes data/local/tmp/lm_phone_bg.arpa /dev/stdout | grep -v "<unk>" | gzip -c > data/local/lm/lm_phone_bg.arpa.gz 

	gunzip -c data/local/lm/lm_phone_bg.arpa.gz | utils/find_arpa_oovs.pl data/lang/words.txt  > data/local/tmp/oov.txt # find OOV

	gunzip -c data/local/lm/lm_phone_bg.arpa.gz | grep -v '<s> </s>' | grep -v '</s> <s>'  | grep -v '</s> </s>' | arpa2fst - | fstprint | utils/remove_oovs.pl data/local/tmp/oov.txt | utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang/words.txt --osymbols=data/lang/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon |fstarcsort > data/lang/G.fst 

	fstisstochastic data/lang/G.fst 

	echo "TCS-IITB>> Created Language model FST"

	utils/prepare_lang.sh --num-sil-states 3 data/local/dict/ "!SIL" data/local/lang data/lang

	echo "TCS-IITB>> Dictionary & language model preparation succeeded"

	echo "TCS-IITB>> Preparing graph"      

	utils/mkgraph.sh data/lang $model_dir $graph_dir || exit 1;

	echo "TCS-IITB>> === Preparing graph done; Graph stored at "${graph_dir}

fi

if [[ ($stage -le 3) && ("$do_diarization" == true) ]]; then
echo '
#######################################################################
TCS-IITB>> Perform feature extraction for SAD
#######################################################################
'
mkdir -p ${data_set}
start=`date +%s`
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.

for lines in `ls $path/audio`; do
echo ${lines}_${beamform} ${PWD}/out_beamform/${lines}_${beamform}.wav >> $data_set/wav.scp
done
cat $data_set/wav.scp | awk -F ' ' '{print $1" "$1}' > $data_set/utt2spk
#utils/utt2spk_to_spk2utt.pl $data_set/utt2spk > $data_set/spk2utt
utils/fix_data_dir.sh $data_set

mfccdir=mfcc
for x in ${test_dir}; do
steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
--mfcc-config conf/mfcc_hires.conf \
data/$x exp/make_mfcc/$x $mfccdir
done
end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Runtime for SAD feature extraction : $runtime sec"
echo

start=`date +%s`
dir=exp/segmentation${affix}
sad_work_dir=exp/sad${affix}_${nnet_type}/
sad_nnet_dir=$dir/tdnn_${nnet_type}_sad_1a

for datadir in ${test_dir}; do
test_set=data/${datadir}
## Perform segmentation
local/segmentation/detect_speech_activity.sh --nj $nj --stage $sad_stage \
$test_set $sad_nnet_dir mfcc $sad_work_dir \
data/${datadir} || exit 1

test_dir=data/${datadir}_${nnet_type}_seg
mkdir -p  $test_dir
mv data/${datadir}_seg/* ${test_dir}/.
steps/segmentation/convert_utt2spk_and_segments_to_rttm.py \
${test_dir}/utt2spk ${test_dir}/segments ${test_dir}/rttm

done


end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Runtime for segmentation: $runtime sec"
echo

for input_file in `ls $path/audio`; do 
num_spk=$(cat $path/audio/${input_file}/script.txt | head -1 | sed 's/Number of Speakers: //g') 
echo ${input_file}_beamform $num_spk >> ${data_set}/reco2num_spk
done

start=`date +%s`
echo 'Removing all earlier stored label and transcript files before starting diarization'
if [ "$diarize" == "xvector" ]; then
extract_xvectors_only=false
echo '------Running x-vector feature diarization-------------'
  for datadir in ${test_dir}; do
    ref_rttm=data/${datadir}_${nnet_type}_seg/ref_rttm
    local/diarize.sh --nj $nj --cmd "$train_cmd" --stage $diarizer_stage \
      --ref-rttm $ref_rttm \
      exp/xvector_nnet_1a \
      data/${datadir}_${nnet_type}_seg \
      exp/${datadir}_${nnet_type}_seg_diarization $num_spk $extract_xvectors_only
      
  done
fi

if [[ ("$diarize" == "tdoa") || ("$diarize" == "xtdoa") ]] ; then
	echo '------Running beamformit TDOA feature diarization-------------'
        for input_file in `ls $path/audio`;do 
	num_spk=$(cat $path/audio/${input_file}/script.txt | head -1 | sed 's/Number of Speakers: //g') 
	temp_file=$(echo $input_file | awk -F "_${beamform}" '{print $1}')
	if [ "$beamform" != "beamformit" ];then
		./run_beamformit.sh beamform $temp_file
	fi
	[ "$diarize" == "tdoa" ] && python return_vec.py $temp_file ${test_sets}_${nnet_type}_seg $num_spk $output_dir/${temp_file}_${beamform} tdoa 
	if [ "$diarize" == "xtdoa" ];then 
	        extract_xvectors_only=true
		    local/diarize.sh --nj $nj --cmd "$train_cmd" --stage $diarizer_stage \
		      exp/xvector_nnet_1a \
		      data/${test_sets}_${nnet_type}_seg \
		      exp/${test_sets}_${nnet_type}_seg_diarization $num_spk $extract_xvectors_only
	   
           python return_vec.py $temp_file ${test_sets}_${nnet_type}_seg $num_spk $output_dir/${temp_file}_${beamform} xtdoa
	fi
        done
	
  
fi
echo "TCS-IITB>> Using the speaker labels written to utt2spk to do diarization"
end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Runtime for feature extraction and clustering: $runtime sec"
echo 

fi


echo '
#######################################################################
TCS-IITB>> Running Decoding 
#######################################################################
'
if [ $stage -le 4 ]; then
## Data Preparation for decoding
mkdir -p ${data_set}_asr


for lines in `ls $path/audio`; do
echo ${lines}_${beamform} ${PWD}/out_beamform/${lines}_${beamform}_8k.wav >> ${data_set}_asr/wav.scp
done 
cat ${data_set}_asr/wav.scp | awk -F ' ' '{print $1" "$1}' > ${data_set}_asr/utt2spk
#utils/utt2spk_to_spk2utt.pl $data_set/utt2spk > $data_set/spk2utt
utils/fix_data_dir.sh ${data_set}_asr


for lines in `ls $path/audio`; do
text=$(cat ${path}/audio/${lines}/script.txt | grep 'Speaker [0-9]' | sed 's/Speaker [0-9]: //g' | sed 's/\.\n /.\ /g' | sed 's/\.//g')
echo ${lines}_${beamform} $text >> ${data_set}_asr/text
done
fi 
test_dir=dev_eval_asr
if [ $stage -le 5 ]; then
	echo "TCS-IITB>> Computing MFCCs for decoding"
	start=`date +%s`
	for datadir in ${test_dir}; do
	    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires_asr.conf \
	      --cmd "$train_cmd" data/${datadir}
	    steps/compute_cmvn_stats.sh data/${datadir}
	    utils/fix_data_dir.sh data/${datadir}
	done

	end=`date +%s`
	runtime=$((end-start))
	echo
	echo "TCS-IITB>> Runtime for extracting MFCC for decoding: $runtime sec"  
	echo 

fi


if [ $stage -le 6 ]; then
	echo "TCS-IITB>> Extracting i-vectors"
	echo  
	start=`date +%s`
	data=$test_dir
	nspk=1
	steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nj}" \
	      data/${data} exp/nnet3_cleaned_aspire/extractor \
	      exp/nnet3_cleaned_aspire/ivectors_${data}
	      
	end=`date +%s`
	runtime=$((end-start))
	echo
	echo "TCS-IITB>> Runtime for extracting i-vectors :$runtime sec"   
	echo 
fi


if [ $stage -le 7 ]; then
	start=`date +%s` 
	echo "TCS-IITB>> Decoding"
	decode_set=$test_dir
	steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
	    --nj ${nj} --cmd "$decode_cmd" \
	    --online-ivector-dir exp/nnet3_cleaned_aspire/ivectors_${decode_set} \
	    $graph_dir data/${decode_set} ${model_dir}/decode_${decode_set}
	end=`date +%s`
	runtime=$((end-start))
	echo 
	echo "TCS-IITB>> Runtime for decoding and scoring : $runtime sec"   
	echo
fi

runtime=$((end-start1))

echo "------------WER on TCS-dataset enhanced using ${bemform} is------------"
cat ${model_dir}/decode_${test_dir}/scoring_kaldi/best_wer 
echo "WER stored at ${model_dir}/decode_${test_dir}/scoring_kaldi/best_wer"

echo "TCS-IITB>> Total Runtime : $runtime seconds"  

