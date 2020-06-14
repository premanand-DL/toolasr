function [ DSB_Data, DSB] = DSB( Multi_STFT,Tau_Spk)
% Performs Delay Sum Beamforming
% Multi_STFT - Multi Channel STFT of the input data
% TDOA - Time Difference of Arrival for each frame (No_Frame x No_Ch)
[No_Bins, No_Frames, No_Ch] = size(Multi_STFT);
FFT_Size = (No_Bins-1)*2;
% for i = 1:nbin
%     SV_Spk(:,i) = exp(-1i*2*pi*(i-1)*Tau_Spk(i,:).'/FFT_Size)/nchan;
% end;


%--------------------------------DSB---------------------------------------
%DSB = zeros(No_Ch,No_Bins);
DSB_Data = zeros(No_Bins,No_Frames);

for j = 1:No_Bins
    %DSB(:,j) =  SV_Spk(:,j)/(SV_Spk(:,j)'*SV_Spk(:,j));
    for i = 1:No_Frames
        SV_Spk = exp(-1i*2*pi*(i-1)*Tau_Spk(i,:).'/FFT_Size)/No_Ch;
        DSB =  SV_Spk/(SV_Spk'*SV_Spk);
        
        MC_Data  = reshape(Multi_STFT(j,i,:),[No_Ch 1]);
        DSB_Data(j,i) = DSB'*MC_Data;
    end;
end;

end
