## Multi-channel audio transription tool
This tool is used to generate speaker labelled transcripts using a input multi-channel audio. The script ./multictext.sh is to be called from terminal terminal. This tool is as per the system blocks shown in the Figure below

![System Piupeline](https://github.com/iitbdaplab/toolasr/blob/master/back-end_framework.png)

### Instructions for running
First move to the kaldi path
```
cd <your path where kaldi is installed>/kaldi/egs
```
then, download the repository, 
```
$: git clone https://github.com/iitbdaplab/toolasr
and
$: cd toolasr/dia 
```

Then initialize python virtual environment for python dependencies
```
source setup.sh
```
The script can be run using the command below :
```
./multictext.sh $PWD/<input-filename> <num_spk> <output-dir>
```
For eg.
```
./multictext.sh /home/user/multi_audio/s01_audio <num_spk> output/ 
```
where the multi-channel audio is stored as s01_audio.{CH1,CH2,CH3,CH4}.wav, <num_spk> are total number of speakers 
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
./multictext.sh /home/user/multi_audio/s01_audio 3  --beamform mvdr output/ 
```
## Other Instructions
The script used by the tool ```multictext.sh``` has a config file ```config``` which allows to choose the set of parameters 
like the type of enhancements, diarization method and so on. You can chnage the options here or give the options as in-line arguments using the names in the above table.
The details of intermediate stages of output is listed below
⋅⋅* The output audio of single-channel enhancement method is stored at ```single_<denoise/derevereb>``` folder as a 4 channels.
⋅⋅* The output audio of beamforming is stored at ```out_beamform``` as ```<input-file>_<beamform>.wav```.
..* The output of diarization and ASR is stored at the ```<output>``` folder specified when the script is run.
