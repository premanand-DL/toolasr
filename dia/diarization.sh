#!/bin/bash

#DATA Prepration
data_set=data/dev_lib
mkdir -p $data_set
find $PWD/data/beamformit/ -name "*.wav" | > wav1.scp
paste -d <(cat wav1.scp | rev | cut -d '/' -f 1 | rev | cut -d '.' -f 1) wav1.scp > data/$data_set/wav.scp
rm wav1.scp


# Doing Enhancement
input_dir=/home/samit/MTP2/multi_audio1
output_dir=$PWD/data/beamformit_output
cd beamformit
echo $PWD
./do_beamforming.sh $input_dir $output_dir
cd -


# Data Preparation

