function [RPD, EPP ]= relative_power_density(pxx, f, band)
%% Description

    %RPD: relative_power_density
    %EPP: equivalently percent power
%% 
    RPD = zeros(size(pxx, 1),1);
    EPP = zeros(size(pxx, 1),1);
     
    

    for i = 1:size(pxx, 1)
        
          % Define the frequency range
          if(size(band,1) == 1)
              band_range = f >= band(1) & f <= band(2);
          else
              band_range = f >= band(i,1) & f <= band(i,2);
          end
          % Compute the mean amplitude within the band range for the current channel
          band_mean = mean(pxx(i, band_range));
          
          % Compute the equivalently percent power for the band range for the current channel
          band_percent = sum(pxx(i, band_range))/sum(pxx(i, :));
          
          RPD(i) = band_mean;
          EPP(i) = band_percent;
    end
    
end