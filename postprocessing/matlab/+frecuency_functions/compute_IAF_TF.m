function [IAF, TF] = compute_IAF_TF(pxx,f)

    % Define the alpha frequency range (8-12 Hz)
    alpha_range = f >= 8 & f <= 12;
    % Define the theta second half of the range (7-8 Hz)
    theta_range_second_half = f >= 7 & f <= 8;
    
    IAF = zeros(size(pxx, 1),1);
    TF = zeros(size(pxx, 1),1);
    
    
    % Loop over each channel in the EEG data
    for i = 1:size(pxx, 1)
      % Identify the peak amplitude within the alpha range for the current channel
      [alpha_peak, alpha_peak_ind] = max(pxx(i, alpha_range));
      f_alpha_range = f(alpha_range);
      
      [min_theta_power, min_theta_power_ind]= min(pxx(i, theta_range_second_half));
      f_theta_range = f(theta_range_second_half);

      
        
      % Store the IAP value for the current channel
      IAF(i) = f_alpha_range(alpha_peak_ind);
      TF(i) = f_theta_range(min_theta_power_ind);
      
      
    end
end
