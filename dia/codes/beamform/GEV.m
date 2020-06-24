function [ Y ] = GEV( X,TDOA,IS)
% Performs Multi Channel Alignment
% Multi_STFT - Multi Channel STFT of the input data
% TDOA - Time Difference of Arrival for each frame (No_Frame x No_Ch)
[nbin, nfram, nchan] = size(X);
FFT_Size = (nbin-1)*2;

%--------------------------------GEV--------------------------------------

Mu = 1e-3;
Energy = permute(mean(abs(X).^2,2),[3 1 2]);
Y = zeros(nbin,nfram);

%-----------------------------Noise Covariance Matrix----------------------
Ncov=zeros(nchan,nchan,nbin);
for f=1:nbin,
    for n=1:IS,
        Ntf=permute(X(f,n,:),[3 1 2]);
        Ncov(:,:,f)=Ncov(:,:,f)+Ntf*Ntf';
    end
    Ncov(:,:,f)=Ncov(:,:,f)/IS;
end

Scov=zeros(nchan,nchan,nbin);
for f=1:nbin,
    for n=IS:nfram,
        Ntf=permute(X(f,n,:),[3 1 2]);
        Scov(:,:,f)=Scov(:,:,f)+Ntf*Ntf';
    end
    Scov(:,:,f)=Scov(:,:,f)/nfram;
end

disp([size(Scov) size(Ncov)])

for i = 1:nfram
    for j = 1:nbin
	[V,W] = eig(Scov(:,:,j),Ncov(:,:,j));
        % Compute the Noise Coherence matrix
        Y(j,i) = V(:,1)'*reshape(X(j,i,:),[nchan 1]);
    end
end

end
