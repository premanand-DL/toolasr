echo =============================================================
echo "TCS-IITB>> Running Beamformit"
echo =============================================================
. ./cmd.sh
. ./path.sh
# Reading strings from command line arguments
audio_dir=$1
enhandir_beamform="out_beamform"
recording_name=$2


# Make enhancement directory
mkdir -p  ${enhandir_beamform}
	
# Call beamforming scripts
local/run_beamformit_mod.sh --cmd "$train_cmd"  $audio_dir $enhandir_beamform $recording_name 
