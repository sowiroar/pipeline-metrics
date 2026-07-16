function Frec_metrics= compute_PSD_metrics(pxx, f, Freq_Bands, IAF, TF)

%%
    field = fieldnames(Freq_Bands);

    for i = 1:length(field)
      current_field = field{i};
      
      band_range = getfield(Freq_Bands, current_field);
      
      [RPD, EPP ]= frecuency_functions.relative_power_density(pxx, f, band_range);
      
      Frec_metrics.([current_field '_RPD']) =RPD;
      Frec_metrics.([current_field '_EPP']) =EPP;

    end
%%
    Frec_metrics.IAF = IAF;
    Frec_metrics.TF = TF;

end