function [pxx,f] = PSD(eegSignal, fs, normalized)

%% Description
  % Compute the power spectral density of each channel of the EEG signal
  % using Welch's method with 1-second Hanning windows and 50% overlap
  
 
  % fs: Hz sample frequency
  % normalized: 0: not normalized
  %             1: n_PSD = PSD/df;  df = fs/N; N = length(eegSignal);
  %             2: n_PSD = pxx / sum(pxx);
%% Function
  win = hann(fs)'; % hanning window of 1 second in poins, fs(sample frequency) is the number of point for 1-second
  
  %[pxx,f] = pwelch(x,window,noverlap,nfft,fs): pwelch structure
  [pxx,f] = pwelch(eegSignal, win, [], 2048, fs); %If noverlap is specified as empty, a value is used to obtain 50% overlap between segments.
                                                %%If noverlap is specified as empty, a default nfft is used 
   
  if(normalized == 1)
        N = length(eegSignal);  
        df = fs/N;
        pxx = pxx/df;
  elseif(normalized == 2)
        pxx = pxx./sum(pxx);
  end
  
   pxx=pxx';
end