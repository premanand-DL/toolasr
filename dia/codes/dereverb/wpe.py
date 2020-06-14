#!/usr/bin/python3
import numpy as np 
import soundfile as sf 
from tqdm import tqdm 
from nara_wpe.wpe import wpe 
from nara_wpe.wpe import get_power 
from nara_wpe.utils import stft, istft, get_stft_center_frequencies
import sys

basename=sys.argv[1]
x= int(sys.argv[2])
print("Starting single-channel WPE")
stft_options = dict(size=512, shift=128)
for i in range(x):
	y,fs = sf.read('single_channel/'+basename+'.CH'+str(i+1)+'.wav')
	Y=np.expand_dims(y	,axis=0)
	Y = stft(Y,size=512, shift=128) 
	Y = Y.transpose(2, 0, 1) 
	Z = wpe(Y) 
	z_np = istft(Z.transpose(1, 2, 0), size=stft_options['size'], shift=stft_options['shift'])
	sf.write('single_dereverb/wpe/'+sys.argv[1]+'.CH'+str(i+1)+'.wav',z_np.T,fs)
