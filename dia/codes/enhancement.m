%addpath(genpath('../audio'))
addpath('codes/utils')
addpath('codes/source_localization')
addpath('codes/beamform')
addpath('codes/denoising')
addpath('codes/dereverb')
wlen = 1024;
filename= argv(){1};
loc= argv(){2};
enhan = argv(){3};
denoise = str2num(argv(){4});
reverb = str2num(argv(){5});
t_d = argv(){6};
t_r = argv(){7};
num_chn = str2num(argv(){8});
mask=argv(){9};
seq=argv(){10};

if(denoise==1 && reverb==0)
        disp(['TCS-IITB>> Performing single-channel ' t_d ' denoising'])
	for i=1:num_chn
	  [y,fs]= audioread(['single_channel/' filename '.CH' num2str(i) '.wav']);
	  if(strcmp(t_d,"wiener"))
                 output=wiener(y,fs,2);
                 audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
	  end
	  if(strcmp(t_d,"spec-sub"))
	     output=spec_sub1(y,fs,1);
	     audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
	  end
	end
end

if(denoise==1 && reverb==1 && strcmp(seq,"dr"))
disp(['TCS-IITB>> Performing single-channel ' t_d ' denoising and ' t_r ' dereverberation'])
  for i=1:num_chn
	  [y,fs]= audioread(['single_channel/' filename '.CH' num2str(i) '.wav']);
	  if(strcmp(t_d,"wiener"))
            output=wiener(y,fs,2);
            audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
	  end
	  if(strcmp(t_d,"spec-sub"))
	     output=spec_sub1(y,fs,1);
	    audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
	  end
  end
       	  if(strcmp(t_r,"wpe"))
             str=['./codes/dereverb/wpe2.py ' filename ' ' num2str(num_chn)];
             [~] = system(str);
	  end 
  for i=1:num_chn  
	  if(strcmp(t_r,"nmf"))
	parm.analysis = 1024; %window length (1024 corresonds to 64ms when fs = 16000 samples/s)
	parm.hop = parm.analysis/4; %hop size
	parm.win = sqrt(hamming(parm.analysis)); % window type
	parm.Nframe = 20; % number of frames allocated for RIR
	%CNMF
	sparsity = 1;
	[CNMF, ~] = dereverb_kl_divergence_new(output,sparsity,parm);
	audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],CNMF,fs)
	 end

  end

end

if(denoise==1 && reverb==1 && strcmp(seq,"rd"))
disp(['TCS-IITB>> Performing single-channel ' t_r ' dereverberation and ' t_d ' denoising'])

  if(strcmp(t_r,"wpe"))
             str=['./codes/dereverb/wpe1.py ' filename ' ' num2str(num_chn)];
             [~] = system(str);
  end 
  for i=1:num_chn  
	[y,fs]= audioread(['single_channel/' filename '.CH' num2str(i) '.wav']); 
	  if(strcmp(t_r,"nmf"))
	parm.analysis = 1024; %window length (1024 corresonds to 64ms when fs = 16000 samples/s)
	parm.hop = parm.analysis/4; %hop size
	parm.win = sqrt(hamming(parm.analysis)); % window type
	parm.Nframe = 20; % number of frames allocated for RIR
	%CNMF
	sparsity = 1;
	[CNMF, ~] = dereverb_kl_divergence_new(y,sparsity,parm);
	audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],CNMF,fs)
    end
 end
  for i=1:num_chn
	  [y,fs]= audioread(['beamform/' filename '.CH' num2str(i) '.wav']);
	  if(strcmp(t_d,"wiener"))
            output=wiener(y,fs,2);
            audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
	  end
	  if(strcmp(t_d,"spec-sub"))
	     output=spec_sub1(y,fs,1);
	    audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],output,fs)
          end
  end


end


if(denoise==0 && reverb==1)
       	  if(strcmp(t_r,"wpe"))
             str=['./codes/dereverb/wpe1.py ' filename ' ' num2str(num_chn)];
             [~] = system(str);
	  end  
   for i=1:num_chn
	  [y,fs]= audioread(['single_channel/' filename '.CH' num2str(i) '.wav']); 
	  if(strcmp(t_r,"nmf"))
	parm.analysis = 1024; %window length (1024 corresonds to 64ms when fs = 16000 samples/s)
	parm.hop = parm.analysis/4; %hop size
	parm.win = sqrt(hamming(parm.analysis)); % window type
	parm.Nframe = 20; % number of frames allocated for RIR
	%CNMF
	sparsity = 1;
	[CNMF, ~] = dereverb_kl_divergence_new(y,sparsity,parm);
	audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],CNMF,fs)
	 end

	end
end

if(denoise==0 && reverb==0)
disp('TCS-IITB>>  Processing')
	for i=1:num_chn
          
	  [y,fs]= audioread(['single_channel/' filename '.CH' num2str(i) '.wav']);
          audiowrite(['beamform/' argv(){1} '.CH' num2str(i) '.wav'],y,fs)
        end
end
disp('TCS-IITB>> Starting Beamforming')
%% ----------------------------Array Definition---------------------------
% TCS Array
% xmic=[-.10 .10 -.10 0 .10]; % left to right axis
% ymic=[.095 .095 -.095 -.095 -.095]; % bottom to top axis
input_dir=['beamform/' filename];
out_dir=['out_beamform/' filename];

