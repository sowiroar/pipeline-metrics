function Freq_Bands = define_frequency_bands(IAF, TF)

  %% Canonical EEG frequency bands: Delta: 1.5-6 Hz, Theta: 6.5-8.0 Hz, Alpha1: 8.5-10 Hz,
    
    Freq_Bands.Delta_canon = [1.5 6.0];    %Delta: 1.5-6  Hz
    Freq_Bands.Theta_canon = [6.5 8.0];    %Theta: 6.5-8.0 Hz
    Freq_Bands.Alpha1_canon = [8.5 10.0];  %Alpha1: 8.5-10 Hz
    Freq_Bands.Alpha2_canon = [10.5 12.0]; %Alpha2: 10.5-12.0 Hz
    Freq_Bands.Beta1_canon = [12.5 18.0];  %Beta1: 12.5-18.0 Hz
    Freq_Bands.Beta2_canon = [18.5 21.0];  %Beta2: 18.5-21.0 Hz
    Freq_Bands.Beta3_canon = [21.5 30.0];  %Beta3: 21.5-30.0 Hz
    Freq_Bands.Gamma_canon = [30.0 40.0];  %Gamma: 30.0-40.0 Hz
   
    %% Subject specific EEG frequency bands
    Freq_Bands.Delta_subj_spec = [TF-4 TF-2]; 
    Freq_Bands.Theta_subj_spec = [TF-2 TF];  
    Freq_Bands.Low_subj_spec = [TF IAF];  
    Freq_Bands.High_subj_spec = [IAF IAF+2];  
    Freq_Bands.Beta_subj_spec = [12.0 30.0];  
    Freq_Bands.Gamma_subj_spec= [30.0 50.0];  
end