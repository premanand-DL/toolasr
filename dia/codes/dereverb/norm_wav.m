function [data] = norm_wav(data, nbits)

nbits = nbits -1; % one less, as half for positive and half of negative bits
scale  = (2^nbits-1)/2^nbits;

data = data/max(abs(data)) * scale;
