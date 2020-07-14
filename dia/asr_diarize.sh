#!/bin/bash
# This script is used to go diarization and then ASR for the input single channel audio
#author: Sachin Nayak
#From IIT Bombay, Mumbai

. ./config
diarize=$1
audio_path=$2
input_file=$3
output_dir=$4
enhancement_only=$5
num_spk=$6
beamform=$7


. ./conf/sad.conf
. ./path.sh
. ./cmd.sh
nj=1
test_sets=dev_test
stage=0
sad_stage=0
use_new_rttm_reference=false
score=false
diarizer_stage=0


echo '
#######################################################################
TCS-IITB>> Starting Diarization
#######################################################################
'
if [ $stage -le 1 ];then
mkdir -p data.bak
cp -r data/* data.bak/
rm -rf data

data_set=data/dev_test
mkdir -p $data_set
[ "$single_channel_decode" == "true" ] && input_file=$(echo $audio_path | rev | cut -d '/' -f 1 | rev | awk -F '.wav' '{print $1}')
echo $audio_path | rev | cut -d '/' -f 1 | rev | awk -F '.wav' '{print $1}' > $data_set/wav.scp
cat $data_set/wav.scp | while read lines
do
echo $lines $audio_path >> wav2.scp
done
mv wav2.scp $data_set/wav.scp


cat $data_set/wav.scp | awk -F ' ' '{print $1" "$1}' > $data_set/utt2spk
#utils/utt2spk_to_spk2utt.pl $data_set/utt2spk > $data_set/spk2utt
utils/fix_data_dir.sh $data_set

fi

echo '
#######################################################################
TCS-IITB>> Perform feature extraction for SAD
#######################################################################
'
start=`date +%s`
if [ $stage -le 2 ]; then
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.
  mfccdir=mfcc
  for x in ${test_sets}; do
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
      --mfcc-config conf/mfcc_hires.conf \
      data/$x exp/make_mfcc/$x $mfccdir
  done
fi
end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Elapsed time is ${runtime} seconds for SAD feature extraction"
echo 
echo '
#######################################################################
TCS-IITB>> Perform SAD on the recording for obtaining segments
#######################################################################
'
start=`date +%s`
dir=exp/segmentation${affix}
sad_work_dir=exp/sad${affix}_${nnet_type}/
sad_nnet_dir=$dir/tdnn_${nnet_type}_sad_1a
if [ $stage -le 3 ]; then
  for datadir in ${test_sets}; do
    test_set=data/${datadir}
    if [ ! -f ${test_set}/wav.scp ]; then
      echo "$0: Not performing SAD on ${test_set}"
      exit 0
    fi
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
fi

end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Elapsed time is ${runtime} seconds for segmentation"
echo 
echo '
#######################################################################
TCS-IITB>> Perform diarization on the dev/eval data
#######################################################################
'
start=`date +%s`
mkdir -p $output_dir
if [ $stage -le 4 ]; then
echo 'Removing all earlier stored label and transcript files before starting diarization'
rm -f $output_dir/${input_file}_*rttm* $output_dir/${input_file}_*txt_temp* $output_dir/${input_file}_*labels*
if [ "$diarize" == "xvector" ]; then
extract_xvectors_only=false
echo '------Running x-vector feature diarization-------------'
  for datadir in ${test_sets}; do
    if $use_new_rttm_reference == "true"; then
      mode="$(cut -d'_' -f1 <<<"$datadir")"
      ref_rttm=./chime6_rttm/${mode}_rttm
    else
      ref_rttm=data/${datadir}_${nnet_type}_seg/ref_rttm
    fi
    local/diarize.sh --nj $nj --cmd "$train_cmd" --stage $diarizer_stage \
      --ref-rttm $ref_rttm \
      exp/xvector_nnet_1a \
      data/${datadir}_${nnet_type}_seg \
      exp/${datadir}_${nnet_type}_seg_diarization $num_spk $extract_xvectors_only
      
  done
fi

if [[ ("$diarize" == "tdoa") || ("$diarize" == "xtdoa") ]] && [ "$single_channel_decode" == "false" ]; then
	echo '------Running beamformit TDOA feature diarization-------------'
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
	
fi

end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Elapsed time is ${runtime} seconds for diarization feature extraction and clustering"
echo 
fi

echo '
#######################################################################
TCS-IITB>> Perform ASR using diarization time stamps
#######################################################################
'
test_dir=${test_sets}_${nnet_type}_seg_asr
mkdir -p data/$test_dir
cp data/${test_sets}_${nnet_type}_seg/{segments,wav.scp,spk2utt,utt2spk} data/$test_dir/

#If the ASR decoder graph already exists then specify the paths below by uncommenting, 
#else the paths from config file will be taken
#model_dir=exp/chain_cleaned/tdnn_1d_sp
#graph_dir=$dir/graph_tgsmall
if [ $stage -le 5 ]; then
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
echo "TCS-IITB>> Elapsed time is ${runtime} seconds for extracting MFCC for decoding"  
echo 
fi

if [ $stage -le 6 ]; then
start=`date +%s`
data=$test_dir
nspk=1
steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
      data/${data} exp/nnet3_cleaned/extractor \
      exp/nnet3_cleaned/ivectors_${data}
      
end=`date +%s`
runtime=$((end-start))
echo
echo "TCS-IITB>> Elapsed time is ${runtime} seconds for extracting ivectors"   
echo 
fi



if [ $stage -le 8 ]; then
start=`date +%s`
[ ! -f "${graph_dir}/HCLG.fst" ] && utils/mkgraph.sh --self-loop-scale 1.0 --remove-oov \
  data/lang ${model_dir} $graph_dir && end=`date +%s` && runtime=$((end-start)) && echo "TCS-IITB>> It took ${runtime} seconds to build the graph"
  
start=`date +%s`  
decode_set=$test_dir
steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj ${nj} --cmd "$decode_cmd" \
    --online-ivector-dir exp/nnet3_cleaned/ivectors_${decode_set} \
    $graph_dir data/${decode_set} ${model_dir}/decode_${decode_set}_tgsmall
    
end=`date +%s`
runtime=$((end-start))
echo 
echo "TCS-IITB>> Elapsed time is ${runtime} seconds for decoding"   
echo 
fi

echo '
#######################################################################
TCS-IITB>> Writing Conversation text
#######################################################################
'

cat ${model_dir}/decode_${test_dir}_tgsmall/log/decode* | grep -v "LOG" | grep $input_file > $output_dir/${input_file}_segment
if [ "$diarize" == "xvector" ]; then
	cp exp/${test_sets}_${nnet_type}_seg_diarization/rttm $output_dir/${input_file}_rttm
	sed -i 's/    / /g' $output_dir/${input_file}_rttm
	sed -i 's/   / /g' $output_dir/${input_file}_rttm
	sed -i 's/  / /g' $output_dir/${input_file}_rttm
	cat data/${test_sets}_${nnet_type}_seg/segments | while read lines
	do
	start=$(echo $lines | cut -d ' ' -f 3)
	spk=$(cat $output_dir/${input_file}_rttm | cut -d ' ' -f 4,8 | grep $start | cut -d ' ' -f 2)
	[ ! -z "$spk" ] && echo ${spk} >> $output_dir/${input_file}_unsorted_rttm
	seg=$(echo $lines | cut -d ' ' -f 1)
	cat $output_dir/${input_file}_segment | grep $seg | cut -d ' ' -f 2- >> $output_dir/${input_file}_txt_temp
	done
	python sort_spk.py $output_dir/${input_file}_unsorted_rttm $output_dir/${input_file}_labels
	paste -d ' ' $output_dir/${input_file}_labels $output_dir/${input_file}_txt_temp > ${output_dir}/${input_file}_txt
	#echo "Speaker "$spk": "$text >> ${output_dir}/${input_file}_txt
fi

if [[ ("$diarize" == "tdoa")  || ("$diarize" == "xtdoa") ]]; then
	cat data/${test_sets}_${nnet_type}_seg/segments | while read lines
	do
		seg=$(echo $lines | cut -d ' ' -f 1)
		cat $output_dir/${input_file}_segment | grep $seg | cut -d ' ' -f 2- >> $output_dir/${input_file}_txt_temp

	done
	python sort_spk.py $output_dir/${input_file}_unsorted_rttm $output_dir/${input_file}_labels
	paste -d ' ' $output_dir/${input_file}_labels $output_dir/${input_file}_txt_temp > ${output_dir}/${input_file}_txt
fi
echo "******************************************************************"
echo
cat  ${output_dir}/${input_file}_txt
echo
echo "******************************************************************"
echo
echo "Succesfully decoded ${audiopath}"
