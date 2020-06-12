#!/bin/bash
. ./conf/sad.conf
. ./path.sh
. ./cmd.sh
nj=2
input_dir=/home/samit/MTP2/multi_audio1
output_dir=$PWD/data/beamformit_output
test_sets=dev_lib
stage=4
sad_stage=0
use_new_rttm_reference=false
score=true
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



 > $data_set/segments
cat $data_set/wav.scp | while read lines1
do
nums=$(echo $lines1 | cut -d '_' -f 1)
rec=$(echo $lines1 | cut -d ' ' -f 1)
i=1
cat $meta/${nums}_dur | while read lines2
do
if [ $i -eq 1 ];then
start=0
fi
tmp=$(echo $lines2 | cut -d ' ' -f 1) 
end=$(echo $tmp + $start | bc)
sil=$(echo $lines2 | cut -d ' ' -f 2)
num_s=$(echo $lines1 | cut -d '_' -f 1 | cut -d 'S' -f 2)
utt_id=$(sed -n "${i}p" $meta/order_spk_${num_s}) 
i=$(($i+1))
echo ${utt_id}-${rec}_${start}_${end} ${rec} $start $end >> $data_set/segments
start=$(echo $end + $sil | bc)
done
done

> $data_set/utt2spk
i=1
for lines1 in $(cat $data_set/wav.scp | cut -d ' ' -f 1);do
nums=$(echo $lines1 | cut -d '_' -f 1 | cut -d 'S' -f 2)
echo $nums
for lines2 in $(cat ${meta}/order_spk_${nums});do
utt=$(sed -n "${i}p" $data_set/segments | cut -d ' ' -f 1)
echo $utt $lines2 >> $data_set/utt2spk
i=$(($i+1))
done
done

exit 1

> $data_set/spk2utt
utils/utt2spk_to_spk2utt.pl $data_set/utt2spk > $data_set/spk2utt
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
    cp data/${datadir}/{segments.bak,utt2spk.bak} ${test_dir}/
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
