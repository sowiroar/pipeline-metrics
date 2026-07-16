function [sub_picos_superiores] = buscar_picos_cercanos_a_inferiores(corazon, umbral_inf, umbral_sup, proporcion)
    % Utiliza peakfinder para hallar los picos inferiores del ECG.
    % Luego en un entorno cercano a esos picos inferiores, busca
    % el pico maximo. Luego calcula el promedio temporal entre los picos
    % y obtiene un intervalo definido por:
    % [pico_inferior - promedio_temporal * proporcion : pico_inferior]
    % La funcion vuelve a usar peakfinder pero sólo en este intervalo.
    % La variable umbral es la que será utilizada en la función peakfinder
    
    %% Inverte corazon para buscar los sub_picos y vuelve a invertir
    corazon = corazon * -1; % Toma la variable corazon y la invierte
    sub_picos=peakfinder(corazon,umbral_inf)%umbral); % corre el peakfinder a los picos inferiores
    corazon = corazon * -1; % invierto el corazon de nuevo

%%   Check point
   figure
   plot(corazon)
   hold on
   plot(sub_picos, corazon(sub_picos), 'or')

   Check_point_2=input('Estan bien puestas las marcas?...(1=SI / Ctrl+C para interrumpir)');
   clear Check_point_2
   
%    diferencia_picos = sub_picos(2:end) - sub_picos(1:end-1); % diferencia entre picos
%    promedio = median(diferencia_picos); % promedio diferencia entre picos

%% Buscar picos superiores por ventanas asociadas a un pico inferior
    sub_picos_superiores = [];
    for x = 1:length(sub_picos);
        actual = sub_picos(x);
        if x == 1
            sub_inferior = floor(actual*(1-proporcion));
        else            
            sub_inferior = actual - floor((actual-sub_picos(x-1))*proporcion);
        end
        % arma una ventana
        intervalo = corazon(sub_inferior:actual);
        
        %Umbral para picos superiores
        umbral=umbral_sup;
        
        % corre peakfinder a la ventana por cada sub_pico
        sub_max = peakfinder(intervalo, umbral);
        if  isempty(sub_max);
        else
            sub_picos_superiores(x) = sub_inferior + sub_max(end)- 1;
        end
        
%%       Check point
%        figure
%        plot(intervalo)
%        hold on
%        plot(sub_max, intervalo(sub_max), 'or')
        
    end
    
%   plot(sub_picos_superiores)

%% Elimina ceros de sub_picos_superiores
    sub_picos_superiores(sub_picos_superiores==0)=[];
%    picos = corazon(sub_picos_superiores);

end