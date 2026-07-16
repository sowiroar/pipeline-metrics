function intervalo = BuscarIntervaloMarcas(EEG, marca_inicio, marca_fin)
% Devuelve el intervalo de tiempo en que aparece marca_inicio y marca_fin

    intervalo = [-1 -1];

    for i=1:length(EEG.event)
        marca_actual = num2str(EEG.event(i).type);
        if strcmp(marca_actual,num2str(marca_inicio))
                intervalo(1) = EEG.event(i).latency/EEG.srate;              
        elseif strcmp(marca_actual,num2str(marca_fin))
            intervalo(end) = EEG.event(i).latency/EEG.srate;
        end   
    end

end