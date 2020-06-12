#!/bin/bash

input_file=$1
output_dir=$2


if [ $# -ne 2 ]; then
  echo "Usage: $0 [options] <input-filename> <out-dir>"
  echo "If the file has path /home/user/audio/S01audio.CH1.wav, then just give If the file has path /home/user/audio/S01audio as <input-filename> "
  echo "e.g.:   multictext \\"
  echo "    S10audio decoded_output/"
  echo "main options (for others, see top of script file)"
  echo "  --dereverb <string>                   # Run Single-channel deverberation on multi-channel audio {wpe, nmf }"
  echo "  --denoise <string>                    # Run Single-channel denoising on multi-channel audio {wiener, spec-sub}"
  echo "  --localize <string>                   # Type of TDOA estimation for beamforming. {gcc_phat, gcc_scot}"
  echo "  --beamform <string>                   # Beaforming method {beamformit, dsb, mvdr_ta, mvdr_nn, gev_ta, gev_nn"
  echo "  --diarize <string>                    # Type of diarization method {tdoa, xvector,xtdoa}"
  echo " You can also specify the arguments in config file"
  exit 1;
fi


denoise=
dereverb=
while getopts dereverb:denoise:localize:beamform:diarize option
do
case "${option}"
in
dereverb) dereverb=${OPTARG};;
denoise) denoise=${OPTARG};;
localize) localize=${OPTARG};;
beamform) beamform=${OPTARG};;
diarize) diarize=${OPTARG};;
esac
done

. ./config

num_c=$(ls ${input_file}* | wc -l)
cp ${input_file}* single_channel/
input_file=$(echo $input_file | rev | cut -d '/' -f 1 | rev | awk -F '.CH' '{print $1}')

if [ -z "$localize" ]; then
localize=gcc_phat
fi

if [ -z "$beamform" ]; then
beamform=beamformit
fi

if [ -z "$diarize" ]; then
diarize=xvector
fi


reverb=1
noise=1

if [ -z "$dereverb" ] || [ -z "$denoise" ]; then

if [ -z "$denoise" ] && [ ! -z "$dereverb" ] ; then
#do dereverb only
reverb=1
noise=0
#do wpe
if [ "$denoise" == "wpe" ]; then
./codes/dereverb/wpe.py $input_file $num_c
fi
#do nmf
if [ "$denoise" == "nmf" ]; then
octave -q codes/denoising/enhance.m $input_file NMF $num_c
fi

elif [ ! -z "$denoise" ] && [ -z "$dereverb" ]; then
reverb=0
noise=1
if [ "$denoise" == "wiener" ]; then
octave -q codes/denoising/enhance.m $input_file Wiener $num_c
fi    
#do denoise only
if [ "$denoise" == "spec-sub" ]; then
octave -q codes/denoising/enhance.m $input_file Spec-Sub $num_c
fi

else
reverb=0
noise=0
fi

fi


#Beamforming

mask=$(echo $beamform | cut -d '_' -f 2)
if [ ! -z "$mask" ]; then
beamform=$(echo $beamform | cut -d '_' -f 1)
fi
if [ -z "$dereverb" ]; then 
dereverb=n
fi
if [ -z "$denoise" ]; then
denoise=n
fi 

if [ ! -f "${PWD}/out_beamform/${input_file}_${beamform}.wav" ]; then

octave -q codes/enhancement.m $input_file $localize $beamform $noise $reverb $denoise $dereverb ${num_c} $mask

#diarization and ASR
fi

[ "$enhancement_only" == true ] && echo Enhanced audio is stored at $PWD/out_beamform/${input_file}_${beamform}.wav && exit 1

path=$PWD/out_beamform/${input_file}_${beamform}.wav
./asr_diarize.sh $diarize $path ${input_file}_${beamform} $output_dir $enhancement_only