if(strcmp(enhan,'mvdr') && strcmp(mask,"nn")) % Perform MVDR beamforming 
   % initial few frames assumed to be silence
 y = [];
 for i=1:num_chn
 [temp,fs] = audioread(['beamform/' filename '.CH' num2str(i) '.wav']);
 y = [y;temp'];
 end
audiowrite(['beamform/' filename '_mvdr_nn.wav'],y',fs);
disp('TCS-IITB>> Enhancing audio using MVDR NN mask ')
cmd = ['python codes/beamform/nnmvdr.py  codes/beamform/model_nnmask/mdl_adam/estimator_0.3827.pkl beamform/' filename '_mvdr_nn.wav' ' --gev False' ' --dump out_beamform'];
[~]=system(cmd);
disp('TCS-IITB>> Enhancement Done')
end


if(strcmp(enhan,'gev') && strcmp(mask,"nn")) % Perform MVDR beamforming 
   % initial few frames assumed to be silence
 y = [];
 for i=1:num_chn
 [temp,fs] = audioread(['beamform/' filename '.CH' num2str(i) '.wav']);
 y = [y;temp'];
 end
audiowrite(['beamform/' filename '_gev_nn.wav'],y',fs);
disp('TCS-IITB>> Enhancing audio using GEV NN mask ')
cmd = ['python codes/beamform/nnmvdr.py codes/beamform/model_nnmask/mdl_adam/estimator_0.3827.pkl beamform/' filename '_gev_nn.wav'  ' --dump out_beamform'];
[~]=system(cmd);
disp('TCS-IITB>> Enhancement Done')
end


if(strcmp(enhan,'beamformit'))
cmd = ['./run_beamformit.sh '  'beamform ' filename ];
[~] = system(cmd);
[y,fs]= audioread(['out_beamform/' filename '.wav']);
audiowrite(['out_beamform/' filename '_beamformit.wav'],y,fs)
files=['rm out_beamform/' filename '.wav'];
[~]=system(files);
quit
end

%Read Data
[Data1, Fs] = audioread([input_dir '.CH1.wav']);
[Data2, Fs] = audioread([input_dir '.CH2.wav']);
[Data3, Fs] = audioread([input_dir '.CH3.wav']);
[Data4, Fs] = audioread([input_dir '.CH4.wav']);
Data=[Data1 Data2 Data3 Data4];
nsampl = size(Data1,1);

% Perform STFT
X = stft_multi(Data.',wlen);
[nbin,nfram,nchan] = size(X);


% Localize
Max_Delay = ceil(0.2 * Fs / 340);
if(strcmp(loc,"gcc_phat"))
 [TDOA R]= Compute_GCC(X,Max_Delay);
else
 [TDOA R]= Compute_SCOT_R(X,Max_Delay);
end

Index = -Max_Delay:Max_Delay;
%plot(Index,R);

for t=1:nfram
   TDOA(t,:) = TDOA(t,:) - TDOA(t,1);
end;

%% Perform VAD
% VAD_Size = wlen;
% VAD_Out = VAD(Data(:,5),VAD_Size);

% y = Data(:,2);
% y=y/max(abs(y));
% audiowrite('Degrade_Spk1_MA2_NO.wav',y,Fs);
% 
% y = Data(:,3);
% y=y/max(abs(y));
% audiowrite('Degrade_Spk1_MA3_NO.wav',y,Fs);
% 
% y = Data(:,4);
% y=y/max(abs(y));
% audiowrite('Degrade_Spk1_MA4_NO.wav',y,Fs);
% 
if(strcmp(enhan,'dsb')) % Perform DSB Beanforming
disp('TCS-IITB>> Enhancing audio using DSB')
  [Y1,~] = DSB(X,TDOA);
  y1=istft_multi(Y1(:,:,1),nsampl).';
  y1=y1/max(abs(y1));
  Write_File( y1, Fs, [out_dir '_dsb.wav'] );
disp('TCS-IITB>> Enhancement Done')
  %audiowrite([out_dir 'DSB.wav'],y1,Fs);
end% DSB

% Y2 = MCA(X,TDOA);
% y2=istft_multi(Y2(:,:,1),nsampl).';
% y2=y2/max(abs(y2));
% audiowrite('MCA_Gain_Spk3.wav',y2,Fs);
%

if(strcmp(enhan,'mvdr') && strcmp(mask,"ta")) % Perform MVDR beamforming 
   % initial few frames assumed to be silence	
   disp('TCS-IITB>> Enhancing audio using MVDR Time averaged mask')
   Y3 = MVDR(X,TDOA.',10);
   y3=istft_multi(Y3(:,:,1),nsampl).';
   y3=y3/max(abs(y3));
   Write_File(y3, Fs, [out_dir '_mvdr_ta.wav']);
disp('TCS-IITB>> Enhancement Done')
end


if(strcmp(enhan,'gev') && strcmp(mask,"ta")) % Perform MVDR beamforming 
   % initial few frames assumed to be silence	
   disp('TCS-IITB>> Enhancing audio using GEV Time averaged mask')
   Y3 = GEV(X,TDOA.',10);
   y3=istft_multi(Y3(:,:,1),nsampl).';
   y3=y3/max(abs(y3));
   Write_File(y3, Fs, [out_dir '_gev_ta.wav']);
disp('TCS-IITB>> Enhancement Done')
end


% 
% Y4 = MVDR_Gain(X,TDOA.',10);
%y4=istft_multi(Y4(:,:,1),nsampl).';
%y4=y4/max(abs(y4));
%audiowrite('MVDR_Gain_Spk3.wav',y4,Fs);

