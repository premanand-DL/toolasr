#!/bin/bash

input_file=$1
num_spk=$2
output_dir=$3


if [ $# -le 2 ]; then
  echo "Usage: $0 [options] <input-filename> <num-of-speakers> <out-dir>"
  echo "If the file has path /home/user/audio/S01audio.CH1.wav, then just give /home/user/audio/S01audio as <input-filename> "
  echo "<num-of-speakers> should be in range from 2 to 7"
  echo "e.g.:   ./multictext.sh /home/sachin/multi_audio/S10audio 3 decoded_output/"
  echo "<out-dir> should be where the transcripts are stored"
  echo "Have the audio files in the form named as S10_audio.CH1.wav, S10_audio.CH2.wav, S10_audio.CH3.wav and so on"
  echo "main options (for others, see top of script file)"
  echo "  --dereverb <string>                   # Run Single-channel deverberation on multi-channel audio {wpe, nmf }"
  echo "  --denoise <string>                    # Run Single-channel denoising on multi-channel audio {wiener, spec-sub}"
  echo "  --localize <string>                   # Type of TDOA estimation for beamforming. {gcc_phat, gcc_scot}"
  echo "  --beamform <string>                   # Beaforming method {beamformit, dsb, mvdr_ta, mvdr_nn, gev_ta, gev_nn"
  echo "  --diarize <string>                    # Type of diarization method {tdoa, xvector,xtdoa}"
  echo " You can also specify the arguments in config file"
  exit 1;
fi

echo "-----------------------------------------------------------------"
echo "-----------------------------------------------------------------"
echo "                         Initialiazing                     "

echo "-----------------------------------------------------------------"
echo "-----------------------------------------------------------------"

[[ $num_spk != ?(-)+([2-7]) ]] && echo "Either $num_spk is not integer or out of limits for number of speakers" && exit 1
denoise=
dereverb=

. ./config

#ln -s ../../wsj/s5/steps .
#ln -s ../../wsj/s5/utils .
# Read command line options
ARGUMENT_LIST=(
    "dereverb"
    "denoise"
    "localize"
    "beamform"
    "diarize"
    "enhancement_only"
)



# read arguments
opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "" \
    -- "$@"
)


eval set --$opts

while true; do
    case "$1" in
    --dereverb)  
        shift
        dereverb=$1
        ;;
    --denoise)  
        shift
        denoise=$1
        ;;
    --localize)  
        shift
        localize=$1
        ;;
    --beamform)  
        shift
        beamform=$1
        ;;
    --diarize)  
        shift
        diarize=$1
        ;;
    --enhancement_only)  
        shift
        enhancement_only=$1
        ;;
      --)
        shift
        break
        ;;
    esac
    shift
done


if [ "$single_channel_decode" == true ];then
[[ ("$single_channel_decode" == "true" ) && ("$diarize" == "tdoa") || ("$diarize" == "xtdoa") ]] && echo 'Need Multi-audio data for '${diarize}' diarizatiion method, hence using the x-vector diarization method '
path=$input_file
diarize=xvector
./asr_diarize.sh $diarize $path ${input_file}_${beamform} $output_dir $enhancement_only $num_spk $beamform
exit 1
fi

num_c=$(ls ${input_file}* | wc -l)
cp ${input_file}* single_channel/
input_file=$(echo $input_file | rev | cut -d '/' -f 1 | rev )


#default arguments
if [ -z "$localize" ]; then
localize=gcc_phat
fi

if [ -z "$beamform" ]; then
beamform=beamformit
fi

if [ -z "$diarize" ]; then
diarize=xvector
fi

#Get Sampling rate and downsampke to 16KHz
sam_fre=$(sox --i -r single_channel/${input_file}.CH1.wav)  
if [ "${sam_fre}" != "16000" ]; then
	for i in $(eval echo {1..$num_c});do
	 sox single_channel/${input_file}.CH${i}.wav -c 1 -r 16000 single_channel/${input_file}.CH${i}.wav
	done
fi


#Options to run single-channel enhancement before beamforming

reverb=1
noise=1
if [ -z "$dereverb" ] || [ -z "$denoise" ]; then

	if [ -z "$denoise" ] && [ ! -z "$dereverb" ] ; then
	#do dereverb only

	reverb=1
	noise=0

	elif [ ! -z "$denoise" ] && [ -z "$dereverb" ]; then
	reverb=0
	noise=1
	else
	reverb=0
	noise=0
	fi

fi


#Beamforming
mask=$(echo $beamform | cut -d '_' -f 2)
if [ ! -z "$mask" ]; then
beamforming=$(echo $beamform | cut -d '_' -f 1)
fi
if [ -z "$dereverb" ]; then 
dereverb=n
fi
if [ -z "$denoise" ]; then
denoise=n
fi 

if [ ! -f "${PWD}/out_beamform/${input_file}_${beamform}.wav" ]; then # If the file exists then proceed to diarization and ASR
octave -q codes/enhancement.m $input_file $localize $beamforming $noise $reverb $denoise $dereverb ${num_c} $mask $seq
[ "$enhancement_only" == true ] && echo Enhanced audio is stored at $PWD/out_beamform/${input_file}_${beamform}.wav && exit 1
#diarization and ASR
path=$PWD/out_beamform/${input_file}_${beamform}.wav
./asr_diarize.sh $diarize $path ${input_file}_${beamform} $output_dir $enhancement_only $num_spk $beamform
exit 1
fi

[ "$enhancement_only" == true ] && echo Enhanced audio is stored at $PWD/out_beamform/${input_file}_${beamform}.wav && exit 1

if [ -f "${PWD}/out_beamform/${input_file}_${beamform}.wav" ]; then
echo Using the enhanced output from ${PWD}/out_beamform/${input_file}_${beamform}.wav
#diarization and ASR
path=$PWD/out_beamform/${input_file}_${beamform}.wav
./asr_diarize.sh $diarize $path ${input_file}_${beamform} $output_dir $enhancement_only $num_spk $beamform
fi





