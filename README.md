# This tool is used to generate speaker labelled transcripts using a input multi-channel audio. The script ./multictext.sh 
is to be called from terminal terminal. This tool is as per the system blocks shown in the Figure below

![System Piupeline](https://github.com/iitbdaplab/toolasr/blob/master/back-end_framework.png)

First, download the repository,
```
$: git clone https://github.com/iitbdaplab/toolasr
and
$: cd dia 
```
The script can be run using the command below :
```
./multictext.sh /home/user/multi_audio/s01_audio <num_spk> output/ 
```
where the multi-channel audio is stored as s01_audio.{CH1,CH2,CH3,CH4}.wav, <num_spk> are total num ber of speskers 
in the session and output is where the transcripts generated will be stored. You can use the sample audios from multi_audio 
folder in the directory cloned. 

The options to be used along with this file is given in the table below:
|   Option  |                                                              Description                                                              |                 Values                |
|:---------:|:-------------------------------------------------------------------------------------------------------------------------------------:|:-------------------------------------:|
| -denoise  | Does signal-channel denoising on the multi-channel audio                                                                              |            wiener, spec-sub           |
| -dereverb | Does single-channel dereverberation of the multi-audio or  the denoised audio if denoising is sepcified                               |                wpe, nmf               |
| -localize | GCC based localization to compute the time difference of  arrival (TDOA) used as steering vector for beamforming                      |           gcc_phat, gcc_scot          |
| -beamform | Does multi-channel enhancement. Does it on the enhanc- ed audio using  single-channel denoising and/or dreverb- eration, if specified | dsb, mvdr_ta, mvdr_nn, gev_ta, gev_nn |
| -diarize  | The type of diarization system used                                                                                                   |          xvector, tdoa, xtdoa         |

The options can also be passed as arguments to the file as an example below :
```
```
./multictext.sh /home/user/multi_audio/s01_audio 3  --beamform mvdr output/ 
```
