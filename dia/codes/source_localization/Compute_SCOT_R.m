function [ Tau S] = Compute_SCOT_R( Multi_STFT, Max_Delay)

[No_Bins, No_Frames, No_Ch] = size(Multi_STFT);
FFT_Size = (No_Bins-1)*2;

%% -------------------------------SCOT-------------------------------------
Alpha = 0.3;
Tau = zeros(No_Frames,No_Ch);
G_xx = zeros(No_Bins,No_Ch);

for j = 1:No_Frames
    FFT_X1 = Multi_STFT(:,j,1);
    G_xx(:,1) = Alpha*G_xx(:,1) + (1-Alpha)*FFT_X1.*conj(FFT_X1);
    for k = 1:No_Ch
        FFT_X2 = Multi_STFT(:,j,k);
        G_xx(:,k) = Alpha*G_xx(:,k) + (1-Alpha)*FFT_X2.*conj(FFT_X2);
        G_x1x2   = FFT_X1.*conj(FFT_X2);
 
        % Compute SCOT 
        SCOT_Weight = 1./sqrt(G_xx(:,k).*G_xx(:,k));
        G_Hat = G_x1x2.*SCOT_Weight;
        G_Hat = [G_Hat; conj(G_Hat(No_Bins-1:-1:2))];
        R     = fftshift(ifft(G_Hat));
        
        if(j == 15 && k == 2)
            S = R(FFT_Size/2+1-Max_Delay:FFT_Size/2+1+Max_Delay);
        end;
        
        [~, Index] = max(R(FFT_Size/2+1-Max_Delay:FFT_Size/2+1+Max_Delay));
        Tau(j,k) = -(Index-Max_Delay-1);
    end;
end;

Tau = Tau(1:No_Frames,:);
end
