addpath('codes/denoising');
addpath('codes/dereverb');
x=[argv(){1} '.wav'];
if(strcmp(argv(){2},"Spec-Sub"))
   disp('Starting Spectral Subtraction single-channel enhancement')
   for i =1:str2num(argv(){3})
     [y,fs] = audioread(['single_channel/' argv(){1} '.CH' num2str(i) '.wav']);
     
     output=spec_sub1(y,fs,1);
     audiowrite(['single_denoising/spec_sub/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
   end
end

if(strcmp(argv(){2},"Wiener"))
  disp('Starting Wiener single-channel enhancement')
   for i =1:str2num(argv(){3})
        
        [y,fs] = audioread(['single_channel/' argv(){1} '.CH' num2str(i) '.wav']);
        esHRNR = wiener(y,fs,2);
        audiowrite(['single_denoising/wiener/' argv(){1} '.CH' num2str(i) '.wav'],esHRNR,fs)
   end
end

if(strcmp(argv(){2},"NMF"))
%% STFT and reverb parameters
parm.analysis = 1024; %window length (1024 corresonds to 64ms when fs = 16000 samples/s)
parm.hop = parm.analysis/4; %hop size
parm.win = sqrt(hamming(parm.analysis)); % window type
parm.Nframe = 20; % number of frames allocated for RIR

% edit it


%CNMF
disp('Starting NMF single-channel enhancement')
sparsity = 1;
     for i =1:str2num(argv(){3})
        
        [y,fs] = audioread(['single_channel/' argv(){1} '.CH' num2str(i) '.wav']);
        [CNMF, ~] = dereverb_kl_divergence_new(y,sparsity,parm);
        audiowrite(['single_dereverb/nmf/' argv(){1} '.CH' num2str(i) '.wav'],CNMF,fs)
     end
end
