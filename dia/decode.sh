#!/bin/bash
. ./conf/sad.conf
. ./path.sh
. ./cmd.sh
nj=2
input_dir=/home/samit/MTP2/multi_audio1
output_dir=$PWD/data/beamformit_output
test_sets=dev_lib
stage=8
sad_stage=0
use_new_rttm_reference=false
score=false
diarizer_stage=4
#######################################################################
# Perform DATA Prepration
#######################################################################

if [ $stage -eq 0 ];then
meta=$input_dir/meta-data
data_set=data/dev_lib

find $PWD/data/beamformit/ -name "*.wav" > wav1.scp
mkdir -p $data_set
cat wav1.scp | rev | cut -d '/' -f 1 | rev | awk -F '.wav' '{print $1}' | sort -u > $data_set/wav.scp
cat $data_set/wav.scp | while read lines
do
echo $lines $PWD/data/beamformit/$lines.wav >> wav2.scp
done
mv wav2.scp $data_set/wav.scp
rm wav1.scp

cat $data_set/wav.scp | awk -F ' ' '{print $1" "$1}' > $data_set/utt2spk
#utils/utt2spk_to_spk2utt.pl $data_set/utt2spk > $data_set/spk2utt
utils/fix_data_dir.sh $data_set

fi


#######################################################################
# Perform  Enhancement
#######################################################################

if [ $stage -eq 1 ];then
> beamformit/cfg-files/channels
ls /home/samit/MTP2/multi_audio1/ | grep .wav | cut -d '.' -f 1-3 | sort -u > list_files
cat list_files | while read lines
do
echo $lines $lines.CH1.wav $lines.CH2.wav $lines.CH3.wav $lines.CH4.wav $lines.CH5.wav >>	 beamformit/cfg-files/channels
done

cd beamformit
./do_beamforming.sh $input_dir output
cd -
fi


#######################################################################
# Perform feature extraction
#######################################################################
if [ $stage -eq 2 ]; then
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.
  mfccdir=mfcc
  for x in ${test_sets}; do
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
      --mfcc-config conf/mfcc_hires.conf \
      data/$x exp/make_mfcc/$x $mfccdir
  done
fi

#######################################################################
# Perform SAD on the dev/eval data
#######################################################################

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
    mv data/${datadir}_seg ${test_dir}/
   # cp data/${datadir}/{segments,utt2spk} ${test_dir}/              # cp data/${datadir}/{segments.bak,utt2spk.bak} ${test_dir}/
    # Generate RTTM file from segmentation performed by SAD. This can
    # be used to evaluate the performance of the SAD as an intermediate
    # step.
    steps/segmentation/convert_utt2spk_and_segments_to_rttm.py \
      ${test_dir}/utt2spk ${test_dir}/segments ${test_dir}/rttm
  if [ $score == "true" ]; then
      echo "Scoring $datadir.."
      # We first generate the reference RTTM from the backed up utt2spk and segments
      # files.
      ref_rttm=${test_dir}/ref_rttm
      steps/segmentation/convert_utt2spk_and_segments_to_rttm.py ${test_dir}/utt2spk.bak \
        ${test_dir}/segments.bak ${test_dir}/ref_rttm

  fi

 done
fi



#######################################################################
# Perform diarization on the dev/eval data
#######################################################################
if [ $stage -eq 4 ]; then
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
      exp/${datadir}_${nnet_type}_seg_diarization
  done
fi


#######################################################################
# Perform ASR using diarization time stamps
#######################################################################
test_dir=${test_sets}_${nnet_type}_seg_asr
mkdir -p data/$test_dir
cp data/${test_sets}_${nnet_type}_seg/{segments,wav.scp,spk2utt,utt2spk} data/$test_dir/
dir=exp/chain_cleaned/tdnn_1d_sp
graph_dir=$dir/graph_tgsmall
if [ $stage -eq 5 ]; then
for datadir in ${test_dir}; do
    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires_asr.conf \
      --cmd "$train_cmd" data/${datadir}
    steps/compute_cmvn_stats.sh data/${datadir}
    utils/fix_data_dir.sh data/${datadir}
done
fi

if [ $stage -eq 6 ]; then
data=$test_dir
nspk=2
steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
      data/${data} exp/nnet3_cleaned/extractor \
      exp/nnet3_cleaned/ivectors_${data}
fi

if [ $stage -eq 7 ]; then
utils/mkgraph.sh --self-loop-scale 1.0 --remove-oov \
  data/lang_test_tgsmall $dir $graph_dir
fi

if [ $stage -eq 8 ]; then
decode_set=$test_dir
steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 2 --cmd "$decode_cmd" \
    --online-ivector-dir exp/nnet3_cleaned/ivectors_${decode_set} \
    $graph_dir data/${decode_set} $dir/decode_${decode_set}_tgsmall
fi


