#!/bin/bash


. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.
path=$1
graph_dir=exp/tri4b/graph
model_dir=exp/tri4b
mkdir -p data/test
filename=$(echo $path | rev | cut -d '/' -f 1 | rev | rev | cut -d '.' -f 2- | rev )
echo $filename
<<"COMMENT"
echo $filename' '$path > data/test/wav.scp
echo $filename' '$filename > data/test/utt2spk
./utils/utt2spk_to_spk2utt.pl data/test 
nspk=$(wc -l <data/test/spk2utt)
steps/decode_fmllr.sh --nj ${nspk} --cmd "$decode_cmd" \
     $graph_dir data/test \
       exp/tri4b/decode_test || exit 1;
COMMENT
